CONST = require("./config").Const
argv = require('minimist')(process.argv.slice(2))
Configurator = require './configurator'
VirtDBConnector = require 'virtdb-connector'
Protocol = require './protocol'
log = VirtDBConnector.log

class PostgresConfig

    constructor: (@name, svcConfigAddress) ->
        VirtDBConnector.connect(@name, svcConfigAddress)

    listen: () =>
        VirtDBConnector.onIP () =>
            VirtDBConnector.setupEndpoint @name, Protocol.DBConfigServer, @_onMessage

    _onMessage: (serverConfig) =>
        new Configurator(serverConfig).Perform()

console.log "Arguments got:", argv
postgresConfig = new PostgresConfig(argv['name'], argv['url'])
postgresConfig.listen()

#
# On exit close the sockets
#
process.on "SIGINT", ->
    if Protocol.DBConfigSocket?
        Protocol.DBConfigSocket.close()
    return
