# CSV Data server
# Binds REP socket to tcp://*:5555
# Expects Query from client
#

require('source-map-support').install();

fs      = require("fs")             # reading data descriptor and CSV files
csv     = require("csv")            # csv parsing
glob    = require("glob")           # case insensitive file search
logger  = require("./logger")
protocol = require("./protocol")
FieldData = require("./fieldData")
config = require("./config")
CONST = config.Const
log = require('loglevel');

# CSV processing
ProcessCSV = (query) =>
    limit = CONST.MAX_CHUNK_SIZE
    if query.Filter.length == 0 and query.limit
        limit = query.Limit
    out_data = new Array()
    for field in query.Fields
        out_data[field.Name] =
            QueryId: query.QueryId
            Name: field.Name
            Data: FieldData.createInstance(field)
            EndOfData: false
    cursor = 0
    parser = csv.parse(
        columns: true
    )
    sendData = (column) ->
        protocol.emit 'column', column
        if column.EndOfData == true
            log.info field.Name, " - length: ", column.Data.length(), " last value: ",
                    column.Data.get(column.Data.length() - 1)
        else
            log.debug field.Name, " - length: ", column.Data.length(), " last value: ",
                    column.Data.get(column.Data.length() - 1)

    transformer = csv.transform(
        # Called per row
        (data) ->
            cursor += 1
            for field in query.Fields
                out_data[field.Name].Data.push data[field.Name]
                if cursor == limit
                    out_data[field.Name].EndOfData = false;
                    sendData out_data[field.Name]
                    out_data[field.Name].Data.reset()
            if cursor == limit
                cursor = 0
        ,
        # Called once after all rows have been processed
        (err, output) ->
            if err
                log.error err
                return
            for field in query.Fields
                # if out_data[field.Name].Data.length() >= 1
                out_data[field.Name].EndOfData = true;
                sendData out_data[field.Name]
    )
    glob("data/" + query.Table + ".csv", { nocase: true }, (err, files) ->
        if files.length != 1
            log.error "Error. Not excatly one file with that name"
        else
            log.debug "Opening file: ", files[0]
            fs.createReadStream(files[0]).pipe(parser).pipe(transformer)
    )


protocol.on CONST.QUERY.MESSAGE, (query_data) ->
    log.info "Query arrived: ", query_data.Table
    log.debug logger.dumpQuery query_data
    ProcessCSV query_data
    return

process.on "SIGINT", ->
    protocol.emit CONST.CLOSE_MESSAGE
    return
