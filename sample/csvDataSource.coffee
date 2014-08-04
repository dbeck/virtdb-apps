# Hello World server
# Binds REP socket to tcp://*:5555
# Expects "Hello" from client, replies with "world"
zmq = require("zmq")
fs = require("fs")
p = require("node-protobuf")
pb = new p(fs.readFileSync("../src/proto/data.desc"))

dumpExpression = (expression, indent) =>
    console.log indent, "Operand:", expression.Operand
    if expression.Composite
        console.log indent, "Composite:"
        indent += "    "
        dumpExpression expression.Composite.Left, indent
        dumpExpression expression.Composite.Right, indent
    if expression.Simple
        console.log indent, "Simple:"
        indent += "  "
        console.log indent, "Variable: ", expression.Simple.Variable
        console.log indent, "Value: ", expression.Simple.Value

dumpQuery = (query) =>
    console.log "Query:"
    indent = "  "
    console.log indent, "QueryId:", query.QueryId
    console.log indent, "Table:", query.Table
    for filter in query.Filter
        console.log  indent, "Filter:"
        dumpExpression filter, indent + "  "
    if query.Columns.length > 0
        console.log indent, "Columns:"
    for column in query.Columns
        console.log indent + "  ", column
    if query.Limit
        console.log indent, "Limit: ", query.Limit

# socket to talk to clients
responder = zmq.socket("rep")
responder.on "message", (request) ->
  # newData = pb.parse(request, "virtdb.interface.pb.Expression")
  # dumpExpression newData, ""
  newData = pb.parse(request, "virtdb.interface.pb.Query")
  #console.log "Query received: ", newData
  dumpQuery newData
  #dumpExpression newData, ""

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
