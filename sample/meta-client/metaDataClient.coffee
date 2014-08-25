zmq  = require "zmq"
fs   = require "fs"
pb    = require "node-protobuf"
proto_meta   = new pb fs.readFileSync "../../src/proto/meta_data.pb.desc"
proto_config = new pb fs.readFileSync "../../src/proto/db_config.pb.desc"
keypress = require 'keypress'
log             = require('loglevel');
log.setLevel('debug')

VirtDB = require "./virtdb"

request_socket = null

config_socket = zmq.socket("push")
config_socket.connect "tcp://localhost:5558"

sendRequest = () ->
    console.time "Metadata request"
    request_data =
        Name: '^Master$'
        Schema: 'data'
    buf = proto_meta.serialize(request_data, "virtdb.interface.pb.MetaDataRequest")
    request_socket.send buf

configDB = (message) ->
    config =
        Type: "virtdb_fdw"
        Name: "csv_srv"
        Tables: message.Tables
    buf = proto_config.serialize(config, "virtdb.interface.pb.ServerConfig")
    config_socket.send buf

    # for table in reply.Tables
    #     console.log table.Name + ": " + table.Fields.length + " fields"
    console.timeEnd "Metadata request"


resetSocket = () ->
    if request_socket
        request_socket.close()
    request_socket = zmq.socket("req")
    request_socket.connect "tcp://localhost:5557"
    request_socket.on 'message', (message) ->
        reply = proto_meta.parse(message, "virtdb.interface.pb.MetaData")
        configDB reply
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
    if key.name == 'o'
        new VirtDB "tcp://localhost:65004"

process.stdin.setRawMode true
process.stdin.resume()
