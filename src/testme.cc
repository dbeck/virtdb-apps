#include "meta_data.pb.h"
#include <memory>

int main()
{
  using virtdb::interface::pb::MetaDataRequest;
  std::shared_ptr<MetaDataRequest> request(new MetaDataRequest);
  return 0;
}

