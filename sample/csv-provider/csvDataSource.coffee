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

process.on "SIGINT", ->
    protocol.emit CONST.CLOSE_MESSAGE
    return

try
    virtdb = new VirtDB "csv-provider", "tcp://localhost:65001"

    virtdb.onMetaDataRequest (request) ->
        log.debug "Metadata request arrived: ", request.Name
        new MetaDataService(request, virtdb.sendMetaData).process()
        return

    virtdb.onQuery (query) ->
        log.debug "Query arrived: ", query.QueryId
        new DataService(query, virtdb.sendColumn).process()

catch e
    console.log e
