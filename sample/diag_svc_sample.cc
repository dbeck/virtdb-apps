
// proto
#include <svc_config.pb.h>
#include <diag.pb.h>
#include <logger.hh>
#include <util.hh>
#include <connector.hh>
// others
#include <zmq.hpp>
#include <iostream>
#include <map>
#include <future>

using namespace virtdb;
using namespace virtdb::interface;
using namespace virtdb::util;
using namespace virtdb::connector;

namespace
{
  template <typename EXC>
  int usage(const EXC & exc)
  {
    std::cerr << "Exception: " << exc.what() << "\n"
              << "\n"
              << "Usage: diag_svc_sample <ZeroMQ-EndPoint>\n"
              << "\n"
              << " endpoint examples: \n"
              << "  \"ipc:///tmp/diag-endpoint\"\n"
              << "  \"tcp://localhost:65001\"\n\n";
    return 100;
  }
  
  struct log_data
  {
    typedef std::shared_ptr<pb::LogHeader> header_sptr;
    typedef std::map<uint32_t, header_sptr> header_map;
    typedef std::map<uint32_t, std::string> symbol_map;
    typedef std::map<pb::ProcessInfo, header_map, compare_process_info> process_headers;
    typedef std::map<pb::ProcessInfo, symbol_map, compare_process_info> process_symbols;
    
    process_headers headers_;
    process_symbols symbols_;
    
    void add_header( const pb::ProcessInfo & proc_info, const pb::LogHeader & hdr )
    {
      auto proc_it = headers_.find(proc_info);
      if( proc_it == headers_.end() )
      {
        auto success = headers_.insert(std::make_pair(proc_info,header_map()));
        proc_it = success.first;
      }
      
      auto head_it = proc_it->second.find(hdr.seqno());
      if( head_it == proc_it->second.end() )
      {
        (proc_it->second)[hdr.seqno()] = header_sptr(new pb::LogHeader(hdr));
      }
    }
    
    void add_symbol( const pb::ProcessInfo & proc_info, const pb::Symbol & sym )
    {
      auto proc_it = symbols_.find(proc_info);
      if( proc_it == symbols_.end() )
      {
        auto success = symbols_.insert(std::make_pair(proc_info,symbol_map()));
        proc_it = success.first;
      }
      
      auto sym_it = proc_it->second.find(sym.seqno());
      if( sym_it == proc_it->second.end() )
      {
        (proc_it->second)[sym.seqno()] = sym.value();
      }
    }
    
    std::string resolve(const symbol_map & smap, uint32_t id) const
    {
      static const std::string empty("''");
      auto it = smap.find(id);
      if( it == smap.end() )
        return empty;
      else
        return it->second;
    }
    
    void print_variable(const pb::ValueType & var) const
    {
      switch( var.type() )
      {
          // TODO : handle array parameters ...
        case pb::Kind::BOOL:   std::cout << (var.boolvalue(0)?"true":"false"); break;
        case pb::Kind::FLOAT:  std::cout << var.floatvalue(0); break;
        case pb::Kind::DOUBLE: std::cout << var.doublevalue(0); break;
        case pb::Kind::STRING: std::cout << var.stringvalue(0); break;
        case pb::Kind::INT32:  std::cout << var.int32value(0); break;
        case pb::Kind::UINT32: std::cout << var.uint32value(0); break;
        case pb::Kind::INT64:  std::cout << var.int64value(0); break;
        case pb::Kind::UINT64: std::cout << var.uint64value(0); break;
        default:               std::cout << "'unhandled-type'"; break;
      };
    }
    
    static const std::string &
    level_string( pb::LogLevel level )
    {
      static std::map<pb::LogLevel, std::string> level_map{
        { pb::LogLevel::INFO,          "INFO", },
        { pb::LogLevel::ERROR,         "ERROR", },
        { pb::LogLevel::SIMPLE_TRACE,  "TRACE", },
        { pb::LogLevel::SCOPED_TRACE,  "SCOPED" },
      };
      static std::string unknown("UNKNOWN");
      auto it = level_map.find(level);
      if( it == level_map.end() )
        return unknown;
      else
        return it->second;
    }
    
    void print_data(const pb::ProcessInfo & proc_info,
                    const pb::LogData & data,
                    const pb::LogHeader & head,
                    const symbol_map & symbol_table) const
    {
      std::ostringstream host_and_name;
  
      if( proc_info.has_hostsymbol() )
        host_and_name << " " << resolve(symbol_table, proc_info.hostsymbol());
      if( proc_info.has_namesymbol() )
        host_and_name << "/" << resolve(symbol_table, proc_info.namesymbol());
      
      std::cout << '[' << proc_info.pid() << ':' << data.threadid() << "]"
                << host_and_name.str()
                << " (" << level_string(head.level())
                << ") @" << resolve(symbol_table,head.filenamesymbol()) << ':'
                << head.linenumber() << " " << resolve(symbol_table,head.functionnamesymbol())
                << "() @" << data.elapsedmicrosec() << "us ";
      
      int var_idx = 0;

      if( head.level() == pb::LogLevel::SCOPED_TRACE &&
          data.has_endscope() &&
          data.endscope() )
      {
        std::cout << " [EXIT] ";
      }
      else
      {
        if( head.level() == pb::LogLevel::SCOPED_TRACE )
          std::cout << " [ENTER] ";
        
        for( int i=0; i<head.parts_size(); ++i )
        {
          auto part = head.parts(i);
          
          if( part.isvariable() && part.hasdata() )
          {
            std::cout << " {";
            if( part.has_partsymbol() )
              std::cout << resolve(symbol_table, part.partsymbol()) << "=";
            
            if( var_idx < data.values_size() )
              print_variable( data.values(var_idx) );
            else
              std::cout << "'?'";
            
            std::cout << '}';
            
            ++var_idx;
          }
          else if( part.hasdata() )
          {
            std::cout << " ";
            if( var_idx < data.values_size() )
              print_variable( data.values(var_idx) );
            else
              std::cout << "'?'";
            
            ++var_idx;
          }
          else if( part.has_partsymbol() )
          {
            std::cout << " " << resolve(symbol_table, part.partsymbol());
          }
        }
      }
      std::cout << "\n";
    }
    
