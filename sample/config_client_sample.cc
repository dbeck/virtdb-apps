
#include <logger.hh>
#include <util.hh>
#include <connector.hh>
#include <chrono>
#include <thread>
#include <iostream>

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
              << "Usage: config_client_sample <ZeroMQ-EndPoint>\n"
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
    if( argc < 2 )
    {
      THROW_("invalid number of arguments");
    }
    
    endpoint_client     ep_clnt(argv[1], "config_client");
    log_record_client   log_clnt(ep_clnt);
    config_client       cfg_clnt(ep_clnt);

    cfg_clnt.watch(ep_clnt.name(),
                   [](const pb::Config & cfg)
    {
      std::cout << "Received config (SUB):\n" << cfg.DebugString() << "\n";
      return true;
    });
    
    pb::Config cfg_req;
    cfg_req.set_name(ep_clnt.name());
    
    cfg_clnt.get_config(cfg_req, [](const pb::Config & cfg)
    {
      std::cout << "Received config:\n" << cfg.DebugString() << "\n";
      return true;
    });

    auto cfgdata = cfg_req.mutable_configdata();
    cfgdata->set_key("Hello");
    auto mval = cfgdata->mutable_value();
    value_type<int32_t>::set(*mval, 1);

    
    for( int i=0;i<4;++i )
    {
      // give a chance to log sender to initialize
      std::this_thread::sleep_for(std::chrono::milliseconds(2000));
      
      cfg_clnt.get_config(cfg_req,
                          [](const pb::Config & cfg)
      {
        // don't care. want to see SUB messages ...
        return true;
      });
    }
    
    LOG_TRACE("exiting");
    ep_clnt.remove_watches();
    cfg_clnt.remove_watches();
  }
  catch (const std::exception & e)
  {
    return usage(e);
  }
  return 0;
}
