#pragma once

#include <dsproxy/query_proxy.hh>
#include <cachedb/hash_util.hh>
#include <cachedb/db.hh>
#include <cachedb/query_table_log.hh>
#include <memory>
#include <chrono>

namespace virtdb { namespace simple_cache {
  
  class query_data
  {
    dsproxy::query_proxy::query_sptr          query_;
    std::chrono::system_clock::time_point     start_;
    std::string                               tab_hash_;
    cachedb::hash_util::colhash_map           col_hashes_;
    int64_t                                   timeout_seconds_;
    std::string                               error_info_;
    
  public:
    typedef std::shared_ptr<query_data> sptr;
    
    dsproxy::query_proxy::query_sptr query() const;
    std::chrono::system_clock::time_point start() const;
    const std::string & tab_hash() const;
    const cachedb::hash_util::colhash_map & col_hashes() const;
    
    const std::string & col_hash(const std::string & name) const;
    
    const std::string & error_info() const;
    void error_info(const std::string & err);
    
    query_data(dsproxy::query_proxy::query_sptr q,
               int64_t cache_timeout_seconds=60);
    
    
    bool has_cached_data(cachedb::db & cache);
    bool store_column_block(cachedb::db & cache,
                            const std::string & colname,
                            const std::string & column_hash);
    
    virtual ~query_data();
  };

}}
