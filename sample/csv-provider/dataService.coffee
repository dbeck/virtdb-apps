fs      = require("fs")             # reading data descriptor and CSV files
csv     = require("csv")            # csv parsing
glob    = require("glob")           # case insensitive file search
FieldData = require("./fieldData")
CONST = require("./config").Const
log = require('loglevel')

class DataService
    limit: 0
    cursor: 0
    out_data: []
    table: ""
    fields: []
    transformer: null
    sendData: null

    # Private methods
    get_limit = (query) =>
        if query.Filter.length == 0 and query.Limit
            @limit = query.Limit
        else
            @limit = CONST.MAX_CHUNK_SIZE + 1

    fill_column_header = (query, field) =>
        {} =
            QueryId: query.QueryId
            Name: field.Name
            Data: FieldData.createInstance(field)
            EndOfData: false

    # Public methods
    constructor: (query, sendData) ->
        @out_data = []
        @table = query.Table
        @fields = query.Fields
        for field in @fields
            @out_data[field.Name] = fill_column_header(query, field)

        # Limit is only taken into consideration if we can handle all filters
        @limit = get_limit(query)

        # Counter for sending in chunks
        @cursor = 0

        @sendData = sendData

    on_record: (data) =>
        @cursor += 1
        for field in @fields
            @out_data[field.Name].Data.push data[field.Name]
            if @cursor == CONST.MAX_CMAX_CHUNK_SIZE
                @out_data[field.Name].EndOfData = false
                @sendData @out_data[field.Name]
                @out_data[field.Name].Data.reset()
        if @cursor == CONST.MAX_CHUNK_SIZE
            @cursor = 0
        if @cursor == @limit
            @transformer.end()

    on_end: (err, output) =>
        if err
            log.error err
            return
        for field in @fields
            # if out_data[field.Name].Data.length() >= 1
            @out_data[field.Name].EndOfData = true
            @sendData @out_data[field.Name]

    process: =>
        # Gathering output per column
        # CSV module objects
        @transformer = csv.transform @on_record, @on_end

        # transformer = csv.transform(on_record, on_end)
        parser = csv.parse(
            columns: true
        )

        # Case-insensitive file lookup
        glob("data/" + @table + ".csv", { nocase: true }, (err, files) =>
            if files.length != 1
                log.error "Error. Not excatly one file with that name"
            else
                log.debug "Opening file: ", files[0]
                fs.createReadStream(files[0]).pipe(parser).pipe(@transformer)
        )

module.exports = DataService
