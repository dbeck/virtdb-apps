# CSV Data server
# Binds REP socket to tcp://*:5555
# Expects Query from client
#

zmq     = require("zmq")            # messaging
fs      = require("fs")             # reading data descriptor and CSV files
p       = require("node-protobuf")  # serialization
csv     = require("csv")            # csv parsing
glob    = require("glob")           # case insensitive file search

pb      = new p(fs.readFileSync("../src/proto/data.desc"))
publisher = zmq.socket("pub")
publisher.bindSync "tcp://*:5556"

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
    if query.Fields.length > 0
        console.log indent, "Columns:"
    for field in query.Fields
        console.log indent + "  ", field
    if query.Limit
        console.log indent, "Limit: ", query.Limit

# CSV processing
ProcessCSV = (queryid, tableName, fields) =>
    out_data = {}
    limit = 100000
    for field in fields
        out_data[field.Name] =
            QueryId: queryid
            Name: field.Name
            Data:
                Type: 2
                StringValue: Array()
                IsNull: Array()
            EndOfData: true
    actual = 0
    parser = csv.parse(
        columns: true
    )
    transformer = csv.transform(
        (data) ->
            for field in fields
                if actual < limit
                    out_data[field.Name].Data.StringValue.push data[field.Name]
                    out_data[field.Name].Data.IsNull.push false
            actual += 1
        ,
        (err, output) ->
            console.log "finished"
            for field in fields
                if out_data[field.Name].Data.StringValue.length >= 1
                    buf = pb.serialize(out_data[field.Name], "virtdb.interface.pb.Column")
                    publisher.send(buf)
                    #console.log buf
                    console.log field.Name, " - length: ", out_data[field.Name].Data.StringValue.length, " last value: ", out_data[field.Name].Data.StringValue[out_data[field.Name].Data.StringValue.length - 1]
    )
    glob("data/" + tableName + ".csv", { nocase: true }, (err, files) ->
        if files.length != 1
            console.log "Error. Not excatly one file with that name"
        else
            console.log "Opening file: ", files[0]
            fs.createReadStream(files[0]).pipe(parser).pipe(transformer)
    )

query_socket = zmq.socket("rep")
query_socket.bind "tcp://*:55555", (err) ->
  if err
    console.log err
  else
    console.log "Listening on 55555..."
  return

query_socket.on "message", (request) ->
    query_socket.send "ack"
    working = true
    newData = pb.parse(request, "virtdb.interface.pb.Query")
    dumpQuery newData

    # read up CSV and extract data
    ProcessCSV newData.QueryId, newData.Table, newData.Fields
    console.log "processing csv"
    return

process.on "SIGINT", ->
  query_socket.close()
  return
