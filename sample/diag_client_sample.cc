
#include <logger.hh>
#include <util.hh>
#include <connector.hh>
#include <memory>
#include <chrono>
#include <thread>

using namespace virtdb::interface;
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
  try
  {
    if( argc < 2 )
    {
      THROW_("invalid number of arguments");
    }
    
    endpoint_client     ep_clnt(argv[1], "diag-client");
    log_record_client   log_clnt(ep_clnt);

    // send test messages
    log_info_test();
    log_error_test();
    log_scoped_test();
    
    pb::GetLogs req;
    req.set_microsecrange(100000000);
    
    log_clnt.get_logs(req,
                      [](pb::LogRecord & rec){
      std::cout << "Log record arrived.\n"
                << rec.DebugString() << "\n"
                << " #data:" << rec.data_size()
                << " #headers:" << rec.headers_size()
                << " #symbols:" << rec.symbols_size()
                << "\n\n";
      return true;
    });
    
    std::cout << "Waiting for 20s to receive log records on the PUB channel\n\n";
    
    log_clnt.watch("hello-watch", [](const std::string & name,
                                     pb::LogRecord & rec) {
      
      std::cout << "Log record arrived (PUB-SUB).\n"
                << rec.DebugString() << "\n"
                << " #data:" << rec.data_size()
                << " #headers:" << rec.headers_size()
                << " #symbols:" << rec.symbols_size()
                << "\n\n";
    });
    
    std::this_thread::sleep_for(std::chrono::seconds(20));
    
    LOG_INFO("exiting");
    
  }
  catch (const std::exception & e)
  {
    return usage(e);
  }
  return 0;
}
