zmq  = require "zmq"
fs   = require "fs"
pb    = require "node-protobuf"
proto_meta   = new pb fs.readFileSync "../../src/proto/meta_data.desc"
keypress = require 'keypress'
request_socket = null

sendRequest = () ->
    console.time "Metadata request"
    request_data =
        Name: ''
        Schema: 'data'
    buf = proto_meta.serialize(request_data, "virtdb.interface.pb.MetaDataRequest")
    request_socket.send buf

resetSocket = () ->
    if request_socket
        request_socket.close()
    request_socket = zmq.socket("req")
    request_socket.connect "tcp://localhost:5557"
    request_socket.on 'message', (message) ->
        console.time "Protocol buffers parse"
        reply = proto_meta.parse(message, "virtdb.interface.pb.MetaDataReply")
        # for table in reply.Tables
        #     console.log table.Name + ": " + table.Fields.length + " fields"
        console.timeEnd "Protocol buffers parse"
        console.timeEnd "Metadata request"

keypress process.stdin
resetSocket()

process.stdin.on 'keypress', (ch, key) ->
    if key.name == 'escape' or (key.name =='c' and key.ctrl == true) or key.name == 'q'
        process.exit()
    if key.name == 's'
        sendRequest()
        return
    if key.name == 'c'
        resetSocket()
        return

process.stdin.setRawMode true
process.stdin.resume()
