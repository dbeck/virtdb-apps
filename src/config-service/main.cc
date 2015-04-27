
#include <logger.hh>
#include <connector.hh>
#include <iostream>

using namespace virtdb::connector;

namespace
{
  template <typename EXC>
  int usage(const EXC & exc)
  {
    std::cerr << "Exception: " << exc.what() << "\n"
              << "\n"
              << "Usage: config-service <Request-Reply-EndPoint>\n"
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
    
    server_context::sptr   ctx{new server_context};
    client_context::sptr   cctx{new client_context};
    
    ctx->service_name("config-service");
    ctx->ip_discovery_timeout_ms(1);
    
    endpoint_server        ep_srv(ctx, argv[1], "config-service");
    endpoint_client        ep_clnt(cctx, ep_srv.local_ep(), ep_srv.name());
    log_record_client      log_clnt(cctx, ep_clnt, "diag-service");
    config_client          cfg_clnt(cctx, ep_clnt, "config-service");
    config_server          cfg_srv(ctx, cfg_clnt, ep_srv);
    
    ep_srv.reload_from("/tmp");
    cfg_srv.reload_from("/tmp");
    
    while( true )
    {
      std::this_thread::sleep_for(std::chrono::seconds(60));
      ep_srv.save_to("/tmp");
      cfg_srv.save_to("/tmp");
      LOG_TRACE("alive");
    }
  }
  catch (const std::exception & e)
  {
    return usage(e);
  }
  return 0;
}
