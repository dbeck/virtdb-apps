#include "query_data.hh"
#include <logger.hh>

using namespace virtdb::cachedb;

namespace virtdb { namespace simple_cache {
  
  dsproxy::query_proxy::query_sptr
  query_data::query() const
  {
    return query_;
  }
  
  std::chrono::system_clock::time_point
  query_data::start() const
  {
    return start_;
  }
  
  const std::string &
  query_data::tab_hash() const
  {
    return tab_hash_;
  }
  
  const cachedb::hash_util::colhash_map &
  query_data::col_hashes() const
  {
    return col_hashes_;
  }
  
  const std::string &
  query_data::col_hash(const std::string & name) const
  {
    static const std::string empty;
    auto it = col_hashes_.find(name);
    if( it == col_hashes_.end() )
      return empty;
    else
      return it->second;
  }
  
  const std::string &
  query_data::error_info() const
  {
    return error_info_;
  }

  void
  query_data::error_info(const std::string & err)
  {
    error_info_ = err;
  }
  
  query_data::query_data(dsproxy::query_proxy::query_sptr q,
             int64_t cache_timeout_seconds)
  : query_{q},
    start_{std::chrono::system_clock::now()},
    timeout_seconds_{cache_timeout_seconds}
  {
    cachedb::hash_util::hash_query(*query_,
                                   tab_hash_,
                                   col_hashes_);
  }
  
  bool
  query_data::has_cached_data(cachedb::db & cache)
  {
    using namespace virtdb::cachedb;
    using namespace std::chrono;
    query_table_log qtl;
    qtl.key(tab_hash_);
    size_t ret = cache.fetch(qtl);
    if( ret > 0 )
    {
      std::string t0;
      bool converted = storeable::convert(qtl.t0_completed_at(), t0);
      
      auto now = system_clock::now();
      int64_t difftime = duration_cast<std::chrono::seconds>(now - qtl.t0_completed_at()).count();
      
      LOG_INFO(V_(qtl.clazz()) <<
               V_(query_->queryid()) <<
               "has" << V_(ret) << "properties" <<
               V_(qtl.n_columns()) <<
               V_(qtl.t0_nblocks()) <<
               V_(t0) <<
               V_(converted) <<
               V_(difftime) <<
               V_(timeout_seconds_) );
      
      if( converted &&
         qtl.t0_nblocks() > 0 &&
         qtl.n_columns() > 0 &&
         difftime < timeout_seconds_ )
      {
        return true;
      }
    }
    return false;
  }
  
  bool
  query_data::store_column_block(cachedb::db & cache,
                                 const std::string & colname,
                                 const std::string & column_hash,
                                 size_t seq_no,
                                 cachedb::query_column_block & qcb)
  {
    qcb.key(this->col_hash(colname), start_, seq_no);
    qcb.column_hash(column_hash);
    size_t res = cache.set(qcb);
    if( res != 1 )
    {
      LOG_ERROR("failed to store query_column_block" <<
                V_(query()->queryid()) <<
                V_(query()->schema()) <<
                V_(query()->table()) <<
                V_(colname) <<
                V_(seq_no) <<
                V_(column_hash) <<
                V_(res) );
      return false;
    }
    else
    {
      return true;
    }
  }
  
  bool
  query_data::update_column_job(cachedb::db & cache,
                                const std::string & colname,
                                size_t seq_no,
                                bool last,
                                cachedb::query_column_job & qcj)
  {
    qcj.key(this->col_hash(colname), start_);
    size_t res = cache.fetch(qcj);
    if( qcj.is_complete() )
    {
      LOG_ERROR("unexpected state" <<
                V_(qcj.clazz()) <<
                V_(query()->queryid()) <<
                V_(query()->schema()) <<
                V_(query()->table()) <<
                V_(colname) <<
                V_(seq_no) <<
                V_(last) <<
                V_(qcj.is_complete()) <<
                V_(qcj.max_block()) <<
                V_(qcj.block_count()) <<
                V_(res));
      return false;
    }
    
    // set properties and update database
    qcj.is_complete(last);
    if( qcj.max_block() < seq_no ) qcj.max_block(seq_no);
    qcj.block_count(qcj.block_count()+1);
    res = cache.set(qcj);
    return (res >= 3); // at least the number of columns
  }
  
  bool
  query_data::update_column_log(cachedb::db & cache,
                                const std::string & colname,
                                const cachedb::query_column_job & qcj,
                                cachedb::query_column_log & qcl)
  {
    qcl.key(this->col_hash(colname));
    size_t res = cache.fetch(qcl);
    
    
  }
  
  query_data::~query_data()
  {
  }
  
}}

