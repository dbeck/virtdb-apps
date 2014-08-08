# CSV Data server
# Binds REP socket to tcp://*:5555
# Expects Query from client
#

require('source-map-support').install();

fs      = require("fs")             # reading data descriptor and CSV files
csv     = require("csv")            # csv parsing
glob    = require("glob")           # case insensitive file search
logger  = require("./logger.js")
protocol = require("./protocol.js")

class FieldData
    constructor: (field) ->
        @Type = 2
        @FieldName = field.Name
        @StringValue = new Array()
        @IsNull = new Array()

    push: (value) =>
        @StringValue.push value
        @IsNull.push false

    length: () =>
        @StringValue.length

    get: (index) =>
        @StringValue[index]

# CSV processing
ProcessCSV = (query) =>
    out_data = new Array()
    limit = query.Limit || 100000
    for field in query.Fields
        out_data[field.Name] =
            QueryId: query.QueryId
            Name: field.Name
            Data: new FieldData(field)
            EndOfData: true
    cursor = 0
    parser = csv.parse(
        columns: true
    )
    transformer = csv.transform(
        # Called per row
        (data) ->
            for field in query.Fields
                if cursor < limit
                    out_data[field.Name].Data.push data[field.Name]
            cursor += 1
        ,
        # Called once after all rows have been processed
        (err, output) ->
            for field in query.Fields
                if out_data[field.Name].Data.length() >= 1
                    protocol.emit 'column', out_data[field.Name]
                    console.log field.Name, " - length: ", out_data[field.Name].Data.length(), " last value: ",
                            out_data[field.Name].Data.get(out_data[field.Name].Data.length() - 1)
    )
    glob("data/" + query.Table + ".csv", { nocase: true }, (err, files) ->
        if files.length != 1
            console.log "Error. Not excatly one file with that name"
        else
            console.log "Opening file: ", files[0]
            fs.createReadStream(files[0]).pipe(parser).pipe(transformer)
    )


protocol.on "query", (query_data) ->
    #logger.dumpQuery query_data
    ProcessCSV query_data
    return

process.on "SIGINT", ->
    protocol.emit 'close'
    return
