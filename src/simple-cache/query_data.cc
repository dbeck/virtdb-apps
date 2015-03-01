#ifdef RELEASE
#define LOG_TRACE_IS_ENABLED false
#define LOG_SCOPED_IS_ENABLED false
#endif //RELEASE

#include "query_data.hh"
#include <logger.hh>
#include <util/exception.hh>
#include <util/flex_alloc.hh>
#include <util/relative_time.hh>
#include <util/active_queue.hh>
#include <lz4/lib/lz4.h>
#include <memory>
#include <google/protobuf/io/coded_stream.h>

using namespace virtdb::cachedb;

namespace virtdb { namespace simple_cache {
  
  void
  query_data::init_test()
  {
#ifndef RELEASE
    collector_sptr_.reset(new collector_t(col_hashes_.size()));
    for( int i=0; i<query_->fields_size(); ++i )
    {
      column_idxs_[query_->fields(i).name()] = i;
    }
#endif
  }
  
  void
  query_data::test_add_col(std::shared_ptr<interface::pb::Column> dta)
  {
#ifndef RELEASE
    auto it = column_idxs_.find(dta->name());
    if( it == column_idxs_.end() ) { THROW_("invalid column name"); }
    collector_sptr_->insert( dta->seqno(), it->second, dta );
#endif
  }
  
