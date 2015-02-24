#ifdef RELEASE
#define LOG_TRACE_IS_ENABLED false
#define LOG_SCOPED_IS_ENABLED false
#endif //RELEASE

#include <connector/endpoint_client.hh>
#include <connector/config_client.hh>
#include <connector/log_record_client.hh>
#include <dsproxy/query_proxy.hh>
#include <dsproxy/column_proxy.hh>
#include <dsproxy/meta_proxy.hh>

#include <cachedb/db.hh>
#include <cachedb/column_data.hh>
#include <cachedb/hash_util.hh>
#include <cachedb/query_table_log.hh>

#include <util/exception.hh>
#include <util/relative_time.hh>
#include <common.pb.h>
#include <logger.hh>
#include <map>
#include <string>
#include <iostream>
#include <chrono>

using namespace virtdb::interface;
using namespace virtdb::connector;
using namespace virtdb::dsproxy;
using namespace virtdb::cachedb;
using namespace virtdb::util;

namespace
{
  template <typename EXC>
  int usage(const EXC & exc)
  {
    std::cerr << "Exception: " << exc.what() << "\n"
              << "\n"
              << "Usage: simple-cache <Service-Config-0MQ-EndPoint> <ServiceName>\n"
              << "\n"
              << " endpoint example: \n"
              << "  \"tcp://localhost:65001\"\n\n";
    return 100;
  }
  
  typedef std::map<std::string, std::string> string_map;
  
  // TODO: refactor ...
  void convert_config(const std::string & prefix,
                      const pb::KeyValue & cfg,
                      string_map & result)
  {
    std::string new_prefix{prefix};
    new_prefix += cfg.key() + "/";
    
    if( cfg.has_value() )
    {
      auto value = cfg.value();
      if( value.stringvalue_size() > 0 )
      {
        result[new_prefix] = value.stringvalue(0);
      }
    }
    for( auto const & c : cfg.children() )
    {
      convert_config(new_prefix, c, result);
    }
  }
  
  class query_data
  {
    query_proxy::query_sptr                query_;
    std::chrono::system_clock::time_point  start_;
    std::string                            tab_hash_;
    hash_util::colhash_map                 col_hashes_;
    
  public:
    typedef std::shared_ptr<query_data> sptr;
    
    query_data(query_proxy::query_sptr q)
    : query_{q},
      start_{std::chrono::system_clock::now()}
    {
      hash_util::hash_query(*query_,
                            tab_hash_,
                            col_hashes_);
    }
    
    bool
    has_cached_data(db & cache)
    {
      query_table_log qtl;
      qtl.key(tab_hash_);
      if( cache.fetch(qtl) )
      {
      }
      return false;
    }
    
    virtual ~query_data() {}
  };
}


