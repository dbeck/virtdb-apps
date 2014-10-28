#include <logger.hh>
#include <util.hh>
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
              << "Usage: load-config <ZeroMQ-EndPoint> <file>\n"
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
    std::string file{argv[2]};
    std::string config_svc{argv[1]};
    
    endpoint_client     ep_clnt(config_svc,  "save-configs");
    log_record_client   log_clnt(ep_clnt, "diag-service");
    config_client       cfg_clnt(ep_clnt, "config-service");
    
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
    
    if( !cfg_clnt.wait_valid_sub(10000) )
    {
      LOG_ERROR("failed to connect to config service at" << V_(config_svc));
      THROW_("cannot connect to config service");
    }
    if( !cfg_clnt.wait_valid_req(10000) )
    {
      LOG_ERROR("failed to connect to config service at" << V_(config_svc));
      THROW_("cannot connect to config service");
    }
  
    LOG_INFO("config client connected");
    
    {
      pb::Config cfg_req;
      // load config data
      std::ifstream ifs{file};
      if( ifs.is_open() )
      {
        if( cfg_req.ParseFromIstream(&ifs) )
        {
          auto process_config = [&](const pb::Config & cfg) {
            LOG_TRACE("config reply" << M_(cfg));
            return true;
          };
          
          if( !cfg_clnt.send_request(cfg_req, process_config, 30000) )
          {
            LOG_ERROR("failed to configure" << M_(cfg_req));
          }
          else
          {
            LOG_INFO("loaded config" << M_(cfg_req));
          }
        }
        else
        {
          LOG_ERROR("couldn't parse file" << file);
        }
      }
      else
      {
        LOG_ERROR("couldn't load file" << file);
      }
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
