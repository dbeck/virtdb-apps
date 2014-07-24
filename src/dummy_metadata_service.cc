#include <zmq.hpp>
#include <meta_data.pb.h>
#include <iostream>

int main()
{
  zmq::context_t ctx (1);
  zmq::socket_t s (ctx, ZMQ_REP);
  s.bind ("tcp://*:5555");
  while( true )
  {
    zmq::message_t request;
    s.recv (&request);
    std::cout << "new request arrived";
    // zmq::message_t reply (5);
    // memcpy ((void *) reply.data (), "World", 5);
    // socket.send (reply);
  }
  return 0;
}
