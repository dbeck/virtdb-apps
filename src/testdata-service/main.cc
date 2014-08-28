
#include <logger.hh>
#include <connector.hh>
#include <chrono>
#include <thread>
#include <iostream>

using namespace virtdb::interface;
using namespace virtdb::util;
using namespace virtdb::connector;

namespace
{
  template <typename EXC>
  int usage(const EXC & exc)
  {
    std::cerr << "Exception: " << exc.what() << "\n"
    << "\n"
    << "Usage: testdata-service <ZeroMQ-EndPoint>\n"
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
    
    endpoint_client     ep_clnt(argv[1], "diag_svc");
    log_record_client   log_clnt(ep_clnt);
    config_client       cfg_clnt(ep_clnt);
    column_server       col_srv(cfg_clnt);
    query_server        query_srv(cfg_clnt);
    meta_data_server    meta_srv(cfg_clnt);
    
    while( true )
    {
      std::this_thread::sleep_for(std::chrono::seconds(15));
      LOG_TRACE("alive");
    }
  }
  catch (const std::exception & e)
  {
    return usage(e);
  }
  return 0;
}

