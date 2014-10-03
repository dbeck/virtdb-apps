CONST = require("./config").Const
Configurator = require './configurator'
VirtDBConnector = require 'virtdb-connector'
Protocol = require './protocol'
log = VirtDBConnector.log
V_ = log.Variable
argv = require('minimist')(process.argv.slice(2))

class GreenplumConfig

    constructor: (@name, @svcConfigAddress) ->
        VirtDBConnector.connect(@name, @svcConfigAddress)

    listen: () =>
        VirtDBConnector.onIP () =>
            VirtDBConnector.setupEndpoint @name, Protocol.DBConfigServer, @_onMessage

    _onMessage: (serverConfig) =>
        log.info "Got serverConfig"
        try
            new Configurator(serverConfig, @svcConfigAddress).Perform()
        catch e
            log.error "Caught exception", V_(e)

console.log "Arguments got:", argv
greenplumConfig = new GreenplumConfig(argv['name'], argv['url'])
greenplumConfig.listen()

#
# On exit close the sockets
#
process.on "SIGINT", ->
    if Protocol.DBConfigSocket?
        Protocol.DBConfigSocket.close()
    return