    void print_message( const pb::LogRecord & rec ) const
    {
      for( int i=0; i<rec.data_size(); ++i )
      {
        auto data = rec.data(i);
        auto proc_heads = headers_.find(rec.process());
        if( proc_heads == headers_.end() )
        {
          std::cout << "missing proc-header\n";
          return;
        }
        
        auto head = proc_heads->second.find(data.headerseqno());
        if( head == proc_heads->second.end())
        {
          std::cout << "missing header-seqno\n";
          return;
        }
        
        if( !head->second )
        {
          std::cout << "empty header\n";
          return;
        }
        
        auto proc_syms = symbols_.find(rec.process());
        if( proc_syms == symbols_.end() )
        {
          std::cout << "missing proc-symtable\n";
          return;
        }
        
        print_data( rec.process(), data, *(head->second), proc_syms->second );
      }
    }
  };
}

int main(int argc, char ** argv)
{
  using pb::LogRecord;
  using pb::LogHeader;
  using pb::ProcessInfo;

  try
  {
    if( argc < 2 )
    {
      THROW_("invalid number of arguments");
    }
    
    endpoint_client     ep_clnt(argv[1], "diag_svc");
    // TODO : config_client       cfg_clnt(ep_clnt);
    // TODO : log_record_server   log_svr(cfg_clnt);
    
    std::promise<ip_discovery_client::endpoint_vector> ip_discovery_promise;
    std::future<ip_discovery_client::endpoint_vector> ip_discovery_data{ip_discovery_promise.get_future()};
    
    ep_clnt.watch(pb::ServiceType::IP_DISCOVERY, [&ip_discovery_promise](const pb::EndpointData & ep)
    {
      ip_discovery_client::endpoint_vector result;
      for( int i=0; i<ep.connections_size(); ++i )
      {
        auto conn = ep.connections(i);
        if( conn.type() == pb::ConnectionType::RAW_UDP )
        {
          for( int ii=0; ii<conn.address_size(); ++ii )
          {
            result.push_back(conn.address(ii));
          }
        }
      }
      if( result.size() > 0 )
      {
        // we don't need more IP_DISCOVERY endpoints
        ip_discovery_promise.set_value(result);
        return false;
      }
      else
      {
        // continue iterating over IP_DISCOVERY endpoints
        return true;
      }
    });
    
    // wait till we have a valid IP_DISCOVERY endpoint data
    ip_discovery_data.wait();
    
    // stop listening on IP_DISCOVERY endpoint data
    ep_clnt.remove_watches(pb::ServiceType::IP_DISCOVERY);
    
    // determine my ip
    std::string my_ip;
    {
      my_ip = ip_discovery_client::get_ip(ip_discovery_data.get());
      if( my_ip.empty() )
      {
        net::string_vector my_ips = util::net::get_own_ips();
        if( !my_ips.empty() )
          my_ip = my_ips[0];
      }
      if( my_ip.empty() )
      {
        THROW_("cannot find a valid IP address");
      }
    }

    // setting up our own endpoint
    zmq::context_t context(1);
    zmq::socket_t diag_socket(context, ZMQ_PULL);
    std::string diag_service_address;

    {
      pb::EndpointData ep_data;
      ep_data.set_name(ep_clnt.name());
      ep_data.set_svctype(pb::ServiceType::LOG_RECORD);

      std::ostringstream os;
      os << "tcp://" << my_ip << ":*";
      diag_socket.bind(os.str().c_str());

      {
        // TODO: refactor to separate class ...
        char last_zmq_endpoint[512];
        last_zmq_endpoint[0] = 0;
        size_t opt_size = sizeof(last_zmq_endpoint);
        diag_socket.getsockopt(ZMQ_LAST_ENDPOINT, last_zmq_endpoint, &opt_size);
        last_zmq_endpoint[sizeof(last_zmq_endpoint)-1] = 0;
        
        auto conn = ep_data.add_connections();
        conn->set_type(pb::ConnectionType::PUSH_PULL);
        diag_service_address = last_zmq_endpoint;
        *(conn->add_address()) = last_zmq_endpoint;
      }
      
      ep_clnt.register_endpoint(ep_data);
    }
    
    log_data log_static_data;
    std::cerr << "Diag service started at: " << diag_service_address << "\n";
    
    while( true )
    {
      try
      {
        zmq::message_t message;
        if( !diag_socket.recv(&message) )
          continue;
        
        LogRecord rec;
        if( !message.data() || !message.size())
          continue;
        
        bool parsed = rec.ParseFromArray(message.data(), message.size());
        if( !parsed )
          continue;
        
        for( int i=0; i<rec.headers_size(); ++i )
          log_static_data.add_header(rec.process(),rec.headers(i));
        
        for( int i=0; i<rec.symbols_size(); ++i )
          log_static_data.add_symbol(rec.process(), rec.symbols(i));
        
        log_static_data.print_message(rec);

      }
      catch (const std::exception & e)
      {
        std::cerr << "cannot process message. exception: " << e.what() << "\n";
      }
      catch (...)
      {
        std::cerr << "unknown exception caught while processing log message\n";
      }
    }
  }
  catch (const std::exception & e)
  {
    return usage(e);
  }
  return 0;
}

