fs          = require 'fs'
zmq         = require 'zmq'
protobuf    = require 'node-protobuf'
async       = require "async"

proto_service_config = new protobuf(fs.readFileSync('../../src/common/proto/svc_config.pb.desc'))
proto_meta           = new protobuf(fs.readFileSync('../../src/common/proto/meta_data.pb.desc'))
proto_data           = new protobuf(fs.readFileSync('../../src/common/proto/data.pb.desc'))
proto_diag           = new protobuf(fs.readFileSync('../../src/common/proto/diag.pb.desc'))


class Protocol
    @svcConfigSocket = null
    @metadata_socket = null
    @column_socket = null
    @diag_socket = null
    @diagAddress = null

    @svcConfig = (connectionString, onEndpoint) ->
        @svcConfigSocket = zmq.socket 'req'
        @svcConfigSocket.on 'message', (message) ->
            endpointMessage = proto_service_config.parse message, 'virtdb.interface.pb.Endpoint'
            for endpoint in endpointMessage.Endpoints
                onEndpoint endpoint

        @svcConfigSocket.connect connectionString

    @sendEndpoint = (endpoint) ->
        @svcConfigSocket.send proto_service_config.serialize endpoint, 'virtdb.interface.pb.Endpoint'

    @bindHandler = (socket, svcType, zmqType, onBound) ->
        return (err) ->
            zmqAddress = ""
            if not err
                zmqAddress = socket.getsockopt zmq.ZMQ_LAST_ENDPOINT
            onBound err, svcType, zmqType, zmqAddress


    @metaDataServer = (connectionString, onRequest, onBound) =>
        @metadata_socket = zmq.socket "rep"
        @metadata_socket.on "message", (request) =>
            try
                newData = proto_meta.parse(request, "virtdb.interface.pb.MetaDataRequest")
                onRequest newData
            catch ex
                console.log ex
                @metadata_socket.send 'err'
            return
        @metadata_socket.bind connectionString, @bindHandler(@metadata_socket, 'META_DATA', 'REQ_REP', onBound)

    @queryServer = (connectionString, onQuery, onBound) =>
        @query_socket = zmq.socket "pull"
        @query_socket.on "message", (request) =>
            try
                query = proto_data.parse(request, "virtdb.interface.pb.Query")
                onQuery query
            catch ex
                console.log ex
                @query_socket.send 'err'
            return
        @query_socket.bind connectionString, @bindHandler(@query_socket, 'QUERY', 'PUSH_PULL', onBound)

    @columnServer = (connectionString, callback, onBound) =>
        @column_socket = zmq.socket "pub"
        @column_socket.bind connectionString, @bindHandler(@column_socket, 'COLUMN', 'PUB_SUB', onBound)

    @sendMetaData = (data) =>
        @metadata_socket.send proto_meta.serialize data, "virtdb.interface.pb.MetaData"

    @sendColumn = (columnChunk) =>
        @column_socket.send columnChunk.QueryId, zmq.ZMQ_SNDMORE
        @column_socket.send proto_data.serialize columnChunk, "virtdb.interface.pb.Column"
        console.log "Column data sent: ", columnChunk.Name, "(", columnChunk.Data.length() ,")"

    @onDiagSocket = (callback) =>
        if @diag_socket?
            callback()
        else
            async.retry 5, (retry_callback, results) =>
                setTimeout =>
                    err = null
                    # console.log @diag_socket
                    if not @diag_socket?
                        err = "diag_socket is not set yet"
                    retry_callback err, @diag_socket
                , 50
            , =>
                if @diag_socket?
                    callback()

    @sendDiag = (logRecord) =>
        @onDiagSocket () =>
            # console.log logRecord
            @diag_socket.send proto_diag.serialize logRecord, "virtdb.interface.pb.LogRecord"

    @connectToDiag = (addresses) =>
        ret = null
        connected = false
        async.eachSeries addresses, (address, callback) =>
            try
                if ret
                    callback()
                    return
                if address == @diagAddress
                    ret = address
                    callback()
                    return
                socket = zmq.socket "push"
                socket.connect address
                @diagAddress = address
                ret = address
                @diag_socket = socket
                connected = true
                callback()
            catch e
                callback e
        , (err) ->
            if err
                console.log err
        if connected
            ret
        else
            null

    @close = () =>
        @svcConfigSocket?.close()
        @metadata_socket?.close()
        @column_socket?.close()



module.exports = Protocol
