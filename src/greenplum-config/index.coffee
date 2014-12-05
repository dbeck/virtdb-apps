CONST = require("./config").Const
PostgresConfigurator = require './postgres-configurator'
GreenplumConfigurator = require './greenplum-configurator'
VirtDBConnector = require 'virtdb-connector'
Protocol = require './protocol'
log = VirtDBConnector.log
V_ = log.Variable
util = require 'util'
argv = require('minimist')(process.argv.slice(2))

class GreenplumConfig
    @config: null

    constructor: (@name, @svcConfigAddress) ->
        VirtDBConnector.onAddress 'CONFIG', 'REQ_REP', @sendEmptyConfigTemplate
        VirtDBConnector.subscribe 'CONFIG', 'PUB_SUB', @onConfig, @name
        VirtDBConnector.connect(@name, @svcConfigAddress)

    sendEmptyConfigTemplate: (name, address) =>
        empty =
            AppName: @name
        console.log "Got address for CONFIG REQ_REP", name, address
        configToSend = VirtDBConnector.Convert.TemplateToOld empty
        Protocol.SendConfig address, configToSend, (reply) =>
            if not reply.ConfigData? or reply.ConfigData.length == 0
                reply = @_getConfigTemplate()
            else
                for config in reply.ConfigData
                    if config.Key is ''
                        config.Children = @_getConfigTemplate().ConfigData[0].Children
            Protocol.SendConfig address, reply, (reply) =>
                @connect reply

    _getConfigTemplate: () =>
        configTemplate =
            AppName: @name
            Config: [
                VariableName: 'Engine'
                Type: 'STRING'
                Scope: 'Postgres'
                Required: true
                Default: 'Postgres'
            ,
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
                Type: 'STRING'
                Scope: 'Extension'
                Required: true
            ,
                VariableName: 'IgnoreSchema'
                Type: 'BOOL'
                Scope: 'Preferences'
                Required: false
                Default: false
            ,
                VariableName: 'QueryTimeout'
                Type: 'UINT32'
                Scope: 'Preferences'
                Required: false
                Default: 3000
            ,
                VariableName: 'ErrorTable'
                Type: 'STRING'
                Scope: 'Preferences'
                Required: false
                Default: 'virtdb_errors'
            ,
                VariableName: 'RejectLimit'
                Type: 'UINT32'
                Scope: 'Preferences'
                Required: false
                Default: 1
            ]
        VirtDBConnector.Convert.TemplateToOld configTemplate

    connect: (config) =>
        try
            if config?
                newConfig = VirtDBConnector.Convert.ToNew config
                @config = VirtDBConnector.Convert.ToObject newConfig
                if @config?.Postgres?
                    @getConfigurator().connect @svcConfigAddress, @name, configObject
        catch e
            log.error "Caught exception", V_(e)


    onConfig: (config...) =>
        @connect Protocol.ParseConfig config[1]

    listen: () =>
        VirtDBConnector.onIP () =>
            VirtDBConnector.setupEndpoint @name, Protocol.DBConfigServer, @_onMessage
            VirtDBConnector.setupEndpoint @name, Protocol.DBConfigQueryServer, @_onQuery

    _onMessage: (serverConfig) =>
        try
            @getConfigurator().add serverConfig
        catch e
            log.error "Caught exception", V_(e)

    _onQuery: (configQuery) =>
        try
            @getConfigurator().queryConfig configQuery, (err, reply) ->
                if err?
                    log.error "Error happened while querying added tables.", V_(err)
                    return
                Protocol.SendConfigQueryReply reply
        catch e
            log.error "Caught exception", V_(e)

    getConfigurator: () =>
        if @config?.Postgres?.Engine?.toLowerCase() is "postgres"
            return PostgresConfigurator.getInstance()
        if @config?.Postgres?.Engine?.toLowerCase() is "greenplum"
            return PostgresConfigurator.getInstance()
        return null


console.log "Arguments got:", argv
greenplumConfig = new GreenplumConfig argv['name'], argv['url']
greenplumConfig.listen()

#
# On exit close the sockets
#
terminate = ->
    try
        if Protocol.DBConfigSocket?
            Protocol.DBConfigSocket.close()
    catch e
        log.error e
    process.exit()

process.on "SIGINT", terminate
process.on "SIGTERM", terminate
