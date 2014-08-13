
#include <logger.hh>
#include <util/exception.hh>
#include <zmq.hpp>
#include <memory>
#include <chrono>
#include <thread>

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
  using virtdb::logger::log_sink;
  
  try
  {
    if( argc < 2 )
    {
      THROW_("invalid number of arguments");
    }
    
    // initialize 0MQ and logger
    zmq::context_t context(1);
    std::shared_ptr<zmq::socket_t> socket_sptr(new zmq::socket_t(context,ZMQ_PUSH));
    socket_sptr->connect(argv[1]);
    std::shared_ptr<log_sink> sink_sptr(new log_sink(socket_sptr));
    
    // tests
    log_info_test();
    log_error_test();
    log_scoped_test();
    
    // give a chance to log sender before we quit
    std::this_thread::sleep_for(std::chrono::milliseconds(1000));
  }
  catch (const std::exception & e)
  {
    return usage(e);
  }
  return 0;
}
