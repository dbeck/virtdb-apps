# CSV Data server
# Binds REP socket to tcp://*:5555
# Expects Query from client
#

require('source-map-support').install()

log = require 'loglevel'
DataService = require './dataService'
MetaDataService = require './metaDataService'
VirtDB = require 'virtdb-connector'
log = VirtDB.log
V = log.Variable

try
    virtdb = new VirtDB("csv-provider", "tcp://localhost:65001")

    now = new Date()

    log.info "Starting up @", V(now.toLocaleDateString()), '-', V(now.toLocaleTimeString())

    virtdb.onMetaDataRequest (request) ->
        log.info "Metadata request arrived: ", V(request.Name)
        new MetaDataService(request, virtdb.sendMetaData).process()
        return

    virtdb.onQuery (query) ->
        log.info "Query arrived: ", V(query.QueryId)
        new DataService(query, virtdb.sendColumn).process()

catch e
    virtdb?.close()
    console.log e

process.on "SIGINT", ->
    virtdb?.close()
    return
