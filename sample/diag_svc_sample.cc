
#include <diag.pb.h>
#include <logger.hh>
#include <util/exception.hh>
#include <util/net.hh>
#include <zmq.hpp>
#include <iostream>
#include <map>

using namespace virtdb::interface;
using namespace virtdb::util;

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
  
  struct compare_process_info
  {
    bool operator()(const virtdb::interface::pb::ProcessInfo & lhs,
                    const virtdb::interface::pb::ProcessInfo & rhs) const
    {
      if( lhs.startdate() < rhs.startdate() )
        return true;
      else if( lhs.startdate() > rhs.startdate() )
        return false;
      
      if( lhs.starttime() < rhs.starttime() )
        return true;
      else if( lhs.starttime() > rhs.starttime() )
        return false;
      
      if( lhs.pid() < rhs.pid() )
        return true;
      else if( lhs.pid() > rhs.pid() )
        return false;
      
      if( lhs.random() < rhs.random() )
        return true;
      else if( lhs.random() > rhs.random() )
        return false;
      else
        return false;
    }
  };
  
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

    zmq::context_t context(1);
    zmq::socket_t socket(context, ZMQ_PULL);
    socket.bind(argv[1]);
    
    log_data log_static_data;
    
    
    while( true )
    {
      zmq::message_t message;
      if( !socket.recv(&message) )
        continue;
      
      LogRecord rec;
      if( !message.data() || !message.size())
        continue;
      
      rec.ParseFromArray(message.data(), message.size());
      
      for( int i=0; i<rec.headers_size(); ++i )
        log_static_data.add_header(rec.process(),rec.headers(i));
      
      for( int i=0; i<rec.symbols_size(); ++i )
        log_static_data.add_symbol(rec.process(), rec.symbols(i));

      int fd;
      size_t len = sizeof(fd);
      socket.getsockopt(ZMQ_FD, &fd, &len);
      auto peer = net::get_peer_ip(fd);
      std::cout << fd << " " << peer.first << ":" << peer.second << "\n";
      
      log_static_data.print_message(rec);
    }
  }
  catch (const std::exception & e)
  {
    return usage(e);
  }
  return 0;
}

