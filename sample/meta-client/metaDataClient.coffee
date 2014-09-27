zmq  = require "zmq"
fs   = require "fs"
pb    = require "node-protobuf"
proto_meta   = new pb fs.readFileSync "../../src/common/proto/meta_data.pb.desc"
proto_config = new pb fs.readFileSync "../../src/common/proto/db_config.pb.desc"

request_socket = null

# CHANGE THESE FOR PROPER FUNCTIONALITY (I KNOW IT SUX BUT NEEDED A QUICK AND DIRTY SOLUTION)
db_config_push_url = "tcp://192.168.221.3:41484"
meta_server_request_url = "tcp://192.168.221.3:56659"
#############################################################################################

config_socket = zmq.socket("push")
config_socket.connect db_config_push_url

sendRequest = () ->
    console.time "Metadata request"
    request_data =
        #Name: '^Master$'
        Name: '.*'
        Schema: 'data'
        WithFields: true
    buf = proto_meta.serialize(request_data, "virtdb.interface.pb.MetaDataRequest")
    request_socket.send buf

configDB = (message) ->
    config =
        Type: "virtdb_fdw"
        Name: "csv-provider"
        Tables: message.Tables
    buf = proto_config.serialize(config, "virtdb.interface.pb.ServerConfig")
    config_socket.send buf
    console.timeEnd "Metadata request"


resetSocket = () ->
    if request_socket
        request_socket.close()
    request_socket = zmq.socket("req")
    request_socket.connect meta_server_request_url
    request_socket.on 'message', (message) ->
        reply = proto_meta.parse(message, "virtdb.interface.pb.MetaData")
        configDB reply

resetSocket()
sendRequest()
