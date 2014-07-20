#pragma once

namespace virtdb { namespace service { namespace common {

class base
{
  // copying is not allowed until properly implemented
  base(const base &) = delete;
  base & operator(const base &) = delete;

public:
  base() = default;
  virtual ~base() {}
};

}}} // virtdb/service/common

