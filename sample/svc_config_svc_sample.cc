
// proto
#include <svc_config.pb.h>
#include <logger.hh>
#include <util.hh>
#include <connector.hh>
// others
#include <zmq.hpp>
#include <map>
#include <set>

using namespace virtdb;
using namespace virtdb::interface;
using namespace virtdb::connector;

namespace
{
  template <typename EXC>
  int usage(const EXC & exc)
  {
    std::cerr << "Exception: " << exc.what() << "\n"
              << "\n"
              << "Usage: svc_config_svc_sample <Request-Reply-EndPoint> <Pub-Sub-Endpoint>\n"
              << "\n"
              << " endpoint examples: \n"
              << "  \"ipc:///tmp/svc_config-endpoint\"\n"
              << "  \"tcp://localhost:65001\"\n"
              << "  \"tcp://*:65001\"\n\n";
    return 100;
  }
}

int main(int argc, char ** argv)
{
  using virtdb::logger::log_sink;
  
  try
  {
    if( argc < 2 )
    {
      THROW_("invalid number of arguments");
    }
    
    endpoint_server     ep_srv(argv[1],"svc_config");
    endpoint_client     ep_clnt(ep_srv.local_ep(), ep_srv.name());
    log_record_client   log_clnt(ep_clnt);
    // TODO : config client
    config_client       cfg_clnt(ep_clnt);
    config_server       cfg_srv(cfg_clnt, ep_srv);
    
    while( true )
    {
      std::this_thread::sleep_for(std::chrono::seconds(15));
      LOG_INFO("alive");
    }

  }
  catch (const std::exception & e)
  {
    return usage(e);
  }
  return 0;
}
