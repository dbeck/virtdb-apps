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
        POSTGRES_CONNECTION: "postgres://localhost/vagrant"
        SHARED_OBJECT_PATH: "/home/szhuber/u501/virtdb-enterprise/out/Debug/obj.target/libgreenplum_ext.so"
    @Error:
        Duplicate_Object: '42710'

module.exports = Config
