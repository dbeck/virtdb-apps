log = require 'loglevel'
log.setLevel 'debug'

class Config
    @Const:
        DB_CONFIG:
            PROTO_FILE: "node_modules/virtdb-connector/lib/proto/db_config.pb.desc"
        SERVICE_CONFIG:
            PROTO_FILE: "node_modules/virtdb-connector/lib/proto/svc_config.pb.desc"
        POSTGRES_CONNECTION: "postgres://gpadmin:manager@192.168.221.11:5432/gpadmin"
        SHARED_OBJECT_PATH: "/usr/local/libgreenplum_ext.so"
        # SHARED_OBJECT_PATH: "/home/szhuber/u501/virtdb-enterprise/out/Debug/obj.target/libgreenplum_ext.so"
    @Error:
        Duplicate_Object: '42710'

module.exports = Config
