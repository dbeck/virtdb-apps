# CSV Data server
# Binds REP socket to tcp://*:5555
# Expects Query from client
#

require('source-map-support').install()

logger  = require "./logger"
protocol = require "./protocol"
CONST = require("./config").Const
log = require 'loglevel'
DataService = require './dataService'
MetaDataService = require './metaDataService'
VirtDB = require './virtdb'
virtdb = null

sendData = (column) ->
    protocol.emit CONST.DATA.MESSAGE, column
    log.debug column.Data.FieldName, " - length: ", column.Data.length(), " last value: ",
            column.Data.get column.Data.length() - 1

sendMeta = (data) ->
    virtdb.sendMetaData data

protocol.on CONST.QUERY.MESSAGE, (query_data) ->
    log.info "Query arrived: ", query_data.Table
    log.debug logger.dumpQuery query_data
    new DataService(query_data, sendData).process()
    return

process.on "SIGINT", ->
    protocol.emit CONST.CLOSE_MESSAGE
    return

try
    virtdb = new VirtDB "csv-provider", "tcp://localhost:65001"

    virtdb.onMetaDataRequest (request) ->
        log.info "Metadata request arrived: ", request.Name
        new MetaDataService(request, sendMeta).process()
        return
catch e
    console.log e
