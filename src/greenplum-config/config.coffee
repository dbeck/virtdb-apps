log = require 'loglevel'
log.setLevel 'debug'

class Config
    @Const:
        DB_CONFIG:
            MESSAGE: "config"
            URL: "tcp://*:5558"
            PROTO_FILE: "../common/proto/db_config.pb.desc"
        META_DATA:
            PROTO_FILE: "../common/proto/meta_data.pb.desc"
        MAX_CHUNK_SIZE: 100000
        CLOSE_MESSAGE: "close"
        POSTGRES_CONNECTION: "postgres://gpadmin:manager@192.168.221.11:5432/gpadmin"
        SHARED_OBJECT_PATH: "/usr/local/libgreenplum_ext.so"
        # SHARED_OBJECT_PATH: "/home/szhuber/u501/virtdb-enterprise/out/Debug/obj.target/libgreenplum_ext.so"
    @Error:
        Duplicate_Object: '42710'

module.exports = Config
