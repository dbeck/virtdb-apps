CONST = require("./config").Const
Configurator = require './configurator'
VirtDBConnector = require 'virtdb-connector'
Protocol = require './protocol'
log = VirtDBConnector.log
V_ = log.Variable
util = require 'util'
argv = require('minimist')(process.argv.slice(2))

class GreenplumConfig

    constructor: (@name, @svcConfigAddress) ->
        console.log "GreenplumConfig ctr"
        VirtDBConnector.onAddress 'CONFIG', 'REQ_REP', @sendConfigTemplate
        VirtDBConnector.subscribe 'CONFIG', 'PUB_SUB', @onConfig, @name
        VirtDBConnector.connect(@name, @svcConfigAddress)
        # filledConfig =
        #     Postgres:
        #         Host: '192.168.221.11'
        #         Port: 5432
        #         Catalog: 'gpadmin'
        #         User: 'gpadmin'
        #         Password: 'manager'
        #     Extension:
        #         Path: '/usr/local/libgreenplum_ext.so'
        # Configurator.getInstance().connect @svcConfigAddress, @name, filledConfig

    sendConfigTemplate: (name, address) =>
        console.log "Got address for CONFIG REQ_REP", name, address
        configTemplate =
            AppName: @name
            Config: [
                VariableName: 'Host'
                Type: 'STRING'
                Scope: 'Postgres'
                Required: true
            ,
                VariableName: 'Port'
                Type: 'UINT32'
                Required: true
                Scope: 'Postgres'
                Default: 5432
            ,
                VariableName: 'Catalog'
                Type: 'STRING'
                Required: true
                Scope: 'Postgres'
                Default: 'gpadmin'
            ,
                VariableName: 'User'
                Type: 'STRING'
                Scope: 'Postgres'
                Required: false
            ,
                VariableName: 'Password'
                Type: 'STRING'
                Scope: 'Postgres'
                Required: false
            ,
                VariableName: 'Path'
                Scope: 'GLOBAL'
                Type: 'STRING'
                Scope: 'Extension'
                Required: true
            ]
        configToSend = VirtDBConnector.ConfigService.ConvertTemplateToOld configTemplate
        Protocol.SendConfig address, configToSend

    onConfig: (config...) =>
        configParsed = Protocol.ParseConfig config[1]
        if configParsed?
            newConfig = VirtDBConnector.ConfigService.ConvertToNew configParsed
            configObject = VirtDBConnector.ConfigService.ConvertToObject newConfig
            console.log util.inspect configObject, { depth: null}
            # filledConfig =
            #     Postgres:
            #         Host: '192.168.221.11'
            #         Port: 5432
            #         Catalog: 'gpadmin'
            #         User: 'gpadmin'
            #         Password: 'manager'
            #     SharedObjectPath: '/usr/local/libgreenplum_ext.so'
            Configurator.getInstance().connect @svcConfigAddress, @name, configObject

    listen: () =>
        VirtDBConnector.onIP () =>
            VirtDBConnector.setupEndpoint @name, Protocol.DBConfigServer, @_onMessage
            VirtDBConnector.setupEndpoint @name, Protocol.DBConfigQueryServer, @_onQuery

    _onMessage: (serverConfig) =>
        try
            console.log "onMessage", serverConfig
            new Configurator.getInstance().add serverConfig
        catch e
            console.log "Caught exception", e

    _onQuery: (configQuery) =>
        try
            console.log configQuery
            Configurator.getInstance().queryConfig configQuery, (reply) ->
                Protocol.SendConfigQueryReply reply
        catch e
            console.log "Caught exception", e

console.log "Arguments got:", argv
greenplumConfig = new GreenplumConfig argv['name'], argv['url']
greenplumConfig.listen()

# testObject =
#   Name: ""
#   SkipTables: false
#   SkipFields: true
#
# greenplumConfig._onQuery testObject

#
# On exit close the sockets
#
terminate = ->
    try
        if Protocol.DBConfigSocket?
            Protocol.DBConfigSocket.close()
    catch e
        console.log e
    process.exit()

process.on "SIGINT", terminate
process.on "SIGTERM", terminate