int main(int argc, char ** argv)
{
  try
  {
    std::string default_provider;
    if( argc < 3 ) { THROW_("missing argument"); }
    if( argc > 3 )
    {
      default_provider = argv[3];
    }
    
    std::string endpoint_address{argv[1]};
    std::string service_name{argv[2]};
    
    endpoint_client     ep_clnt(endpoint_address,  service_name);
    log_record_client   log_clnt(ep_clnt, "diag-service");
    config_client       cfg_clnt(ep_clnt, "config-service");
    
    log_clnt.wait_valid_push();
    cfg_clnt.wait_valid_sub();
    cfg_clnt.wait_valid_req();

    LOG_TRACE("connection to log and config services are initialized");
    
    query_proxy     query_fwd(cfg_clnt);
    meta_proxy      meta_fwd(cfg_clnt);
    column_proxy *  col_proxy_ptr = nullptr;
    db              cache;
    
    
    // add data templates here, so db can initialized column families
    column_data     template_column_data;
    template_column_data.default_columns();
    db::storeable_ptr_vec_t column_families { &template_column_data };
    
    // init db:
    if( !cache.init("/tmp/simple-cache-data", column_families) )
    {
      LOG_ERROR("failed to initialze cacche");
    }
    
    std::mutex                                     query_mtx;
    std::map<const std::string, query_data::sptr>  queries;
    
    auto on_data_handler = [&](const std::string & provider_name,
                               const std::string & channel,
                               const std::string & subscription,
                               std::shared_ptr<pb::Column> data)
    {
      if( !data )
      {
        LOG_ERROR("invalid data received" <<
                  V_(provider_name) <<
                  V_(channel) <<
                  V_(subscription));
        return;
      }
      LOG_TRACE("received:" <<
                V_(data->queryid()) <<
                V_(data->name()) <<
                V_(data->ByteSize()) <<
                V_((int)data->data().type()) <<
                V_(data->uncompressedsize()));

      relative_time rt;
      
      // convert column data to be storeable
      column_data dta;
      dta.set(*data);
      
      if( cache.exists(dta) )
      {
        // we already have this column data
        LOG_TRACE("column data is already in the cache" <<
                  V_(provider_name)   << V_(channel)      << V_(subscription) <<
                  V_(data->queryid()) << V_(data->name()) <<
                  V_(dta.key())       << V_(dta.len())    <<
                 "took" << V_(rt.get_usec()));
        
      }
      else if( !cache.set(dta) )
      {
        // update cache with the data
        LOG_ERROR("failed to update column data" <<
                  V_(provider_name)   << V_(channel)      << V_(subscription) <<
                  V_(data->queryid()) << V_(data->name()) <<
                  V_(dta.key())       << V_(dta.len())
                  );
      }
      else
      {
        LOG_INFO("data stored in the cache" <<
                 V_(provider_name)   << V_(channel)      << V_(subscription) <<
                 V_(data->queryid()) << V_(data->name()) <<
                 V_(dta.key())       << V_(dta.len())    <<
                 "took" << V_(rt.get_usec()));
      }
    };
    
    column_proxy column_fwd(cfg_clnt, on_data_handler);
    col_proxy_ptr = &column_fwd;
    
    std::mutex mtx;
    std::mutex config_mtx;
    string_map config_parameters;
    pb::Config cfg_req;
    
    auto reconfigure = [&](const pb::Config & cfg) {
      std::unique_lock<std::mutex> l(config_mtx);
      for( auto const & cf : cfg.configdata() )
      {
        convert_config("",
                       cf,
                       config_parameters);
      }
      if( config_parameters.count("user_config/Data Provider/") )
      {
        std::string data_provider{config_parameters["user_config/Data Provider/"]};
        LOG_TRACE("configure using" << V_(data_provider));
        if( query_fwd.reconnect(data_provider) )
        {
          LOG_INFO("query proxy connected to" << V_(data_provider));
        }
        if( meta_fwd.reconnect(data_provider) )
        {
          LOG_INFO("meta proxy connected to" << V_(data_provider));
        }
        if( column_fwd.reconnect(data_provider) )
        {
          LOG_INFO("column proxy connected to" << V_(data_provider));
        }
      }
    };
    
    auto on_new_query = [&](const std::string & id,
                            query_proxy::query_sptr q)
    {
      column_fwd.subscribe_query(id);
      query_data::sptr tmp_query{new query_data{q}};
      
      if( tmp_query->has_cached_data(cache) )
      {
        return query_proxy::dont_forward;
      }
      else
      {
        std::unique_lock<std::mutex> l(query_mtx);
        queries[id] = tmp_query;
        return query_proxy::forward_query;
      }
    };
    
    auto on_resend_chunk = [&](const std::string & query_id,
                               std::set<std::string> & columns,
                               std::set<uint64_t> & blocks)
    {
      bool ret = true;
      // TODO
      return ret;
    };
    
    query_fwd.watch_new_queries(on_new_query);
    query_fwd.watch_resend_chunk(on_resend_chunk);
    
    auto on_disconnect = [&]()
    {
      LOG_ERROR("disconnect detected. doing automatic reconnect based on the current config data");
      reconfigure(cfg_req);
    };
    
    meta_fwd.watch_disconnect(on_disconnect);
    // TODO : add disconnect detecion code to the other proxies too
    
    LOG_TRACE("registering config watch");
    
    auto config_watch = [&](const std::string & provider_name,
                            const std::string & channel,
                            const std::string & subscription,
                            std::shared_ptr<pb::Config> cfg)
    {
      if( cfg->name() == ep_clnt.name() )
      {
        LOG_TRACE("Received config (SUB):" <<
                 V_(provider_name) <<
                 V_(channel) <<
                 V_(subscription) <<
                 M_(*cfg));
        reconfigure(*cfg);
      }
    };
    
    cfg_clnt.watch(ep_clnt.name(), config_watch);
    
    {
      LOG_TRACE("gathering initial config");
      cfg_req.set_name(ep_clnt.name());
      {
        // sending initial request to gather config data
        cfg_clnt.send_request(cfg_req,
                              [&](const pb::Config & cfg)
                              {
                                reconfigure(cfg);
                                std::set<std::string> strs;
                                for( auto const & c : cfg_req.configdata() )
                                  strs.insert( c.key() );
                                for( auto const & c : cfg.configdata() )
                                {
                                  if( strs.count(c.key()) == 0 )
                                    cfg_req.add_configdata()->MergeFrom(c);
                                }
                                return true;
                              },10000);
      }
      
      bool send_template = true;
      for( auto const & c : cfg_req.configdata() )
        if( c.key() == "" && c.children_size() > 0 )
          send_template = false;
      
      if( send_template )
      {
        pb::KeyValue * cfg_data = nullptr;
        
        {
          // remove "" template if any
          for( int i=0; i<cfg_req.configdata_size(); ++i )
          {
            auto c = cfg_req.mutable_configdata(i);
            if( c->key() == "" )
            {
              cfg_data = c;
              cfg_data->clear_children();
              break;
            }
          }
          if( !cfg_data )
            cfg_data = cfg_req.add_configdata();
        }
        cfg_data->set_key("");
        std::vector<std::string> requested_config_values{
          "Data Provider",
        };
        
        for( auto const & v : requested_config_values )
        {
          auto child = cfg_data->add_children();
          child->set_key(v);
          {
            auto child_l2 = child->add_children();
            child_l2->set_key("Value");
            auto value_l2 = child_l2->mutable_value();
            value_l2->set_type(pb::Kind::STRING);
          }
          {
            auto child_l2 = child->add_children();
            child_l2->set_key("Scope");
            auto value_l2 = child_l2->mutable_value();
            value_l2->add_stringvalue("user_config");
            value_l2->set_type(pb::Kind::STRING);
          }
        }
        
        cfg_clnt.send_request(cfg_req,
                              [&](const pb::Config & cfg)
                              {
                                reconfigure(cfg);
                                return true;
                              },10000);
      }
    }
    
    while( true )
    {
      std::this_thread::sleep_for(std::chrono::seconds(60));
      {
        std::unique_lock<std::mutex> l(mtx);
        LOG_TRACE("alive");
      }
    }

  }
  catch (const std::exception & e)
  {
    return usage(e);
  }
  return 0;
}
