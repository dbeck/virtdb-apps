
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
    
    endpoint_client     ep_clnt(argv[1], "diag-service");
    log_record_client   log_clnt(ep_clnt, "diag-service");
    config_client       cfg_clnt(ep_clnt, "config-service");
    log_record_server   log_svr(cfg_clnt);
    
    while( true )
    {
      // cleanup logs older than 1H
      // TODO : make this configurable
      log_svr.cleanup_older_than(3600000);
      std::this_thread::sleep_for(std::chrono::seconds(60));
      LOG_TRACE("alive" << V_(log_svr.cached_log_count()));
    }
  }
  catch (const std::exception & e)
  {
    return usage(e);
  }
  return 0;
}

