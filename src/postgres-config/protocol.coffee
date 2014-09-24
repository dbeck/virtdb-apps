CONST = require("./config").Const

zmq              = require "zmq"
fs               = require "fs"
protocol_buffers = require "node-protobuf"
proto_config     = new protocol_buffers(fs.readFileSync(CONST.DB_CONFIG.PROTO_FILE))

class Protocol

    @DBConfigSocket: null

    @DBConfigServer = (name, connectionString, onMessage, onBound) =>
        @DBConfigSocket = zmq.socket "pull"
        @DBConfigSocket.on "message", (request) =>
            serverConfigMessage = proto_config.parse(request, "virtdb.interface.pb.ServerConfig")
            onMessage serverConfigMessage
        @DBConfigSocket.bind connectionString, onBound name, @DBConfigSocket, 'DB_CONFIG', 'PUSH_PULL'

module.exports = Protocol
