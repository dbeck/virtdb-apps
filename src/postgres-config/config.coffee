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
    @Error:
        Duplicate_Object: '42710'

module.exports = Config
