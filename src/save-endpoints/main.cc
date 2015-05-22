#include <logger.hh>
#include <util/exception.hh>
#include <connector.hh>
#include <chrono>
#include <mutex>
#include <iostream>
#include <fstream>
#include <set>

using namespace virtdb;
using namespace virtdb::util;
using namespace virtdb::connector;
using namespace virtdb::interface;

namespace
{
  template <typename EXC>
  int usage(const EXC & exc)
  {
    std::cerr << "Exception: " << exc.what() << "\n"
              << "\n"
              << "Usage: save-endpoints <ZeroMQ-EndPoint> <path>\n"
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
    if( argc < 3 )
    {
      THROW_("invalid number of arguments");
    }
    std::string config_svc{argv[1]};
    std::string path{argv[2]};
    
    client_context::sptr  cctx{new client_context};
    endpoint_client       ep_clnt(cctx, config_svc,  "save-endpoints");
    log_record_client     log_clnt(cctx, ep_clnt,    "diag-service");
    
    logger::log_sink::socket_sptr dummy_socket;
    logger::log_sink::sptr        sink_stderr;
    
    if( log_clnt.wait_valid_push(util::DEFAULT_TIMEOUT_MS) )
    {
      LOG_INFO("log connected");
    }
    else
    {
      sink_stderr.reset(new logger::log_sink{dummy_socket});
    }
    
    {
      // gather endpointa
      pb::EndpointData ep;
      ep.set_name("save-endpoints");
      ep.set_svctype(pb::ServiceType::NONE);
      ep.set_validforms(100);
      ep.set_cmd(pb::EndpointData::LIST);
      
      auto process_endpoint = [&](const pb::EndpointData & ep) {
        LOG_TRACE(" " << V_(ep.name()) << V_(ep.connections_size()));
        std::string file_name{path + '/' + ep.name() + ".pbep" + '-' + pb::ServiceType_Name(ep.svctype())};
        std::ofstream outfile{file_name};
        if( outfile.is_open() )
        {
          ep.SerializeToOstream(&outfile);
          LOG_TRACE("endpoints for" <<
                    V_(ep.name()) <<
                    "was written to" <<
                    V_(file_name));
          
        }
      };
      
      ep_clnt.register_endpoint(ep, process_endpoint);
    }
    
    LOG_TRACE("exiting");
    ep_clnt.remove_watches();
  }
  catch (const std::exception & e)
  {
    return usage(e);
  }
  return 0;
}
