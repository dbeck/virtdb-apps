zmq          = require("zmq")            # messaging
EventEmitter = require('events').EventEmitter;
fs           = require("fs")             # reading data descriptor and CSV files
p            = require("node-protobuf")  # serialization
pb           = new p(fs.readFileSync("../src/proto/data.desc"))

module.exports = new EventEmitter();

# Query socket: receives queries
query_socket = zmq.socket("rep")
query_socket.bind "tcp://*:55555", (err) ->
    if err
        console.log err
    else
        console.log "Listening on 55555..."
    return

query_socket.on "message", (request) ->
    query_socket.send "ack"
    newData = pb.parse(request, "virtdb.interface.pb.Query")
    module.exports.emit 'query', newData;
    return

# Publisher socket: sends back the data
publisher_socket = zmq.socket("pub")
publisher_socket.bind "tcp://*:5556", (err) ->
    if err
        console.log err
    else
        console.log "Listening on 5556..."
    return
module.exports.on 'column', (column_data) ->
    buf = pb.serialize(column_data, "virtdb.interface.pb.Column")
    publisher_socket.send(buf)

# On exit close the sockets
module.exports.on 'close', () ->
    query_socket.close()
    publisher_socket.close()
