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
#include <util/active_queue.hh>
#include <common.pb.h>
#include <logger.hh>
#include <map>
#include <string>
#include <iostream>
#include <chrono>

#include "query_data.hh"

using namespace virtdb::interface;
using namespace virtdb::connector;
using namespace virtdb::dsproxy;
using namespace virtdb::cachedb;
using namespace virtdb::util;
using namespace virtdb::simple_cache;

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
    
    std::string cache_location{"/tmp/simple-cache-"};
    cache_location += service_name;
    
    // initialize cache
    auto init_cache = [](db & cache, const std::string & location)
    {
      // add data templates here, so db can initialized column families
      column_data         template_column_data;
      query_table_block   template_query_table_block;
      query_table_log     template_query_table_log;
      query_column_block  template_query_column_block;

      template_column_data.default_columns();
      template_query_table_block.default_columns();
      template_query_table_log.default_columns();
      template_query_column_block.default_columns();
      
      db::storeable_ptr_vec_t column_families {
        &template_column_data,
        &template_query_table_block,
        &template_query_table_log,
        &template_query_column_block,
      };
      
      // init db:
      if( !cache.init(location, column_families) )
      {
        LOG_ERROR("failed to initialze cacche");
      }
    };
    
    init_cache(cache, cache_location);
    
    std::mutex                               query_mtx;
    std::map<std::string, query_data::sptr>  queries;
    
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

      relative_time rt;
      
      // convert column data to be storeable
      column_data dta;
      dta.set(*data);
      
      // query data
      query_data::sptr qdata;
      {
        std::unique_lock<std::mutex> l(query_mtx);
        qdata = queries[data->queryid()];
      }
      
      // TODO : check and debug, do we need to store the data every time???
      if( !cache.set(dta) )
      {
        // update cache with the data
        LOG_ERROR("failed to update column data" <<
                  V_(provider_name)   << V_(data->queryid()) << V_(data->name()) <<
                  V_(dta.key())       << V_(dta.len())
                  );
        
        std::ostringstream os;
        os << "failed to store column data for {" << data->queryid() << '/' << data->name() << ':' << data->seqno() << "}";
        qdata->error_info(os.str());
        return;
      }
      
      const std::string & err_info = qdata->error_info();
      
      if( !err_info.empty() )
      {
        LOG_TRACE("not storing column admin information because of current error state" <<
                  V_(data->queryid()) <<
                  V_(data->name()) <<
                  V_(data->ByteSize()) <<
                  V_((int)data->data().type()) <<
                  V_(data->uncompressedsize()) <<
                  V_(err_info));
        return;
      }
      
      query_column_block qcb;
      if( qdata->store_column_block(cache,
                                    data->name(),
                                    dta.key(),
                                    data->seqno(),
                                    data->endofdata(),
                                    qcb) == false )
      {
        std::ostringstream os;
        os << "failed to store query_column_block data for {" << data->queryid() << '/' << data->name() << ':' << data->seqno() << "}";
        qdata->error_info(os.str());
        LOG_ERROR(V_(os.str()));
        return;
      }
      
      query_table_block qtb;
      if( qdata->update_table_block(cache,
                                    data->name(),
                                    data->seqno(),
                                    qtb) == false )
      {
        std::ostringstream os;
        os << "failed to update query_table_block data for {" << data->queryid() << '/' << data->name() << ':' << data->seqno() << "}";
        qdata->error_info(os.str());
        LOG_ERROR(V_(os.str()));
        return;
      }
      
      LOG_TRACE("update_table_block done" <<
                V_(provider_name)   << V_(data->queryid()) << V_(data->name()) <<
                V_(dta.key())       << V_(dta.len())       << "took" << V_(rt.get_usec()) <<
                V_(qcb.key()) <<
                V_(qtb.key()) <<
                V_(data->seqno()) <<
                V_(data->endofdata()) <<
                V_(qdata->block_count()) <<
                V_(qdata->complete_count()) <<
                V_(qdata->max_block()) <<
                V_(qdata->missing()));
      
      if( qdata->end_of_data(data->endofdata()) &&
          qdata->is_complete(data->seqno()) )
      {
        query_table_log qtl;
        if( qdata->update_table_log(cache, qtl) == false)
        {
          std::ostringstream os;
          os << "failed to update query_table_log data for {" << data->queryid() << '/' << data->name() << ':' << data->seqno() << "}";
          qdata->error_info(os.str());
          return;
        }
        
        // TODO : query data expiry
        /* LOG_INFO("successfully cache table" << V_(qtl.key()) <<
                 V_(provider_name)   << V_(data->queryid()) << V_(data->name()) <<
                 V_(dta.key())       << V_(dta.len()) );//      << "took" << V_(rt.get_usec())); */
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
    
    auto fetch_column = [&](const std::string & column_hash,
                            const std::chrono::system_clock::time_point & tp,
                            const std::string & name,
                            const std::string & query_id,
                            size_t seq_no,
                            size_t & len)
    {
      std::shared_ptr<pb::Column> data;
      query_column_block qcb;
      qcb.key(column_hash, tp, seq_no);
      size_t res = cache.fetch(qcb);
      if( res < 2 )
      {
        LOG_ERROR("failed to fetch query_column_block" <<
                  V_(query_id) << V_(name) <<
                  V_(qcb.key()) <<
                  V_(res) << V_(seq_no));
        return data;
      }
      
      column_data cd;
      cd.key(qcb.column_hash());
      res = cache.fetch(cd);
      if( res < 1 )
      {
        LOG_ERROR("failed to fetch column_data" <<
                  V_(query_id) << V_(name) <<
                  V_(res) << V_(seq_no) << V_(cd.key()));
        return data;
      }
      len = cd.len();
      
      data.reset(new pb::Column);
      auto parsed = data->ParsePartialFromString(cd.data());
      if( !parsed )
      {
        LOG_ERROR("failed to parse column_data" <<
                  V_(query_id) << V_(name) <<
                  V_(res) << V_(cd.len()) << V_(cd.key()));
        data.reset();
        return data;
      }
      
      // align data with query
      data->set_queryid(query_id);
      data->set_name(name);
      data->set_seqno(seq_no);
      data->set_endofdata(qcb.end_of_data());
      return data;
    };
    
    auto send_cached_data = [&](query_data::sptr qd)
    {
      relative_time rt;

      // gather head record: query_table_log
      query_table_log qtl;
      qtl.key(qd->tab_hash());
      size_t res = cache.fetch(qtl);
      
      std::string query_id{qd->query()->queryid()};
      std::string schema{qd->query()->schema()};
      std::string table{qd->query()->table()};
      
      LOG_TRACE("reading cache based on query_table_log" <<
                V_(query_id) <<
                V_(qtl.n_columns()) <<
                V_(qd->tab_hash()) <<
                V_(res) <<
                V_(qtl.property_cref(qtl.qn_t0_completed_at)) <<
                V_(qtl.t0_nblocks()));
      
      if( res < 3 )
      {
        LOG_ERROR("failed to fecth query_table_log" <<
                  V_(query_id) <<
                  V_(schema) <<
                  V_(table) <<
                  V_(res));
        return false;
      }
      if( qtl.t0_nblocks() == 0 )
      {
        LOG_ERROR("query_table_log has no block number info" <<
                  V_(query_id) <<
                  V_(schema) <<
                  V_(table) <<
                  V_(qtl.t0_nblocks()));
        return false;
      }
      if( qtl.n_columns() != qd->col_hashes().size() )
      {
        LOG_ERROR("inconsistent column count in query_table_log" <<
                  V_(query_id) <<
                  V_(schema) <<
                  V_(table) <<
                  V_(qtl.n_columns()) <<
                  V_(qd->col_hashes().size()));
        return false;
      }
      
      auto const & col_hashes = qd->col_hashes();
      
      size_t total_blocks = 0;
      size_t total_bytes  = 0;
      size_t columns      = col_hashes.size();
      
      for( size_t bn=0; bn<qtl.t0_nblocks(); ++bn )
      {
        
        for( auto const & ch : col_hashes )
        {
          size_t len = 0;
          auto data = fetch_column(ch.second,
                                   qtl.t0_completed_at(),
                                   ch.first,
                                   query_id,
                                   bn,
                                   len);

          if( !len || !data )
          {
            LOG_ERROR("invalid column" <<
                      V_(query_id) <<
                      V_(schema) <<
                      V_(table) <<
                      V_(ch.first) <<
                      V_(ch.second) <<
                      V_(bn));
            return false;
          }
          
          col_proxy_ptr->publish(data);
          
          ++total_blocks;
          total_bytes += len;
        }
      }
      
      double ms = (0.0+rt.get_usec())/1000.0;
      
      LOG_INFO("cache returned" <<
               V_(query_id) <<
               V_(schema) <<
               V_(table) <<
               V_(total_blocks) <<
               V_(total_bytes) <<
               V_(columns) <<
               "took" << V_(ms));
      
      // set start point so we can support resend queries too
      qd->start(qtl.t0_completed_at());      
      return true;
    };
    
    // active_queue<query_data::sptr,1000> cached_data_sender{ 1, send_cached_data };
    
    auto on_new_query = [&](const std::string & id,
                            query_proxy::query_sptr q)
    {
      if( q->has_querycontrol() )
      {
        // ignore special queries as they cannot be new
        return query_proxy::dont_forward;
      }
        
      query_data::sptr tmp_query{new query_data{q}};
      {
        std::unique_lock<std::mutex> l(query_mtx);
        queries[id] = tmp_query;
      }
      
      if( tmp_query->has_cached_data(cache) )
      {
        // cached_data_sender.push(tmp_query);
        if( send_cached_data(tmp_query) )
        {
          return query_proxy::dont_forward;
        }
        else
        {
          column_fwd.subscribe_query(id);
          return query_proxy::forward_query;
        }
      }
      else
      {
        column_fwd.subscribe_query(id);
        return query_proxy::forward_query;
      }
    };
    
    auto on_resend_chunk = [&](const std::string & query_id,
                               std::set<std::string> & columns,
                               std::set<uint64_t> & blocks)
    {
      bool ret = false;
      
      // query data
      query_data::sptr qdata;
      {
        std::unique_lock<std::mutex> l(query_mtx);
        qdata = queries[query_id];
      }
      
      if( !qdata )
      {
        LOG_ERROR("unknown" << V_(query_id) << "cannot resend");
        return ret;
      }
      
      auto const & col_hashes = qdata->col_hashes();
      
      for( auto const & c : columns )
      {
        auto const & col_hash = col_hashes.find(c);
        for( auto const & b : blocks )
        {
          size_t len = 0;
          auto data = fetch_column(col_hash->second,
                                   qdata->start(),
                                   c,
                                   query_id,
                                   b,
                                   len);
          
          if( data )
          {
            LOG_TRACE("re-sending" << V_(query_id) << V_(b) << V_(c) << V_(len) << V_(col_hash->second));
            col_proxy_ptr->publish(data);
          }
          else
          {
            LOG_TRACE("cannot re-send" << V_(query_id) << V_(b) << V_(c) << V_(col_hash->second) );
          }          
        }
      }
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
          "Cache Location",
          "Expiry",
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
