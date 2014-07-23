#include <gtest/gtest.h>
#include <memory>

class Cpp11Test : public testing::Test {
protected:
  Cpp11Test() {}
  virtual ~Cpp11Test() {}
};

TEST_F(Cpp11Test, Threading) {
}

int main(int argc, char **argv) 
{
  ::testing::InitGoogleTest(&argc, argv);
  return RUN_ALL_TESTS();
}

