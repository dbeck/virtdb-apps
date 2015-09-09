
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
              << "Usage: diag-service <ZeroMQ-EndPoint>\n"
              << "\n"
              << " endpoint examples: \n"
              << "  \"ipc:///tmp/diag-endpoint\"\n"
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
    server_context::sptr  ctx{new server_context};
    client_context::sptr  cctx{new client_context};
    
    ctx->service_name("diag-service");
    ctx->endpoint_svc_addr(argv[1]);
    
    endpoint_client       ep_clnt(cctx, argv[1], "diag-service");
    log_record_client     log_clnt(cctx, ep_clnt, "diag-service");
    config_client         cfg_clnt(cctx, ep_clnt, "config-service");
    log_record_server     log_svr(ctx, cfg_clnt);
    
    while( true )
    {
      // cleanup logs older than 1H
      // TODO : make this configurable
      if( !ctx->keep_alive(ep_clnt) )
      {
        ep_clnt.reconnect();
      }
      log_svr.cleanup_older_than(3600000);
      std::this_thread::sleep_for(std::chrono::milliseconds(DEFAULT_ENDPOINT_EXPIRY_MS/3));
    }
  }
  catch (const std::exception & e)
  {
    return usage(e);
  }
  return 0;
}

