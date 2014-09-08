
#include <logger.hh>
#include <connector.hh>
#include <iostream>

using namespace virtdb::connector;
using namespace virtdb::interface;

namespace
{
  template <typename EXC>
  int usage(const EXC & exc)
  {
    std::cerr << "Exception: " << exc.what() << "\n"
              << "\n"
              << "Usage: dataprovider_client_sample <ZeroMQ-EndPoint>\n"
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
    if( argc < 2 )
    {
      THROW_("invalid number of arguments");
    }
    
    endpoint_client     ep_clnt(argv[1], "dataprovider-client");
    log_record_client   log_clnt(ep_clnt);
    column_client       column_clnt(ep_clnt, "testdata-provider");
    meta_data_client    meta_clnt(ep_clnt, "testdata-provider");
    
    /*
     public req_client<interface::pb::MetaDataRequest,
     interface::pb::MetaData>
     */
    
    pb::MetaDataRequest req;
    req.set_name(".*");
    req.set_withfields(false);
    
    meta_clnt.send_request(req,
                           [](const pb::MetaData & rep) {
                             std::cout << "MetaData reply:\n" << rep.DebugString() << "\n";
                             return true;
                           },
                           1000);

    req.set_withfields(true);
    meta_clnt.send_request(req,
                           [](const pb::MetaData & rep) {
                             std::cout << "MetaData reply:\n" << rep.DebugString() << "\n";
                             return true;
                           },
                           1000);

    
    // TODO :
    // query_client
    //
    
    LOG_TRACE("exiting");
  }
  catch (const std::exception & e)
  {
    return usage(e);
  }
  return 0;
}
