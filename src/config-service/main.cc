
#include <logger.hh>
#include <util/constants.hh>
#include <connector.hh>
#include <iostream>

using namespace virtdb::connector;
using namespace virtdb::util;

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
    server_context::sptr   sctx{new server_context};
    server_context::sptr   mctx{new server_context};
    client_context::sptr   cctx{new client_context};
    
    ctx->service_name("config-service");
    ctx->endpoint_svc_addr(argv[1]);
    ctx->ip_discovery_timeout_ms(1);

    sctx->service_name("security-service");
    sctx->endpoint_svc_addr(argv[1]);

    mctx->service_name("monitoring-service");
    mctx->endpoint_svc_addr(argv[1]);

    endpoint_server        ep_srv(ctx);
    // load existing data early
    ep_srv.reload_from("/tmp");

    endpoint_client        ep_clnt(cctx, ep_srv.local_ep(), ep_srv.name());
    log_record_client      log_clnt(cctx, ep_clnt, "diag-service");
    config_client          cfg_clnt(cctx, ep_clnt, "config-service");
    
    for( auto const & ep : ep_srv.endpoint_hosts() )
    {
      ctx->bind_also_to(ep);
      sctx->bind_also_to(ep);
      mctx->bind_also_to(ep);
    }
    
    ctx->ip_discovery_timeout_ms(2000);
    sctx->ip_discovery_timeout_ms(2000);
    
    config_server              cfg_srv(ctx, cfg_clnt);
    // load existing data early
    cfg_srv.reload_from("/tmp");
    
    srcsys_credential_server   scred_server(sctx, cfg_clnt);
    cert_store_server          cert_store(sctx, cfg_clnt);
    // no user manager registered here
    
    monitoring_server mon_srv(mctx, cfg_clnt);
    monitoring_client mon_cli(cctx, ep_clnt, "monitoring-service");
    mon_cli.wait_valid();
    
    // register endpoint monitoring here
    ep_srv.on_up_down([&mon_cli](const std::string & name, bool is_up) {
      mon_cli.report_up_down(name, is_up, "config-service");
    });
    
    while( true )
    {
      ctx->keep_alive(ep_clnt);
      sctx->keep_alive(ep_clnt);
      mctx->keep_alive(ep_clnt);
      std::this_thread::sleep_for(std::chrono::milliseconds(DEFAULT_ENDPOINT_EXPIRY_MS/3));
      ep_srv.save_to("/tmp");
      cfg_srv.save_to("/tmp");
    }
  }
  catch (const std::exception & e)
  {
    return usage(e);
  }
  return 0;
}
