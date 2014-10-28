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
              << "Usage: load-endpoint <ZeroMQ-EndPoint> <file>\n"
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
    std::string file{argv[2]};
    
    endpoint_client     ep_clnt(config_svc,  "load-endpoint");
    log_record_client   log_clnt(ep_clnt, "diag-service");
    
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
    
    {
      // load endpoint data
      pb::EndpointData ep;
      std::ifstream ifs{file};
      if( ifs.is_open() )
      {
        if( ep.ParseFromIstream(&ifs) )
        {
          ep_clnt.register_endpoint(ep);
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
  }
  catch (const std::exception & e)
  {
    return usage(e);
  }
  return 0;
}

