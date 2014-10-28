
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
    
    endpoint_client     ep_clnt(argv[1],     "dataprovider-client");
    log_record_client   log_clnt(ep_clnt,    "diag-service");
    column_client       column_clnt(ep_clnt, (argc>2 ? argv[2] : "testdata-provider"));
    meta_data_client    meta_clnt(ep_clnt,   (argc>2 ? argv[2] : "testdata-provider"));
    query_client        qry_clnt(ep_clnt,    (argc>2 ? argv[2] : "testdata-provider"));

    std::string         table_name{argc>2 ? argv[3] : ".*"};
    
    pb::MetaDataRequest req;
    req.set_name(table_name);
    req.set_withfields(false);
    
    bool meta_ret = meta_clnt.send_request(req,
                                           [](const pb::MetaData & rep) {
                                             LOG_TRACE("MetaData reply" << M_(rep));
                                     return true;
                                     },30000);

    LOG_TRACE("without fields" << V_(meta_ret));
    
    req.set_withfields(true);
    meta_ret =
      meta_clnt.send_request(req,
                             [](const pb::MetaData & rep) {
                                LOG_TRACE("MetaData reply" << M_(rep));
                                return true;
                               },99000);
    
    LOG_TRACE("with fields" << V_(meta_ret));
    
    pb::Query query;
    query.set_queryid("1");
    query.set_table("test-table");
    auto f1 = query.add_fields();
    f1->set_name("intfield");
    auto f1desc = f1->mutable_desc();
    f1desc->set_type(pb::Kind::INT32);

    auto f2 = query.add_fields();
    f2->set_name("strfield");
    auto f2desc = f2->mutable_desc();
    f2desc->set_type(pb::Kind::STRING);
    
    std::cout << "Start waiting for data for 10s\n\n";
    
    column_clnt.watch("*",[](const std::string & provider_name,
                             const std::string & channel,
                             const std::string & subscription,
                             std::shared_ptr<pb::Column> data)
    {
      std::cout << "PROVIDER      =" << provider_name << "\n"
                << "CHANNEL       ="  << channel << "\n"
                << "SUBSCRIPTION  =" << subscription << "\n"
                << "DATA          =\n" << data->DebugString() << "\n";
    });
    
    qry_clnt.send_request(query);
    
    std::this_thread::sleep_for(std::chrono::seconds(10));
    
    LOG_TRACE("exiting");
  }
  catch (const std::exception & e)
  {
    return usage(e);
  }
  return 0;
}
