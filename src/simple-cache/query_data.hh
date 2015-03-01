#pragma once

#include <dsproxy/query_proxy.hh>
#include <cachedb/hash_util.hh>
#include <cachedb/db.hh>
#include <cachedb/query_column_block.hh>
#include <cachedb/query_table_block.hh>
#include <cachedb/query_table_log.hh>

#include <memory>
#include <chrono>
#include <map>
#include <set>

// test related
#include <util/table_collector.hh>

namespace virtdb { namespace simple_cache {
  
  class query_data
  {
    typedef std::set<std::string>             colhash_set_t;
    typedef std::map<size_t,colhash_set_t>    block_hash_set_t;
    
    dsproxy::query_proxy::query_sptr          query_;
    std::chrono::system_clock::time_point     start_;
    std::string                               tab_hash_;
    cachedb::hash_util::colhash_map           col_hashes_;
    int64_t                                   timeout_seconds_;
    std::string                               error_info_;
    block_hash_set_t                          complete_map_;
    bool                                      end_of_data_;
    
  public:
    typedef std::shared_ptr<query_data> sptr;
    
    dsproxy::query_proxy::query_sptr query() const;
    const std::string & tab_hash() const;
    const cachedb::hash_util::colhash_map & col_hashes() const;
    const std::string & col_hash(const std::string & name) const;
    
    const std::string & error_info() const;
    void error_info(const std::string & err);
    
    void start(const std::chrono::system_clock::time_point & st);
    std::chrono::system_clock::time_point start() const;
    
    size_t block_count() const;
    size_t complete_count() const;
    size_t max_block() const;
    std::string missing() const;
    bool end_of_data(bool value);
    
    query_data(dsproxy::query_proxy::query_sptr q,
               int64_t cache_timeout_seconds=86400);
    
    
    bool
    has_cached_data(cachedb::db & cache);
    
    bool
    store_column_block(cachedb::db & cache,
                       const std::string & colname,
                       const std::string & column_hash,
                       size_t seq_no,
                       bool end_of_data,
                       cachedb::query_column_block & qcb);

    bool
    update_table_block(cachedb::db & cache,
                       const std::string & colname,
                       size_t seq_no,
                       cachedb::query_table_block & qtb);
    
    bool
    is_complete(size_t seq_no);
    
    bool
    update_table_log(cachedb::db & cache,
                     cachedb::query_table_log & qtl);
    
    virtual ~query_data();
    
    void init_test();
    void test_add_col(std::shared_ptr<interface::pb::Column> dta);
    void decompress_test();
    
  private:
    typedef util::table_collector<interface::pb::Column> collector_t;
    typedef typename collector_t::sptr                   collector_sptr_t;
    typedef std::map<std::string, size_t>                column_idx_map_t;
    
    collector_sptr_t collector_sptr_;
    column_idx_map_t column_idxs_;

  };

}}
