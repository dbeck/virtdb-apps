CONST = require("./config").Const

zmq          = require("zmq")            # messaging
EventEmitter = require('events').EventEmitter;
fs           = require("fs")             # reading data descriptor and CSV files
p            = require("node-protobuf")  # serialization
pb           = new p(fs.readFileSync(CONST.PROTO_FILE))
log          = require('loglevel');

module.exports = new EventEmitter();

# Query socket: receives queries
query_socket = zmq.socket("rep")
query_socket.bind CONST.QUERY.URL, (err) ->
    if err
        log.error err
    else
        log.info "Listening on ", CONST.QUERY.URL
    return

query_socket.on "message", (request) ->
    query_socket.send "ack"
    newData = pb.parse(request, "virtdb.interface.pb.Query")
    module.exports.emit CONST.QUERY.MESSAGE, newData;
    return

# Publisher socket: sends back the data
publisher_socket = zmq.socket("pub")
publisher_socket.bind CONST.DATA.URL, (err) ->
    if err
        log.error err
    else
        log.info "Listening on ", CONST.DATA.URL
    return
module.exports.on CONST.DATA.MESSAGE, (column_data) ->
    buf = pb.serialize(column_data, "virtdb.interface.pb.Column")
    publisher_socket.send(buf)
    log.debug "Column data sent: ", column_data.Name, "(", column_data.Data.length() ,")"

# On exit close the sockets
module.exports.on CONST.CLOSE_MESSAGE, () ->
    query_socket.close()
    publisher_socket.close()
