CONST = require("./config").Const

zmq              = require "zmq"
fs               = require "fs"
protocol_buffers = require "node-protobuf"
proto_config        = new protocol_buffers(fs.readFileSync(CONST.DB_CONFIG.PROTO_FILE))
serviceConfigProto  = new protocol_buffers(fs.readFileSync(CONST.SERVICE_CONFIG.PROTO_FILE))
util = require 'util'

class Protocol

    @DBConfigSocket: null
    @DBConfigQuerySocket: null

    @DBConfigServer = (name, connectionString, onMessage, onBound) =>
        @DBConfigSocket = zmq.socket "pull"
        @DBConfigSocket.on "message", (request) =>
            serverConfigMessage = proto_config.parse(request, "virtdb.interface.pb.ServerConfig")
            onMessage serverConfigMessage
        @DBConfigSocket.bind connectionString, onBound name, @DBConfigSocket, 'DB_CONFIG', 'PUSH_PULL'

    @DBConfigQueryServer = (name, connectionString, onMessage, onBound) =>
        @DBConfigQuerySocket = zmq.socket "rep"
        @DBConfigQuerySocket.on "message", (request) =>
            serverConfigQueryMessage = proto_config.parse(request, "virtdb.interface.pb.DbConfigQuery")
            onMessage serverConfigQueryMessage
        @DBConfigQuerySocket.bind connectionString, onBound name, @DBConfigQuerySocket, 'DB_CONFIG_QUERY', 'REQ_REP'

    @SendConfigQueryReply = (reply) =>
        try
            @DBConfigQuerySocket.send proto_config.serialize reply, "virtdb.interface.pb.DbConfigReply"
        catch ex
            console.log "Error during sending config query reply!", ex

    @SendConfig = (address, config, replyHandler) =>
        try
            templateSocket = zmq.socket "req"
            templateSocket.connect address
            templateSocket.on "message", (replyProto) =>
                reply = serviceConfigProto.parse replyProto, "virtdb.interface.pb.Config"
                replyHandler? reply
            templateSocket.send serviceConfigProto.serialize config, "virtdb.interface.pb.Config"
        catch ex
            console.log "Error during sending config!", ex

    @ParseConfig = (config) =>
        try
            return serviceConfigProto.parse config, "virtdb.interface.pb.Config"
        catch ex
            console.log "Error during parsing config", ex
            return null

module.exports = Protocol
