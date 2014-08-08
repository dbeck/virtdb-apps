log = require('loglevel');
log.setLevel('info')

class Config
    @Const:
        QUERY:
            MESSAGE: "query"
            URL: "tcp://*:55555"
        DATA:
            MESSAGE: "column"
            URL: "tcp://*:5556"
        MAX_CHUNK_SIZE: 100000
        PROTO_FILE: "../src/proto/data.desc"
        CLOSE_MESSAGE: "close"

module.exports = Config
