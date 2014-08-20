
// proto
#include <svc_config.pb.h>
#include <logger.hh>
#include <util.hh>
#include <connector.hh>
// apps
#include <discovery.hh>
// others
#include <zmq.hpp>
#include <map>
#include <set>

using namespace virtdb;
using namespace virtdb::apps;
using namespace virtdb::interface;
using namespace virtdb::connector;

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
    bool operator()(const pb::EndpointData & lhs,
                    const pb::EndpointData & rhs) const
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
    if( argc < 2 )
    {
      THROW_("invalid number of arguments");
    }
    
    /*
    endpoint_server     ep_srv(argv[1]);
    endpoint_client     ep_clnt(ep_srv.local(), "svc_config");
    log_record_client   log_clnt(ep_clnt);
    config_client       cfg_clnt(ep_clnt);
    config_server       cfg_srv(cfg_clnt);
    */
    
    logger::process_info::set_app_name("svc_config");
    
    zmq::context_t context(2);
    zmq::socket_t  req_rep_socket(context,ZMQ_REP);
    zmq::socket_t  pub_sub_socket(context,ZMQ_PUB);

    req_rep_socket.bind( argv[1] );
    // pub sub sockets, kernel to chose a port available on all IPs
    pub_sub_socket.bind( "tcp://*:*" );
    
    // diag socket to be initialized when diag service registers itself
    std::shared_ptr<zmq::socket_t> diag_socket_sptr; // (new zmq::socket_t(context,ZMQ_PUSH));
    std::shared_ptr<log_sink> log_sink_sptr(new log_sink(diag_socket_sptr));
    
    int pubsub_zmq_port = 0;
    {
      // TODO: refactor to separate class ...
      char last_zmq_endpoint[512];
      last_zmq_endpoint[0] = 0;
      size_t opt_size = sizeof(last_zmq_endpoint);
      pub_sub_socket.getsockopt(ZMQ_LAST_ENDPOINT, last_zmq_endpoint, &opt_size);
      last_zmq_endpoint[sizeof(last_zmq_endpoint)-1] = 0;
      if( opt_size > 0 )
      {
        char * ptr = last_zmq_endpoint+opt_size;
        while( ptr > last_zmq_endpoint )
        {
          if( *ptr == ':' )
          {
            pubsub_zmq_port = atoi(ptr+1);
            break;
          }
          --ptr;
        }
      }
    }
    
    typedef std::set<pb::EndpointData, compare_endpoints> endpoint_set;
    endpoint_set       endpoints;
    
    // add IP discovery endpoints
    discovery_server   ip_discovery;
    pb::EndpointData   discovery_endpoint;

    size_t discovery_address_count = 0;
    discovery_endpoint.set_name("ip_discovery");
    discovery_endpoint.set_svctype(pb::ServiceType::IP_DISCOVERY);
    {
      auto disc_ep = ip_discovery.endpoints();
      auto conn = discovery_endpoint.add_connections();
      conn->set_type(pb::ConnectionType::RAW_UDP);

      for( auto const & it : disc_ep )
      {
        auto address = conn->add_address();
        *address = it;
        ++discovery_address_count;
      }
    }
    if( discovery_address_count > 0 )
    {
      endpoints.insert(discovery_endpoint);
    }
    
    // add self endpoints
    pb::EndpointData   self_endpoint;
    
    size_t svc_config_address_count = 0;
    self_endpoint.set_name("svc_config");
    self_endpoint.set_svctype(pb::ServiceType::ENDPOINT);
    {
      auto conn = self_endpoint.add_connections();
      conn->set_type(pb::ConnectionType::REQ_REP);
      // add address parameter
      auto address = conn->add_address();
      *address = argv[1];
      ++svc_config_address_count;
    }
    
    // pub sub sockets, one each on each IPs on a kernel chosen port
    if( pubsub_zmq_port )
    {
      // TODO : refactor self IP discovery to a support class...
      auto conn = self_endpoint.add_connections();
      conn->set_type(pb::ConnectionType::PUB_SUB);
      
      auto ips = util::net::get_own_ips(true);
      for( auto const & ip : ips )
      {
        std::ostringstream os;
        os << "tcp://";
        if( ip.find(':') == std::string::npos )
          os << ip << ":" << pubsub_zmq_port; // ipv4
        else
          os << '[' << ip << "]:" << pubsub_zmq_port; //ipv6
        
        auto address = conn->add_address();
        *address = os.str();
        ++svc_config_address_count;
      }
    }
    if( svc_config_address_count > 0 )
      endpoints.insert(self_endpoint);
    
    /*
    for( auto const & ep : endpoints )
      std::cerr << "configured endpoint: \n" << ep.DebugString() << "\n";
     */
    
    // loop, read endpoint requests
    size_t nth_request = 0;
    std::shared_ptr<pb::Endpoint> reply_data{new pb::Endpoint};
    
    while( true )
    {
      try
      {
        zmq::message_t message;
        if( !req_rep_socket.recv(&message) )
          continue;
        
        pb::Endpoint request;
        if( !message.data() || !message.size())
          continue;
        
        endpoint_set diag_eps;
        try
        {
          if( request.ParseFromArray(message.data(), message.size()) )
          {
            for( int i=0; i<request.endpoints_size(); ++i )
            {
              // ignore endpoints with no connections
              if( request.endpoints(i).connections_size() > 0 )
              {
                // remove old endpoints if exists
                auto it = endpoints.find(request.endpoints(i));
                if( it != endpoints.end() )
                  endpoints.erase(it);

                // insert endpoint
                endpoints.insert(request.endpoints(i));
                
                // take special care for log endpoints
                auto ep_data = request.endpoints(i);
                if( ep_data.svctype() == pb::ServiceType::LOG_RECORD )
                  diag_eps.insert(ep_data);
              }
            }
            std::cerr << "endpoint request arrived: \n" << request.DebugString() << "\n";
          }
        }
        catch (const std::exception & e)
        {
          // ParseFromArray may throw exceptions here but we don't care
          // of it does
          std::string exception_text{e.what()};
          LOG_ERROR("couldn't parse message" << exception_text);
        }
        catch( ... )
        {
          LOG_ERROR("unknown exception");
        }
        
        // reallocate our reply at every 1000th request
        if( (nth_request%1000) == 0 )
          reply_data.reset(new pb::Endpoint);
        
        // clearing previous data
        reply_data->Clear();
        
        // filling the reply
        for( auto const & ep_data : endpoints )
        {
          auto ep_ptr = reply_data->add_endpoints();
          ep_ptr->MergeFrom(ep_data);
        }
        
        int reply_size = reply_data->ByteSize();
        if( reply_size > 0 )
        {
          std::unique_ptr<unsigned char []> reply_msg{new unsigned char[reply_size]};
          bool serialzied = reply_data->SerializeToArray(reply_msg.get(),reply_size);
          if( serialzied )
          {
            // send reply
            req_rep_socket.send(reply_msg.get(), reply_size);
            
            // publish new messages one by one
            for( int i=0; i<request.endpoints_size(); ++i )
            {
              auto ep = request.endpoints(i);
              if( ep.svctype() != pb::ServiceType::NONE &&
                  ep.connections_size() > 0 )
              {
                pb::Endpoint publish_ep;
                publish_ep.add_endpoints()->MergeFrom(request.endpoints(i));
                std::ostringstream os;
                os << ep.svctype() << '.' << ep.name();
                std::string subscription{os.str()};
                pub_sub_socket.send(subscription.c_str(), subscription.length(), ZMQ_SNDMORE);
                pub_sub_socket.send(message.data(), message.size());
              }
            }
          }
          else
          {
            LOG_ERROR( "couldn't serialize Endpoint reply message." << V_(reply_size) );
          }
        }
        
        // TODO : refactor this part into a helper class...
        
        // check if the message was a diag server endpoint change
        // end make sure we reconnect to the new address
        if( !diag_eps.empty() )
        {
          // we only care about the first endpoint
          auto diag_ep = diag_eps.begin();
          
          std::string ipv4, ipv6;
          
          for( int i=0; i<diag_ep->connections_size(); ++i )
          {
            auto & conn = diag_ep->connections(i);
            for( int ii=0; ii<conn.address_size(); ++ii )
            {
              auto address = conn.address(ii);
          
              // separate ipv4 and ipv6 as ipv4 takes precedence
              if( address.find("//[") != std::string::npos &&
                  address.find("]:") != std::string::npos )
                ipv6 = address;
              else
                ipv4 = address;
            }
          }
          
          // ipv4 takes precedence
          std::string zmq_address;
          if( !ipv4.empty() )
            zmq_address = ipv4;
          else if( !ipv6.empty())
            zmq_address = ipv6;
          
          if( !zmq_address.empty() )
          {
            // resetting log sink
            diag_socket_sptr.reset(new zmq::socket_t(context,ZMQ_PUSH));
            log_sink_sptr.reset(new log_sink(diag_socket_sptr));
            // log connect is being done async
            std::thread connect_logger([zmq_address,&diag_socket_sptr]() {
              try {
                // no exceptions are allowed from this thread
                diag_socket_sptr->connect(zmq_address.c_str());
              } catch (...) { }
            });
            // we don't wait for this to complete
            connect_logger.detach();
            LOG_INFO("logger configured");
          }
        }
      }
      catch( const std::exception & e )
      {
        std::string exception_text{e.what()};
        LOG_ERROR("error during processing Endpoint request: " << V_(exception_text));
      }
      catch(...)
      {
        LOG_ERROR("unknown error during Endpoint request processing");
      }
    }
  }
  catch (const std::exception & e)
  {
    return usage(e);
  }
  return 0;
}
