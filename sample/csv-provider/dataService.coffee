fs      = require("fs")             # reading data descriptor and CSV files
csv     = require("csv")            # csv parsing
glob    = require("glob")           # case insensitive file search
FieldData = require("./fieldData")
CONST = require("./config").Const
VirtDBDataProvider = require 'virtdb-provider'
log = VirtDBDataProvider.log
V_ = log.Variable

class DataService
    limit: 0
    cursor: 0
    out_data: []
    query: null
    transformer: null
    sendData: null
    seqNo: 0

    # Private methods
    get_limit: =>
        if @query.Filter?.length == 0 and @query.Limit
            @limit = @query.Limit
        else
            @limit = CONST.MAX_CHUNK_SIZE + 1

    fill_column_header: (field) =>
        {} =
            QueryId: @query.QueryId
            Name: field.Name
            Data: FieldData.createInstance(field)
            SeqNo: @seqNo
            EndOfData: false

    # Public methods
    constructor: (@query, @sendData) ->
        @out_data = []
        for field in @query.Fields
            @out_data[field.Name] = @fill_column_header(field)

        # Limit is only taken into consideration if we can handle all filters
        @limit = @get_limit()

        # Counter for sending in chunks
        @cursor = 0
        log.info "end of ctr"

    on_record: (data) =>
        @cursor += 1
        for field in @query.Fields
            @out_data[field.Name].Data.push data[field.Name]
            if @cursor == @query.MaxChunkSize
                @out_data[field.Name].SeqNo = @seqNo
                @out_data[field.Name].EndOfData = false
                # log.debug "Sending column", V_(field.Name), V_(@out_data[field.Name].Data.length), V_(@out_data[field.Name].SeqNo)
                @sendData @out_data[field.Name]
                @out_data[field.Name].Data.reset()
        if @cursor == @query.MaxChunkSize
            @cursor = 0
            @seqNo += 1
        if @cursor == @limit
            @transformer.end()

    on_end: (err, output) =>
        # log.debug V_(output)
        if err
            log.error err
            return
        for field in @query.Fields
            # if out_data[field.Name].Data.length() >= 1
            @out_data[field.Name].SeqNo = @seqNo
            @out_data[field.Name].EndOfData = true
            @sendData @out_data[field.Name]
            # log.debug "Sending column", V_(field.Name), V_(@out_data[field.Name].Data.length), V_(@out_data[field.Name].SeqNo)
        return

    process: =>
        # Gathering output per column
        # CSV module objects
        @transformer = csv.transform @on_record, @on_end

        parser = csv.parse(
            columns: true
        )

        # Case-insensitive file lookup
        glob("data/" + @query.Table + ".csv", { nocase: true }, (err, files) =>
            if files.length != 1
                log.error "Error. Not excatly one file with that name"
            else
                # log.debug "Opening file: ", V_(files[0])
                fs.createReadStream(files[0]).pipe(parser).pipe(@transformer)
        )

module.exports = DataService
