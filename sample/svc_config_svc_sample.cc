
#include <svc_config.pb.h>
#include <logger.hh>
#include <util/exception.hh>
#include <zmq.hpp>
#include <memory>
#include <chrono>
#include <map>
#include <set>
#include <atomic>

using namespace virtdb::interface;

namespace
{
  template <typename EXC>
  int usage(const EXC & exc)
  {
    std::cerr << "Exception: " << exc.what() << "\n"
    << "\n"
    << "Usage: svc_config_svc_sample <Request-Reply-EndPoint> <Pub-Sub-Endpoint>\n"
    << "\n"
    << " endpoint examples: \n"
    << "  \"ipc:///tmp/svc_config-endpoint\"\n"
    << "  \"tcp://localhost:65001\"\n"
    << "  \"tcp://*:65001\"\n\n";
    return 100;
  }
  
  struct compare_endpoints
  {
    bool operator()(const pb::Endpoint & lhs,
                    const pb::Endpoint & rhs) const
    {
      if( lhs.name() < rhs.name() )
        return true;
      else if (lhs.name() > rhs.name() )
        return false;
      
      if( lhs.svctype() < rhs.svctype() )
        return true;
      else
        return false;
    }
  };
}

int main(int argc, char ** argv)
{
  using virtdb::logger::log_sink;
  
  try
  {
    if( argc < 3 )
    {
      THROW_("invalid number of arguments");
    }
    
    zmq::context_t context(1);
    zmq::socket_t  req_rep_socket(context,ZMQ_REP);
    zmq::socket_t  pub_sub_socket(context,ZMQ_PUB);
    
    // bind our two sockets
    req_rep_socket.bind( argv[1] );
    pub_sub_socket.bind( argv[2] );

    typedef std::set<pb::Endpoint, compare_endpoints> endpoint_set;

    // register our own endpoint service
    endpoint_set   endpoints;
    pb::Endpoint   self_endpoint;
    
    self_endpoint.set_name("svc_config");
    self_endpoint.set_svctype(pb::ServiceType::ENDPOINT);
    {
      auto conn = self_endpoint.add_connections();
      conn->set_type(pb::ConnectionType::REQ_REP);
      auto address = conn->add_address();
      *address = argv[1];
    }
    {
      auto conn = self_endpoint.add_connections();
      conn->set_type(pb::ConnectionType::PUB_SUB);
      auto address = conn->add_address();
      *address = argv[2];
    }
    
    endpoints.insert( self_endpoint );
    
    
    // svc: PUB/Cfg, PULL/Cfg, REP/EP, PUB/EP
    
    // 1, app->config_svc REQ:Endpoint ( 'ME', 'ENDPOINT' ) -> REP:Endpoint ( '*', '*' )
    // 2, app->config_svc PUSH:Config ()
    
   
#if 0
    // initialize 0MQ and logger
    zmq::context_t context(1);
    std::shared_ptr<zmq::socket_t> socket_sptr(new zmq::socket_t(context,ZMQ_PUSH));
    socket_sptr->connect(argv[1]);
    std::shared_ptr<log_sink> sink_sptr(new log_sink(socket_sptr));
#endif
  }
  catch (const std::exception & e)
  {
    return usage(e);
  }
  return 0;
}
