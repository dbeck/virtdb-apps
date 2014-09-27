CONST = require("./config").Const
argv = require('minimist')(process.argv.slice(2))
Configurator = require './configurator'
VirtDBConnector = require 'virtdb-connector'
Protocol = require './protocol'
log = VirtDBConnector.log

class GreenplumConfig

    constructor: (@name, svcConfigAddress) ->
        VirtDBConnector.connect(@name, svcConfigAddress)

    listen: () =>
        VirtDBConnector.onIP () =>
            VirtDBConnector.setupEndpoint @name, Protocol.DBConfigServer, @_onMessage

    _onMessage: (serverConfig) =>
        new Configurator(serverConfig).Perform()

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
