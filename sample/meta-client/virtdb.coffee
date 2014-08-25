# CONST = require("./config").Const
zmq         = require "zmq"
protobuf    = require "node-protobuf"
fs          = require "fs"

proto_service_config = new protobuf(fs.readFileSync("../../src/proto/svc_config.pb.desc"))

class VirtDB
    svcConfigSocket: null   # Communicating endpoints and config

    constructor: (@connectionString) ->
        # Connect to VirtDB Service Config
        @svcConfigSocket = zmq.socket('req')
        @svcConfigSocket.on "message", @_onEndpoint
        @svcConfigSocke.connect @connectionString
        endpoint =
            Endpoints = [
                Name = "empty"
                SvcType = "NONE"
            ]
        svcConfigSocket.send proto_service_config.serialize endpoint, "virtdb.interface.pb.Endpoint"

    _onEndpoint = (message) ->
        console.log proto_service_config.parse message, "virtdb.interface.pb.Endpoint"

module.exports = VirtDB
