# CSV Data server
# Binds REP socket to tcp://*:5555
# Expects Query from client
#

require('source-map-support').install()

log = require 'loglevel'
DataService = require './dataService'
MetaDataService = require './metaDataService'
VirtDB = require './virtdb'


try
    virtdb = new VirtDB("csv-provider", "tcp://localhost:65001")

    VirtDB.info "Starting up"

    virtdb.onMetaDataRequest (request) ->
        VirtDB.info "Metadata request arrived: ", request.Name
        new MetaDataService(request, virtdb.sendMetaData).process()
        return

    virtdb.onQuery (query) ->
        VirtDB.info "Query arrived: ", query.QueryId
        new DataService(query, virtdb.sendColumn).process()

catch e
    virtdb?.close()
    console.log e

process.on "SIGINT", ->
    virtdb?.close()
    return