  void
  query_data::decompress_test()
  {
#ifndef RELEASE
    util::relative_time tm;
    
    size_t max_b = collector_sptr_->max_block_id();
    std::atomic<size_t> decompressed{0};
    std::atomic<size_t> orig_bytes{0};
    std::atomic<size_t> decomp_bytes{0};
    
    auto decompress = [&](std::shared_ptr<interface::pb::Column> dta)
    {
      int maxDecompressedSize = dta->uncompressedsize();
      util::flex_alloc<char,64*1024> buffer(maxDecompressedSize);
      int compSize = dta->compresseddata().size();
      char* destinationBuffer = buffer.get();
      int comp_ret = LZ4_decompress_safe(dta->compresseddata().c_str(),
                                         destinationBuffer,
                                         dta->compresseddata().size(),
                                         maxDecompressedSize);
      if( comp_ret <= 0 )
      {
        THROW_("failed to decompress data");
      }
      
      google::protobuf::io::CodedInputStream is{(const uint8_t *)destinationBuffer, maxDecompressedSize};
      
      auto tag = is.ReadTag();
      uint32_t typ = 0;
      is.ReadVarint32(&typ);
      if( tag != 1<<3 )         { std::cout << "1: tag=" << tag << " typ=" << typ << "\n"; }
      if( typ < 2 || typ > 18 ) { std::cout << "2: tag=" << tag << " typ=" << typ << "\n"; }
      
      
      switch( typ )
      {
        case interface::pb::Kind::STRING:
        case interface::pb::Kind::DATE:
        case interface::pb::Kind::TIME:
        case interface::pb::Kind::DATETIME:
        case interface::pb::Kind::NUMERIC:
        case interface::pb::Kind::INET4:
        case interface::pb::Kind::INET6:
        case interface::pb::Kind::MAC:
        case interface::pb::Kind::GEODATA:
        {
          size_t nread = 0;
          while( true )
          {
            tag = is.ReadTag();
            if( tag != ((2<<3)+2) ) { break; }
            uint32_t len = 0;
            is.ReadVarint32(&len);
            is.Skip(len);
            ++nread;
          }
          //if( nread != 25000 )
          //  std::cout << "4: read=" << nread << " seqno=" << dta->seqno() << " endof=" << dta->endofdata() << "\n";
          break;
        }
          
        case interface::pb::Kind::INT32:
        {
          size_t nread = 0;
          tag = is.ReadTag();
          if( tag != ((3<<3)+2) ) { break; }
          uint32_t payload = 0;
          is.ReadVarint32(&payload);
          int pos = is.CurrentPosition();

          int endpos = pos + payload;
          while( pos < endpos )
          {
            uint32_t n = 0;
            is.ReadVarint32(&n);
            int32_t sval = (n >> 1) ^ (-(n & 1));
            pos = is.CurrentPosition();
            ++nread;
          }
          //if( nread != 25000 )
          //  std::cout << "6: read=" << nread << " seqno=" << dta->seqno() << " endof=" << dta->endofdata() << "\n";
          tag = is.ReadTag();
          break;
        }
          
        case interface::pb::Kind::INT64:
        {
          size_t nread = 0;
          tag = is.ReadTag();
          if( tag != ((4<<3)+2) ) { break; }
          uint32_t payload = 0;
          is.ReadVarint32(&payload);
          int pos = is.CurrentPosition();
          
          int endpos = pos + payload;
          while( pos < endpos )
          {
            uint64_t n = 0;
            is.ReadVarint64(&n);
            int64_t sval = (n >> 1) ^ (-(n & 1));
            pos = is.CurrentPosition();
            ++nread;
          }
          //if( nread != 25000 )
          //  std::cout << "8: read=" << nread << " seqno=" << dta->seqno() << " endof=" << dta->endofdata() << "\n";
          tag = is.ReadTag();
          break;
        }
          
        case interface::pb::Kind::BOOL:
        case interface::pb::Kind::UINT32:
        {
          size_t nread = 0;
          tag = is.ReadTag();
          if( tag != ((5<<3)+2) ) { break; }
          uint32_t payload = 0;
          is.ReadVarint32(&payload);
          
          int pos = is.CurrentPosition();
          
          int endpos = pos + payload;
          while( pos < endpos )
          {
            uint32_t val = 0;
            is.ReadVarint32(&val);
            pos = is.CurrentPosition();
            ++nread;
          }
          //if( nread != 25000 )
          //  std::cout << "10: read=" << nread << " seqno=" << dta->seqno() << " endof=" << dta->endofdata() << "\n";
          tag = is.ReadTag();
          break;
        }
          
        case interface::pb::Kind::UINT64:
        {
          size_t nread = 0;
          tag = is.ReadTag();
          if( tag != ((6<<3)+2) ) { break; }
          uint32_t payload = 0;
          is.ReadVarint32(&payload);
          int pos = is.CurrentPosition();
          
          int endpos = pos + payload;
          while( pos < endpos )
          {
            uint64_t val = 0;
            is.ReadVarint64(&val);
            pos = is.CurrentPosition();
            ++nread;
          }
          //if( nread != 25000 )
          //  std::cout << "12: read=" << nread << " seqno=" << dta->seqno() << " endof=" << dta->endofdata() << "\n";
          tag = is.ReadTag();
          break;
        }
          
        case interface::pb::Kind::DOUBLE:
        {
          size_t nread = 0;
          tag = is.ReadTag();
          if( tag != ((7<<3)+2) ) { break; }
          uint32_t payload = 0;
          is.ReadVarint32(&payload);
          int pos = is.CurrentPosition();
          
          int endpos = pos + payload;
          while( pos < endpos )
          {
            double dv;
            is.ReadRaw(&dv, sizeof(double));
            pos = is.CurrentPosition();
            ++nread;
          }
          //if( nread != 25000 )
          //  std::cout << "13: read=" << nread << " seqno=" << dta->seqno() << " endof=" << dta->endofdata() << "\n";
          tag = is.ReadTag();
          break;
        }
          
        case interface::pb::Kind::FLOAT:
        {
          size_t nread = 0;
          tag = is.ReadTag();
          if( tag != ((7<<3)+2) ) { break; }
          uint32_t payload = 0;
          is.ReadVarint32(&payload);
          int pos = is.CurrentPosition();
          
          int endpos = pos + payload;
          while( pos < endpos )
          {
            float dv;
            is.ReadRaw(&dv, sizeof(double));
            pos = is.CurrentPosition();
            ++nread;
          }
          //if( nread != 25000 )
          //  std::cout << "15: read=" << nread << " seqno=" << dta->seqno() << " endof=" << dta->endofdata() << "\n";
          tag = is.ReadTag();
          break;
        }

        case interface::pb::Kind::BYTES:
        {
          size_t nread = 0;
          while( true )
          {
            tag = is.ReadTag();
            if( tag != ((10<<3)+2) ) { break; }
            uint32_t len = 0;
            is.ReadVarint32(&len);
            is.Skip(len);
            ++nread;
          }
          //if( nread != 25000 )
          //  std::cout << "17: read=" << nread << " seqno=" << dta->seqno() << " endof=" << dta->endofdata() << "\n";
          break;
        }
      };
      
      {
        size_t nread = 0;
        size_t nnulls = 0;
        
        if( tag == ((11<<3)+2) )
        {
          uint32_t payload = 0;
          bool rv = is.ReadVarint32(&payload);
          if( rv )
          {
            int pos = is.CurrentPosition();
            int endpos = pos + payload;
            while( pos < endpos )
            {
              uint32_t val = 0;
              is.ReadVarint32(&val);
              pos = is.CurrentPosition();
              ++nread;
              if( val )
                ++nnulls;
            }
          }
        }
        
        if( dta->endofdata() )
        {
          /*
          std::cout << "19: nulls: read=" <<  nread << " seqno=" << dta->seqno()
                    << " endof=" << dta->endofdata()
                    << " blimit=" << is.BytesUntilLimit()
                    << " nnulls=" << nnulls
                    << "\n";
           */
        }
      }

      ++decompressed;
      orig_bytes += compSize;
      decomp_bytes += maxDecompressedSize;
    };
    
    util::active_queue<std::shared_ptr<interface::pb::Column>,100> q(4,decompress);
    
    for( size_t i=0; i<=max_b; ++i )
    {
      auto row = collector_sptr_->get(i, 1000);
      if( row.second != col_hashes_.size() ) { THROW_("missing columns"); }
      collector_sptr_->erase(i);
      for( auto & dta : row.first )
      {
        if( dta->seqno() != i ) { THROW_("invalid column"); }
        q.push(dta);
      }
      q.wait_empty(std::chrono::seconds(10));
    }
    
    double ms = (0.0+tm.get_usec())/1000.0;
    double ratio = ((0.0+orig_bytes) / (0.0+decomp_bytes))*100.0;
    std::cout << "decompress took " << ms << "ms" <<
    " decompressed=" << decompressed <<
    " orig_bytes=" << orig_bytes <<
    " decomp_bytes=" << decomp_bytes <<
    " ratio=" << ratio << "%\n";

#endif
  }

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
  
