zmq  = require("zmq")
fs   = require("fs")
p    = require("node-protobuf")
pb   = new p(fs.readFileSync("../src/meta_data.pb.desc"))

responder = zmq.socket("rep")
responder.on "message", (request) ->
  newRequest = pb.parse(request, "virtdb.interface.pb.MetaDataRequest")
  console.log "Received request: [", newRequest, "]"
  # TODO : fill MetaData here
  obj = name: "value"
  newReply = pb.serialize(obj, "virtdb.interface.pb.MetaDataReply")
  responder.send newReply
  return

responder.bind "tcp://*:55555", (err) ->
  if err
    console.log err
  else
    console.log "Listening on 55555..."
  return

process.on "SIGINT", ->
  responder.close()
  return
