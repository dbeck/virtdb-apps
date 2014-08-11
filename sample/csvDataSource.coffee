# CSV Data server
# Binds REP socket to tcp://*:5555
# Expects Query from client
#

require('source-map-support').install();

logger  = require("./logger")
protocol = require("./protocol")
CONST = require("./config").Const
log = require('loglevel');
DataService = require('./dataService');

sendData = (column) ->
    protocol.emit CONST.DATA.MESSAGE, column
    log.debug column.Data.FieldName, " - length: ", column.Data.length(), " last value: ",
            column.Data.get(column.Data.length() - 1)

protocol.on CONST.QUERY.MESSAGE, (query_data) ->
    log.info "Query arrived: ", query_data.Table
    log.debug logger.dumpQuery query_data
    new DataService(query_data, sendData).process()
    return

process.on "SIGINT", ->
    protocol.emit CONST.CLOSE_MESSAGE
    return