  void
  query_data::start(const std::chrono::system_clock::time_point & st)
  {
    start_ = st;
  }
  
  size_t
  query_data::block_count() const
  {
    return complete_map_.size();
  }
  
  size_t
  query_data::complete_count() const
  {
    size_t cols = col_hashes_.size();
    size_t ret = 0;
    for( auto const & i : complete_map_ )
    {
      if( i.second.size() == cols )
        ++ret;
    }
    return ret;
  }
  
  std::string
  query_data::missing() const
  {
    std::ostringstream os;
    size_t cols = col_hashes_.size();
    for( auto const & i : complete_map_ )
    {
      if( i.second.size() != cols )
      {
        os << i.first << ':' << cols-i.second.size() << ' ';
      }
    }
    return os.str();
  }

  bool
  query_data::end_of_data(bool value)
  {
    if( value )
      end_of_data_ = value;
    return end_of_data_;
  }
  
  size_t
  query_data::max_block() const
  {
    size_t ret = 0;
    for( auto const & i : complete_map_ )
      if( i.first > ret )
        ret = i.first;
    return ret;
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
    timeout_seconds_{cache_timeout_seconds},
    end_of_data_{false}
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
    
    // skip check for special queries
    if( query()->has_querycontrol() == true ) return false;

    bool ret = false;
    int64_t difftime = 0;
    std::string t0;
    std::string t1;
    
    query_table_log qtl;
    qtl.key(tab_hash_);
    size_t res = cache.fetch(qtl);
    
    if( res > 0 )
    {
      bool converted = storeable::convert(qtl.t0_completed_at(), t0);
      storeable::convert(qtl.t1_completed_at(), t1);
      
      auto now = system_clock::now();
      difftime = duration_cast<std::chrono::seconds>(now - qtl.t0_completed_at()).count();
      
      if( converted &&
         qtl.t0_nblocks() > 0 &&
         qtl.n_columns() > 0 &&
         difftime < timeout_seconds_ )
      {
        ret = true;
      }        
    }
    
    LOG_INFO(V_(qtl.clazz()) <<
             V_(qtl.key()) <<
             V_(query_->queryid()) <<
             V_(query()->schema()) <<
             V_(query()->table()) <<
             "has" << V_(res) << "properties" <<
             V_(qtl.n_columns()) <<
             V_(qtl.t0_nblocks()) <<
             V_(t0) << V_(t1) <<
             V_(ret) << V_(res) <<
             V_(difftime) <<
             V_(timeout_seconds_) );

    return ret;
  }
  
  bool
  query_data::store_column_block(cachedb::db & cache,
                                 const std::string & colname,
                                 const std::string & column_hash,
                                 size_t seq_no,
                                 bool end_of_data,
                                 cachedb::query_column_block & qcb)
  {
    const std::string & colhash = this->col_hash(colname);
    qcb.key(colhash, start_, seq_no);
    qcb.column_hash(column_hash);
    qcb.end_of_data(end_of_data);
    size_t res = cache.set(qcb);
    if( res != 2 )
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
    size_t max_val = std::max(seq_no, max_block());
    for( size_t i=0; i<=max_val; ++i )
    {
      auto it = complete_map_.find(i);
      if( it == complete_map_.end() )
      {
        LOG_TRACE("not complete" << V_(seq_no) << V_(i) << "not found");
        return false;
      }
      if( it->second.size() != ncolumns )
      {
        // LOG_TRACE("block not complete" << V_(seq_no) << V_(i) << V_(it->second.size()));
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

