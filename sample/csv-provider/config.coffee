log = require('loglevel');
log.setLevel('debug')

class Config
    @Const:
        QUERY:
            MESSAGE: "query"
            URL: "tcp://*:55555"
        DATA:
            MESSAGE: "column"
            URL: "tcp://*:5556"
            PROTO_FILE: "../../src/proto/data.pb.desc"
        METADATA:
            MESSAGE: "metadata"
            REPLY:
                MESSAGE: "metadata_reply"
            URL: "tcp://*:5557"
            PROTO_FILE: "../../src/proto/meta_data.pb.desc"
        MAX_CHUNK_SIZE: 100000
        CLOSE_MESSAGE: "close"

module.exports = Config
