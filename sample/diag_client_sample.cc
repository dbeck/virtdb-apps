
#include <logger.hh>
#include <util.hh>
#include <connector.hh>
#include <zmq.hpp>
#include <memory>
#include <chrono>
#include <thread>

using namespace virtdb;
using namespace virtdb::connector;

namespace
{
  template <typename EXC>
  int usage(const EXC & exc)
  {
    std::cerr << "Exception: " << exc.what() << "\n"
              << "\n"
              << "Usage: diag_client_sample <ZeroMQ-EndPoint>\n"
              << "\n"
              << " endpoint examples: \n"
              << "  \"ipc:///tmp/diag-endpoint\"\n"
              << "  \"tcp://localhost:65001\"\n\n";
    return 100;
  }
  
  void log_info_test()
  {
    LOG_INFO("testing simple info");
  }
  
  void log_error_test()
  {
    LOG_ERROR("humidity exceeds" << 0.98 << "percent");
  }
  
  void log_scoped_test()
  {
    for( int i=100; i<105; ++i )
    {
      int celsius = i;
      LOG_SCOPED("temperature is" << V_(celsius) << "degrees");
    }
  }
}

int main(int argc, char ** argv)
{
  using logger::log_sink;
  
  try
  {
    if( argc < 2 )
    {
      THROW_("invalid number of arguments");
    }
    
    endpoint_client     ep_clnt(argv[1], "diag_client");
    log_record_client   log_clnt(ep_clnt);

    for( int i=0;i<4;++i )
    {
      // give a chance to log sender to initialize
      std::this_thread::sleep_for(std::chrono::milliseconds(2000));
    
      // tests
      log_info_test();
      log_error_test();
      log_scoped_test();
    }
    
    LOG_INFO("exiting");
    
  }
  catch (const std::exception & e)
  {
    return usage(e);
  }
  return 0;
}
