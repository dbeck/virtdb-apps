log = require 'loglevel'
log.setLevel 'debug'

class Config
    @Const:
        DB_CONFIG:
            PROTO_FILE: "node_modules/virtdb-connector/lib/proto/db_config.pb.desc"
        SERVICE_CONFIG:
            PROTO_FILE: "node_modules/virtdb-connector/lib/proto/svc_config.pb.desc"
    @Error:
        Duplicate_Object: '42710'

module.exports = Config
