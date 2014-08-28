# CONST = require('./config').Const
Protocol    = require './protocol'
Diag        = require './diag'
Connector   = require './connector'

class VirtDB
    constructor: (@name, connectionString) ->
        Protocol.svcConfig connectionString, Connector.onEndpoint

        endpoint =
            Endpoints: [
                Name: @name
                SvcType: 'NONE'
            ]
        Protocol.sendEndpoint endpoint

    onMetaDataRequest: (callback) =>
        Connector.onIP =>
            Connector.setupEndpoint @name, Protocol.metaDataServer, callback
        return

    onQuery: (callback) =>
        Connector.onIP =>
            Connector.setupEndpoint @name, Protocol.queryServer, callback
            Connector.setupEndpoint @name, Protocol.columnServer

    sendMetaData: (data) ->
        Protocol.sendMetaData data

    sendColumn: (data) ->
        Protocol.sendColumn data

    close: =>
        Protocol.close()

    @log = Diag

module.exports = VirtDB
