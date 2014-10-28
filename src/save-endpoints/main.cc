#include <logger.hh>
#include <util.hh>
#include <connector.hh>
#include <chrono>
#include <mutex>
#include <iostream>
#include <fstream>
#include <set>

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
    std::string path{argv[2]};
    
    endpoint_client     ep_clnt(argv[1],  "save-endpoints");
    log_record_client   log_clnt(ep_clnt, "diag-service");
    
    log_clnt.wait_valid_push();
    LOG_INFO("log connected");
    
    {
      // gather endpointa
      pb::EndpointData ep;
      ep.set_name("save-endpoints");
      ep.set_svctype(pb::ServiceType::NONE);
      
      auto process_endpoint = [&](const pb::EndpointData & ep) {
        LOG_TRACE(" " << V_(ep.name()) << V_(ep.connections_size()));
        std::string file_name{path + '/' + ep.name() + ".pbep"};
        std::ofstream outfile{file_name};
        if( outfile.is_open() )
        {
          ep.SerializeToOstream(&outfile);
          LOG_TRACE("endpoints for" <<
                    V_(ep.name()) <<
                    "was written to" <<
                    V_(file_name));
          
        }
        
        return true;
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
