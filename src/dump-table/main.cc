#ifdef RELEASE
#define LOG_TRACE_IS_ENABLED false
#define LOG_SCOPED_IS_ENABLED false
#endif //RELEASE

#include <logger.hh>
#include <util/exception.hh>
#include <engine/collector.hh>
#include <engine/feeder.hh>
#include <connector.hh>
#include <chrono>
#include <mutex>
#include <iostream>
#include <fstream>
#include <set>

using namespace virtdb::logger;
using namespace virtdb::util;
using namespace virtdb::connector;
using namespace virtdb::interface;
using namespace virtdb::engine;

// #define NOPRINT

namespace
{
  template <typename EXC>
  int usage(const EXC & exc)
  {
    std::cerr << "Exception: " << exc.what() << "\n"
              << "\n"
              << "Usage: dump-table <ZeroMQ-EndPoint> <DataSource> <TableName> [Schema]\n"
              << "\n"
              << " endpoint examples: \n"
              << "  \"ipc:///tmp/cfg-endpoint\"\n"
              << "  \"tcp://localhost:65001\"\n\n";
    return 100;
  }
}

int main(int argc, char ** argv)
{
  try
  {
    if( argc < 4 )
    {
      THROW_("invalid number of arguments");
    }
    
    std::string config_svc{argv[1]};
    std::string data_source{argv[2]};
    std::string table{argv[3]};
    std::string schema;
    
    if( argc > 4 )
      schema = argv[4];
    
    endpoint_client     ep_clnt(config_svc,  "dump-table");
    log_record_client   log_clnt(ep_clnt,    "diag-service");
    
    log_sink::socket_sptr dummy_socket;
    log_sink::sptr        sink_stderr;
    
    if( log_clnt.wait_valid_push(1000) )
    {
      LOG_INFO("log connected");
    }
    else
    {
      sink_stderr.reset(new log_sink{dummy_socket});
    }
    
    LOG_INFO("diag client connected");
    
    query_client q_cli(ep_clnt, data_source);
    
    if( !q_cli.wait_valid(10000) )
    {
      LOG_ERROR("failed to connect to data source" << V_(data_source) << "(query service)" << V_(config_svc));
      THROW_("cannot connect to query service");
    }
    
    column_client col_cli(ep_clnt, data_source);

    if( !col_cli.wait_valid(10000) )
    {
      LOG_ERROR("failed to connect to data source" << V_(data_source) << "(column service)" << V_(config_svc));
      THROW_("cannot connect to column service");
    }
    
    meta_data_client meta_cli(ep_clnt, data_source);

    if( !meta_cli.wait_valid(10000) )
    {
      LOG_ERROR("failed to connect to data source" << V_(data_source) << "(meta_data service)" << V_(config_svc));
      THROW_("cannot connect to meta_data service");
    }

    pb::MetaDataRequest  meta_req;
    pb::MetaData         meta_rep;
    {
      meta_req.set_name(table);
      if( !schema.empty() )
        meta_req.set_schema(schema);
      meta_req.set_withfields(true);
    }
    
    if( !meta_cli.send_request(meta_req,
                               [&meta_rep](const pb::MetaData &rep) { meta_rep.Clear(); meta_rep.MergeFrom(rep); return true; },
                               10000) )
    {
      LOG_ERROR("failed to send meta_data request to data source" << V_(data_source) << V_(config_svc));
      THROW_("failed to send meta_data request");
    }

    pb::TableMeta table_meta;
    for( auto const & tm : meta_rep.tables() )
    {
      if( tm.schema() == schema && tm.name() == table )
      {
        table_meta.MergeFrom(tm);
        break;
      }
    }
    
    if( !table_meta.has_name() )
    {
      LOG_ERROR("meta_data has no table name" << V_(data_source) << V_(table) << M_(meta_rep));
      THROW_("failed to gather meta_data");
    }

    std::map<std::string, size_t> column_map;
    
    size_t i=0;
    for( auto const & fl : table_meta.fields() )
    {
      column_map[fl.name()] = i;
      ++i;
    }

    std::srand((unsigned int)relative_time::instance().get_usec()+time(nullptr));
    std::string query_id{table+"dump"+std::to_string(std::rand())};
    pb::Query query;
    auto resend_function = [&](size_t block_id,
                               const collector::col_vec & cols)
    {
      pb::Query resend_query;
      resend_query.set_queryid(query.queryid());
      resend_query.set_table(query.table());
      resend_query.set_querycontrol(pb::Query_Command::Query_Command_RESEND_CHUNK);
      resend_query.add_seqnos(block_id);
      for( auto const & c : cols )
      {
        auto * f = resend_query.add_fields();
        f->set_name(table_meta.fields(c).name());
        auto * desc = f->mutable_desc();
        desc->set_type(table_meta.fields(c).desc().type());
      }
      if( !schema.empty() )
        resend_query.set_schema(schema);

#if LOG_TRACE_IS_ENABLED
      {
        std::ostringstream os;
        for( auto const & c : cols )
        {
          auto fl = table_meta.fields(c);
          os << c << ':' << fl.name() << ' ';
        }
        LOG_TRACE("doing resend" << V_(query.table()) << V_(os.str()) << M_(resend_query));
      }
#endif // LOG_TRACE_IS_ENABLED
      
      // send the query here
      if( !q_cli.send_request(resend_query) )
      {
        LOG_ERROR("failed to re-send query to data source" << V_(data_source) << V_(config_svc) << M_(resend_query));
      }
    };
    collector::sptr coll{new collector(table_meta.fields_size(), resend_function)};

    col_cli.watch(query_id,
                  [&,query_id](const std::string & provider_name,
                               const std::string & channel,
                               const std::string & subscription,
                               std::shared_ptr<pb::Column> column)
                  {
                    if( !column ) return;
                    if( !column->has_name() ) return;
                    if( !column_map.count(column->name()) ) return;
                    coll->push(column->seqno(), column_map[column->name()], column);
                    /* */
                    LOG_TRACE(V_(column->seqno()) <<
                              V_(column->name()) <<
                              V_(column_map[column->name()]) <<
                              V_(coll->n_process_started()) <<
                              V_(coll->n_process_done()) <<
                              V_(coll->n_process_succeed()) <<
                              V_(coll->n_queued()) <<
                              V_(coll->n_received()));
                     /**/
                  });

    feeder fdr{coll};
    
    // prepare and send query. the data receivers are all set now, need to setup the query
    {
      query.set_queryid(query_id);
      query.set_table(table);
      for( auto const fl : table_meta.fields() )
      {
        auto * f = query.add_fields();
        f->set_name(fl.name());
        auto * desc = f->mutable_desc();
        desc->set_type(fl.desc().type());
      }
      if( !schema.empty() )
        query.set_schema(schema);
    }
    
    // send the query here
    if( !q_cli.send_request(query) )
    {
      LOG_ERROR("failed to send query to data source" << V_(data_source) << V_(config_svc));
      THROW_("failed to send query");
    }

    const char sep = 0x1;
    int n_columns = query.fields_size();
    std::vector<pb::Kind> kinds;
    for( auto const & fl : query.fields() )
    {
      auto desc = fl.desc();
      pb::Kind k = desc.type();
      kinds.push_back(k);
      std::cout << fl.name() << sep;
    }
    
    size_t n_rows = 0;
    std::cout << "\n";
    
    while( true )
    {
      if( !fdr.started() )
      {
        // try to gather first block
        if( !fdr.fetch_next() )
          break;
      }
      else if( !fdr.has_more() )
      {
        // try to gather next block
        if( !fdr.fetch_next() )
          break;
      }
      
      value_type_reader::status r = value_type_reader::ok_;
      
      for( int i=0; (i<n_columns && r==value_type_reader::ok_); ++i )
      {
        pb::Kind k = kinds[i];
        bool null = false;
        switch( k )
        {
          case pb::Kind::INT32:
          {
            int32_t v = 0;
            r = fdr.read_int32((size_t)i, v, null);
            if( r == value_type_reader::ok_ && !null )
            {
#ifndef NOPRINT
              if( !null ) std::cout << v;
#endif // NOPRINT
            }
            break;
          }
          case pb::Kind::INT64:
          {
            int64_t v = 0;
            r = fdr.read_int64((size_t)i, v, null);
            if( r == value_type_reader::ok_ && !null )
            {
#ifndef NOPRINT
              if( !null ) std::cout << v;
#endif // NOPRINT
            }
            break;
          }
          case pb::Kind::UINT32:
          {
            uint32_t v = 0;
            r = fdr.read_uint32((size_t)i, v, null);
            if( r == value_type_reader::ok_ && !null )
            {
#ifndef NOPRINT
              if( !null ) std::cout << v;
#endif // NOPRINT
            }
            break;
          }
          case pb::Kind::UINT64:
          {
            uint64_t v = 0;
            r = fdr.read_uint64((size_t)i, v, null);
            if( r == value_type_reader::ok_ && !null )
            {
#ifndef NOPRINT
              if( !null ) std::cout << v;
#endif // NOPRINT
            }
            break;
          }
          case pb::Kind::DOUBLE:
          {
            double v = 0;
            r = fdr.read_double((size_t)i, v, null);
            if( r == value_type_reader::ok_ && !null )
            {
#ifndef NOPRINT
              if( !null ) std::cout << v;
#endif // NOPRINT
            }
            break;
          }
          case pb::Kind::FLOAT:
          {
            float v = 0;
            r = fdr.read_float((size_t)i, v, null);
            if( r == value_type_reader::ok_ && !null )
            {
#ifndef NOPRINT
              if( !null ) std::cout << v;
#endif // NOPRINT
            }

            break;
          }
          case pb::Kind::BOOL:
          {
            bool v = 0;
            r = fdr.read_bool((size_t)i, v, null);
            if( r == value_type_reader::ok_ && !null )
            {
#ifndef NOPRINT
              if( !null ) std::cout << v;
#endif // NOPRINT
            }
            break;
          }
            
          case pb::Kind::BYTES:
          {
            char * ptr = nullptr;
            size_t len = 0;
            r = fdr.read_bytes((size_t)i, &ptr, len, null);
            if( r == value_type_reader::ok_ && !null && len && ptr )
            {
#ifndef NOPRINT
              if( !null ) { ptr[len] = 0; std::cout << ptr; }
#endif // NOPRINT
            }
            break;
          }
            
          case pb::Kind::STRING:
          case pb::Kind::DATE:
          case pb::Kind::TIME:
          case pb::Kind::DATETIME:
          case pb::Kind::NUMERIC:
          case pb::Kind::INET4:
          case pb::Kind::INET6:
          case pb::Kind::MAC:
          case pb::Kind::GEODATA:
          default:
          {
            char * ptr = nullptr;
            size_t len = 0;
            r = fdr.read_string((size_t)i, &ptr, len, null);
            if( r == value_type_reader::ok_ && !null && len && ptr )
            {
#ifndef NOPRINT
              if( !null ) { ptr[len] = 0; std::cout << ptr; }
#endif // NOPRINT
            }
            break;
          }
        };
        
#ifndef NOPRINT
        if( r == value_type_reader::ok_ ) std::cout << sep;
#endif // NOPRINT
      }
#ifndef NOPRINT
      if( r == value_type_reader::ok_ ) std::cout << "\n";
#endif // NOPRINT
      ++n_rows;
    }
    LOG_TRACE("received" << V_(n_rows) << "from" << V_(data_source) << V_(table));
    
  }
  catch (const std::exception & e)
  {
    return usage(e);
  }
  return 0;
}

