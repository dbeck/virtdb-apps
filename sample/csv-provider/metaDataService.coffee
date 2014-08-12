fs      = require("fs")             # reading data descriptor and CSV files
csv     = require("csv")            # csv parsing
glob    = require("glob")           # case insensitive file search
FieldData = require("./fieldData")
CONST = require("./config").Const
log = require('loglevel');
async = require("async")

class MetaDataService
    reply: []
    schema: null
    regexp: null

    # Public methods
    constructor: (request, @sendData) ->
        @schema = request.Schema
        @regexp = request.Name

    process: () =>
        #
        # Case-insensitive file lookup
        @reply.Tables = []
        glob(@schema+"/*.csv", { nocase: true }, (err, files) =>
            async.each(files,
                (file, callback) =>
                    # # Gathering output per column
                    # # CSV module objects
                    transformer = null
                    table_name = file.substring(file.lastIndexOf("data/")+"data/".length,file.lastIndexOf(".csv"));
                    if not table_name.match @regexp
                        callback()
                        return
                    current_table =
                        Name: table_name
                        Fields: []
                    console.time current_table.Name
                    first_row = true

                    on_record = (data) =>
                        if first_row
                            first_row = false
                            return data
                        else
                            transformer.end()
                            return null

                    on_end = (err, output) =>
                        if err
                            log.error err
                        else
                            if output.length > 0
                                for field in output[0]
                                    current_table.Fields.push(
                                        Name: field
                                        Desc:
                                            Type: 'STRING'
                                    )
                                @reply.Tables.push current_table

                    transformer = csv.transform on_record, on_end
                    parser = csv.parse(
                        columns: null
                    )
                    fs.createReadStream(file).pipe(parser).pipe(transformer).on 'end', () =>
                        console.timeEnd current_table.Name
                        # log.debug "end of ", file
                        callback()
                , () =>
                    @sendData @reply
            )
        )

module.exports = MetaDataService
