#include "meta_data.pb.h"
#include "common.pb.h"
#include <memory>

int main()
{
  using virtdb::interface::pb::MetaDataRequest;
  using virtdb::interface::pb::KeyValue;
  std::shared_ptr<MetaDataRequest> request(new MetaDataRequest);
  std::shared_ptr<KeyValue>        key_value(new KeyValue);
  return 0;
}

