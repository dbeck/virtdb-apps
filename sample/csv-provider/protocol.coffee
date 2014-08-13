CONST = require("./config").Const

zmq             = require("zmq")            # messaging
EventEmitter    = require('events').EventEmitter;
fs              = require("fs")             # reading data descriptor and CSV files
p               = require("node-protobuf")  # serialization
proto_data      = new p(fs.readFileSync(CONST.DATA.PROTO_FILE))
proto_meta      = new p(fs.readFileSync(CONST.METADATA.PROTO_FILE))
log             = require('loglevel');

module.exports = new EventEmitter();

#
# Query socket: receives queries
#
query_socket = zmq.socket("pull")
query_socket.bind CONST.QUERY.URL, (err) ->
    if err
        log.error err
    else
        log.info "Listening on ", CONST.QUERY.URL
    return

query_socket.on "message", (request) ->
    newData = proto_data.parse(request, "virtdb.interface.pb.Query")
    module.exports.emit CONST.QUERY.MESSAGE, newData;
    return

#
# Metadata socket: receives metadata queries and sends replies
#
metadata_socket = zmq.socket("rep")
metadata_socket.bind CONST.METADATA.URL, (err) ->
    if err
        log.error err
    else
        log.info "Listening on ", CONST.METADATA.URL
    return

metadata_socket.on "message", (request) ->
    try
        newData = proto_meta.parse(request, "virtdb.interface.pb.MetaDataRequest")
        module.exports.emit CONST.METADATA.MESSAGE, newData;
    catch ex
        log.error ex
        metadata_socket.send 'err'
    return

module.exports.on CONST.METADATA.REPLY.MESSAGE, (data) ->
    buf = proto_meta.serialize(data, "virtdb.interface.pb.MetaDataReply")
    metadata_socket.send buf
    # publisher_socket.send(buf)
    # log.debug "Column data sent: ", column_data.Name, "(", column_data.Data.length() ,")"

#
# Publisher socket: sends back the data
#
publisher_socket = zmq.socket("pub")
publisher_socket.bind CONST.DATA.URL, (err) ->
    if err
        log.error err
    else
        log.info "Listening on ", CONST.DATA.URL
    return

module.exports.on CONST.DATA.MESSAGE, (column_data) ->
    buf = proto_data.serialize(column_data, "virtdb.interface.pb.Column")
    publisher_socket.send(buf)
    log.debug "Column data sent: ", column_data.Name, "(", column_data.Data.length() ,")"



#
# On exit close the sockets
#
module.exports.on CONST.CLOSE_MESSAGE, () ->
    metadata_socket.close()
    query_socket.close()
    publisher_socket.close()
