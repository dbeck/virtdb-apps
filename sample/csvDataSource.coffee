# Hello World server
# Binds REP socket to tcp://*:5555
# Expects "Hello" from client, replies with "world"
zmq = require("zmq")
fs = require("fs")
p = require("node-protobuf")
pb = new p(fs.readFileSync("../src/data.pb.desc"))

# socket to talk to clients
responder = zmq.socket("rep")
responder.on "message", (request) ->
  newData = pb.parse(request, "virtdb.interface.pb.Expression")
  console.log "Received request: [", newData, "]"

  # do some 'work'
  setTimeout (->

    # send reply back to client.
    responder.send "World"
    return
  ), 1
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
