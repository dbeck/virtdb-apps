CONST = require("./config").Const

zmq              = require "zmq"
fs               = require "fs"
protobuf         = require 'virtdb-proto'

util = require 'util'

class Protocol

    @DBConfigSocket: null
    @DBConfigQuerySocket: null

    @DBConfigServer = (name, connectionString, onMessage, onBound) =>
        @DBConfigSocket = zmq.socket "pull"
        @DBConfigSocket.on "message", (request) =>
            serverConfigMessage = protobuf.db_config.parse(request, "virtdb.interface.pb.ServerConfig")
            onMessage serverConfigMessage
        @DBConfigSocket.bind connectionString, onBound name, @DBConfigSocket, 'DB_CONFIG', 'PUSH_PULL'

    @DBConfigQueryServer = (name, connectionString, onMessage, onBound) =>
        @DBConfigQuerySocket = zmq.socket "rep"
        @DBConfigQuerySocket.on "message", (request) =>
            serverConfigQueryMessage = protobuf.db_config.parse(request, "virtdb.interface.pb.DbConfigQuery")
            onMessage serverConfigQueryMessage
        @DBConfigQuerySocket.bind connectionString, onBound name, @DBConfigQuerySocket, 'DB_CONFIG_QUERY', 'REQ_REP'

    @SendConfigQueryReply = (reply) =>
        try
            @DBConfigQuerySocket.send protobuf.db_config.serialize reply, "virtdb.interface.pb.DbConfigReply"
        catch ex
            console.log "Error during sending config query reply!", ex

    @SendConfig = (address, config, replyHandler) =>
        try
            templateSocket = zmq.socket "req"
            templateSocket.connect address
            templateSocket.on "message", (replyProto) =>
                reply = protobuf.service_config.parse replyProto, "virtdb.interface.pb.Config"
                replyHandler? reply
            templateSocket.send protobuf.service_config.serialize config, "virtdb.interface.pb.Config"
        catch ex
            console.log "Error during sending config!", ex

    @ParseConfig = (config) =>
        try
            return protobuf.service_config.parse config, "virtdb.interface.pb.Config"
        catch ex
            console.log "Error during parsing config", ex
            return null

module.exports = Protocol
