CONST = require("./config").Const

zmq             = require("zmq")
EventEmitter    = require('events').EventEmitter
fs              = require("fs")
p               = require("node-protobuf")
proto_data      = new p(fs.readFileSync(CONST.DATA.PROTO_FILE))
proto_meta      = new p(fs.readFileSync(CONST.METADATA.PROTO_FILE))
log             = require('loglevel')

module.exports = new EventEmitter()

#
# On exit close the sockets
#
module.exports.on CONST.CLOSE_MESSAGE, ->
    query_socket.close()
    publisher_socket.close()
