# CSV Data server
# Binds REP socket to tcp://*:5555
# Expects Query from client
#

require('source-map-support').install()
argv = require('minimist')(process.argv.slice(2))

DataService = require './dataService'
MetaDataService = require './metaDataService'
VirtDB = require 'virtdb-connector'
log = VirtDB.log
V_ = log.Variable

try
    console.log "Arguments got:", argv
    virtdb = new VirtDB(argv['name'], argv['url'])

    now = new Date()

    log.info "Starting up @", V_(now.toLocaleDateString()), '-', V_(now.toLocaleTimeString())

    virtdb.onMetaDataRequest (request) ->
        log.info "Metadata request arrived: ", V_(request.Name)
        new MetaDataService(request, virtdb.sendMetaData).process()
        return

    virtdb.onQuery (query) ->
        log.info "Query arrived: ", V_(query.QueryId), V_(query.Table), V_(query.Fields)
        new DataService(query, virtdb.sendColumn).process()

catch e
    virtdb?.close()
    console.log e

process.on "SIGINT", ->
    virtdb?.close()
    return
