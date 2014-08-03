# Hello World server
# Binds REP socket to tcp://*:5555
# Expects "Hello" from client, replies with "world"
zmq = require("zmq")
fs = require("fs")
p = require("node-protobuf")
pb = new p(fs.readFileSync("../../src/proto/data.desc"))

dumpObject = (data, indent) =>
    console.log indent, "Operand:", data.Operand
    if data.composite
        console.log indent, "composite:"
        indent += "    "
        dumpObject data.composite.Left, indent
        dumpObject data.composite.Right, indent
    if data.simple
        console.log indent, "simple:"
        indent += "  "
        console.log indent, "Variable: ", data.simple.Variable
        console.log indent, "Value: ", data.simple.Value

# socket to talk to clients
responder = zmq.socket("rep")
responder.on "message", (request) ->
  newData = pb.parse(request, "virtdb.interface.pb.Expression")
  dumpObject newData, ""

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
