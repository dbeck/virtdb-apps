
#include <gtest/gtest.h>
#include <interface/common/common.pb.h>
#include <memory>

using namespace virtdb::interface::pb;

typedef std::shared_ptr<KeyValue> KeyValuePtr;

class KeyValueTest : public testing::Test {
protected:
  KeyValueTest() : kvptr_(new virtdb::interface::pb::KeyValue) {}
  virtual ~KeyValueTest() {}
  KeyValuePtr kvptr_;
};

TEST_F(KeyValueTest, GetSetString) {
  EXPECT_TRUE( this->kvptr_.get() != nullptr );
  this->kvptr_->set_stringvalue("Hello World");
  EXPECT_EQ( this->kvptr_->stringvalue(), "Hello World" );
}

int main(int argc, char **argv) 
{
  ::testing::InitGoogleTest(&argc, argv);
  return RUN_ALL_TESTS();
}

