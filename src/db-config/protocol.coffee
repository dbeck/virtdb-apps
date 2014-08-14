CONST = require("./config").Const

zmq             = require("zmq")            # messaging
EventEmitter    = require('events').EventEmitter;
fs              = require("fs")             # reading data descriptor and CSV files
pb              = require("node-protobuf")  # serialization
proto_config    = new pb fs.readFileSync CONST.DB_CONFIG.PROTO_FILE
log             = require('loglevel');

module.exports = new EventEmitter();

#
# DB Config: receives queries
#
config_socket = zmq.socket("pull")
config_socket.bind CONST.DB_CONFIG.URL, (err) ->
    if err
        log.error err
    else
        log.info "Listening on ", CONST.DB_CONFIG.URL
    return

config_socket.on "message", (request) ->
    newData = proto_config.parse(request, "virtdb.interface.pb.ServerConfig")
    module.exports.emit CONST.DB_CONFIG.MESSAGE, newData;
    return


#
# On exit close the sockets
#
module.exports.on CONST.CLOSE_MESSAGE, () ->
    config_socket.close()
