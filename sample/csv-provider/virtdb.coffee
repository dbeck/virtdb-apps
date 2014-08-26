# CONST = require('./config').Const
zmq         = require 'zmq'
protobuf    = require 'node-protobuf'
fs          = require 'fs'
udp         = require 'dgram'
async       = require "async"

proto_service_config = new protobuf(fs.readFileSync('../../src/common/proto/svc_config.pb.desc'))
proto_meta           = new protobuf(fs.readFileSync('../../src/common/proto/meta_data.pb.desc'))

class Protocol
    @svcConfigScoket = null
    @metadata_socket = null

    @svcConfig = (connectionString, onEndpoint) ->
        @svcConfigSocket = zmq.socket('req')
        @svcConfigSocket.on 'message', (message) ->
            endpointMessage = proto_service_config.parse message, 'virtdb.interface.pb.Endpoint'
            for endpoint in endpointMessage.Endpoints
                onEndpoint endpoint

        @svcConfigSocket.connect connectionString

    @sendEndpoint = (endpoint) ->
        @svcConfigSocket.send proto_service_config.serialize endpoint, 'virtdb.interface.pb.Endpoint'

    @metaDataServer = (connectionString, onRequest, onBound) ->
        @metadata_socket = zmq.socket("rep")
        @metadata_socket.on "message", (request) ->
            try
                newData = proto_meta.parse(request, "virtdb.interface.pb.MetaDataRequest")
                onRequest newData
            catch ex
                log.error ex
                @metadata_socket.send 'err'
            return
        @metadata_socket.bind connectionString, (err) =>
            zmqAddress = ""
            if not err
                zmqAddress = @metadata_socket.getsockopt zmq.ZMQ_LAST_ENDPOINT
            onBound(err, zmqAddress)

    @sendMetaData = (data) =>
        @metadata_socket.send proto_meta.serialize data, "virtdb.interface.pb.MetaData"

class VirtDB
    svcConfigSocket: null   # Communicating endpoints and config
    IP: null

    constructor: (@name, connectionString) ->
        # Connect to VirtDB Service Config
        Protocol.svcConfig connectionString, @_onEndpoint

        endpoint =
            Endpoints: [
                Name: @name
                SvcType: 'NONE'
            ]
        Protocol.sendEndpoint endpoint

    onMetaDataRequest: (callback) =>
        @_onIP () =>
            Protocol.metaDataServer 'tcp://'+@IP+':*', callback, (err, zmqAddress) =>
                console.log "Listening on", zmqAddress
                endpoint =
                    Endpoints: [
                        Name: @name
                        SvcType: 'META_DATA'
                        Connections: [
                            Type: 'REQ_REP'
                            Address: [
                                zmqAddress
                            ]
                        ]
                    ]
                Protocol.sendEndpoint endpoint
        return

    sendMetaData: (data) =>
        console.log data
        Protocol.sendMetaData data

    _onIP: (callback) =>
        if @IP?
            callback()
        else
            async.retry 5, (retry_callback, results) =>
                setTimeout () =>
                    err = null
                    if not @IP?
                        err "IP is not set yet"
                    retry_callback err, @IP
                , 50
            , () =>
                callback()

    _onEndpoint: (endpoint) =>
        switch endpoint.SvcType
            when 'IP_DISCOVERY'
                if not @IP?
                    @_findMyIP endpoint.Connections[0].Address.toString()

    _findMyIP: (discoveryAddress) =>
        if discoveryAddress.indexOf 'raw_udp://' == 0
            client = null
            message = new Buffer '?'
            address = discoveryAddress.replace /^raw_udp:\/\//, ''
            if address.indexOf('[') > -1 # IPv6
                ip = address.replace /^\[|\]:[0-9]{2,5}/g, ''
                port = address.replace /\[.*\]:/g, ''
                client = udp.createSocket 'udp6'
            else    # IPv4
                parts = address.split(':')
                ip = parts[0]
                port = parts[1]
                client = udp.createSocket 'udp4'

            client?.on 'message', (message, remote) =>
                @IP = message.toString()
                client.close()


            async.retry 5, (callback, results) =>
                err = null
                client?.send message, 0, 1, port, ip, (err, bytes) ->
                    if err
                        console.log err
                setTimeout () =>
                    if @IP == null
                        err = "IP is not set yet!"
                    callback err, @IP
                , 50
            , () =>
                return


module.exports = VirtDB
