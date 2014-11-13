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
              << "Usage: remove-endpoint <ZeroMQ-EndPoint> <name>\n"
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
    std::string name{argv[2]};
    
    endpoint_client     ep_clnt(config_svc,  "remove-endpoint");
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
    
    typedef std::shared_ptr<pb::EndpointData> ep_sptr;
    typedef std::vector<ep_sptr>              ep_vec;
    
    ep_vec eps_to_remove;
    
    {
      // gather endpointa
      pb::EndpointData ep;
      ep.set_name("save-endpoints");
      ep.set_svctype(pb::ServiceType::NONE);
      
      auto process_endpoint = [&](const pb::EndpointData & ep) {
        LOG_TRACE(" " << V_(ep.name()) << V_(ep.connections_size()));
        if( ep.connections_size() > 0  && ep.name() == name )
        {
          ep_sptr to_remove{new pb::EndpointData};
          to_remove->set_name(ep.name());
          to_remove->set_svctype(ep.svctype());
          to_remove->set_validforms(1000);
          eps_to_remove.push_back(to_remove);
        }
        return true;
      };
      
      ep_clnt.register_endpoint(ep, process_endpoint);
    }
    
    {
      // send endpoint data for removal
      for( auto const & ep  : eps_to_remove )
      {
        LOG_TRACE("sending remove message" << M_(*ep));
        ep_clnt.register_endpoint(*ep);
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
