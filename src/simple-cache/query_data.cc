#ifdef RELEASE
#define LOG_TRACE_IS_ENABLED false
#define LOG_SCOPED_IS_ENABLED false
#endif //RELEASE

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
    const std::string & colhash = this->col_hash(colname);
    qcb.key(colhash, start_, seq_no);
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
      auto it = complete_map_.find(seq_no);
      if( it == complete_map_.end() )
      {
        auto rit = complete_map_.insert(std::make_pair(seq_no, colhash_set_t()));
        it = rit.first;
      }
      it->second.insert(colhash);
      return true;
    }
  }
  
  bool
  query_data::update_table_block(cachedb::db & cache,
                                 const std::string & colname,
                                 size_t seq_no,
                                 cachedb::query_table_block & qtb)
  {
    qtb.key(tab_hash_, start_, seq_no);
    const std::string & colhash = this->col_hash(colname);
    size_t res = cache.fetch(qtb);
    auto it = complete_map_.find(seq_no);
    if( it == complete_map_.end() )
    {
      auto rit = complete_map_.insert(std::make_pair(seq_no, colhash_set_t()));
      it = rit.first;
    }
    it->second.insert(colhash);
    
    // set properties
    qtb.n_columns(col_hashes_.size());
    qtb.n_columns_complete(it->second.size());
    qtb.is_complete(col_hashes_.size() == it->second.size());
    
    // update database
    res = cache.set(qtb);
    return (res >= 3);
  }
  
  bool
  query_data::update_table_log(cachedb::db & cache,
                               cachedb::query_table_log & qtl)
  {
    qtl.key(tab_hash_);
    qtl.n_columns(col_hashes_.size());
    size_t res = cache.fetch(qtl);
    
    // make the previous entry obsolete
    qtl.t1_completed_at(qtl.t0_completed_at());
    qtl.t1_nblocks(qtl.t0_nblocks());
    
    // update the current entry
    qtl.t0_completed_at(start_);
    qtl.t0_nblocks(complete_map_.size());
    
    // update database
    res = cache.set(qtl);
    return (res >= 5);
  }
  
  bool
  query_data::is_complete(size_t seq_no)
  {
    size_t ncolumns = this->col_hashes_.size();
    for( size_t i=0; i<=seq_no; ++i )
    {
      auto it = complete_map_.find(i);
      if( it == complete_map_.end() )
      {
        LOG_TRACE("not complete" << V_(seq_no) << V_(i) << "not found");
        return false;
      }
      if( it->second.size() != ncolumns )
      {
        LOG_TRACE("block not complete" << V_(seq_no) << V_(i) << V_(it->second.size()));
        return false;
      }
    }
    LOG_TRACE("complete" << V_(seq_no));
    return true;
  }
  
  query_data::~query_data()
  {
  }
  
}}

