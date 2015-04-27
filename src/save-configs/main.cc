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
              << "Usage: save-configs <ZeroMQ-EndPoint> <path>\n"
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
    
    client_context::sptr   cctx{new client_context};
    endpoint_client        ep_clnt(cctx, config_svc,  "save-configs");
    log_record_client      log_clnt(cctx, ep_clnt,    "diag-service");
    config_client          cfg_clnt(cctx, ep_clnt,    "config-service");
    
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
    
    std::set<std::string> services;

    {
      // gather service names
      pb::EndpointData ep;
      ep.set_name("save-configs");
      ep.set_svctype(pb::ServiceType::NONE);
      
      auto process_endpoint = [&](const pb::EndpointData & ep) {
        services.insert(ep.name());
      };
      
      ep_clnt.register_endpoint(ep, process_endpoint);
    }
    
    {
      // gather configs
      auto process_config = [&](const pb::Config & cfg) {
        LOG_TRACE(" " << V_(cfg.name()) << V_(cfg.configdata_size()));
        if( cfg.configdata_size() > 0 )
        {
          std::string file_name{path + '/' + cfg.name() + ".pbconf"};
          std::ofstream outfile{file_name};
          if( outfile.is_open() )
          {
            cfg.SerializeToOstream(&outfile);
            LOG_TRACE("config for" <<
                      V_(cfg.name()) <<
                      "was written to" <<
                      V_(file_name));
            
          }
        }
        return true;
      };
      
      for( auto const & s : services )
      {
        LOG_TRACE(" " << V_(s));
        pb::Config cfg_req;
        cfg_req.set_name(s);
        cfg_clnt.send_request(cfg_req, process_config, 30000);
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
