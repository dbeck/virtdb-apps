#pragma once

#include <util/barrier.hh>
#include <utility>
#include <vector>
#include <string>
#include <thread>
#include <atomic>

namespace virtdb { namespace apps {

  class discovery
  {
  public:
    typedef std::vector<std::string> endpoint_vector;
  };
  
  class discovery_client final : public discovery
  {
  public:
    // returns our IP as the discovery server sees it, so we
    // will know if there is NAT between us and the discovery server
    // possible formats are:
    //   123.123.123.123:65432  for ipv4
    //   [1::2::3::4::]:65432   for ipv6
    static std::string
    get_ip(const endpoint_vector & srv_endpoints);
  };
  
  class discovery_server final : public discovery
  {
  public:
    discovery_server();
    ~discovery_server();
    
    // this function tells where the server bound to
    // returns a vector of strings:
    //   123.123.123.123:65432  for ipv4
    //   [1::2::3::4::]:65432   for ipv6
    const endpoint_vector &
    endpoints() const;
    
  private:
    void handle_requests();
    
    endpoint_vector    endpoints_;
    util::barrier      barrier_;
    std::atomic<bool>  stop_me_;
    std::thread        worker_;
    int                fd_ipv4_;
    int                fd_ipv6_;
  };
}}
