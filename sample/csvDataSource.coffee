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

# CSV processing
ProcessCSV = (queryid, tableName, columns) =>
    out_data = {}
    for column in columns
        out_data[column] =
            QueryId: queryid
            Name: column
            Data:
                Type: 2
                StringValue: Array()
            EndOfData: true
    actual = 0
    parser = csv.parse(
        columns: true
    )
    transformer = csv.transform(
        (data) ->
            for column in columns
                out_data[column].Data.StringValue.push data[column]
            actual += 1
        ,
        (err, output) ->
            console.log "finished"
            for column in columns
                if out_data[column].Data.StringValue.length >= 1
                    buf = pb.serialize(out_data[column], "virtdb.interface.pb.Column")
                    console.log buf
                    #console.log column, " - length: ", out_data[column].length, " last value: ", out_data[column][out_data[column].length - 1]
    )
    glob(tableName+".csv", { nocase: true }, (err, files) ->
        if files.length != 1
            console.log "Error. Not excatly one file with that name"
        else
            console.log "Opening file: ", files[0]
            fs.createReadStream(files[0]).pipe(parser).pipe(transformer)
    )


# socket to talk to clients
responder = zmq.socket("rep")
responder.on "message", (request) ->
    newData = pb.parse(request, "virtdb.interface.pb.Query")
    dumpQuery newData

    # read up CSV and extract data
    ProcessCSV newData.QueryId, newData.Table, newData.Columns

    # send data back
    responder.send "World"
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
