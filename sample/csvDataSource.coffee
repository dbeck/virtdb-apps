# CSV Data server
# Binds REP socket to tcp://*:5555
# Expects Query from client
#

fs      = require("fs")             # reading data descriptor and CSV files
csv     = require("csv")            # csv parsing
glob    = require("glob")           # case insensitive file search
logger  = require("./logger.js")
protocol = require("./protocol.js")

# CSV processing
ProcessCSV = (query) =>
    out_data = {}
    limit = query.Limit || 100000
    for field in query.Fields
        out_data[field.Name] =
            QueryId: query.QueryId
            Name: field.Name
            Data:
                Type: 2
                StringValue: Array()
                IsNull: Array()
            EndOfData: true
    cursor = 0
    parser = csv.parse(
        columns: true
    )
    transformer = csv.transform(
        (data) ->
            for field in query.Fields
                if cursor < limit
                    out_data[field.Name].Data.StringValue.push data[field.Name]
                    out_data[field.Name].Data.IsNull.push false
            cursor += 1
        ,
        (err, output) ->
            console.log "finished"
            for field in query.Fields
                if out_data[field.Name].Data.StringValue.length >= 1
                    protocol.emit 'column', out_data[field.Name]
                    #console.log buf
                    console.log field.Name, " - length: ", out_data[field.Name].Data.StringValue.length, " last value: ", out_data[field.Name].Data.StringValue[out_data[field.Name].Data.StringValue.length - 1]
    )
    glob("data/" + query.Table + ".csv", { nocase: true }, (err, files) ->
        if files.length != 1
            console.log "Error. Not excatly one file with that name"
        else
            console.log "Opening file: ", files[0]
            fs.createReadStream(files[0]).pipe(parser).pipe(transformer)
    )


protocol.on "query", (query_data) ->
    logger.dumpQuery query_data
    ProcessCSV query_data
    return

process.on "SIGINT", ->
    protocol.emit 'close'
    return
