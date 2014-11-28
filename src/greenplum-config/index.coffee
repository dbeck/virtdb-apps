CONST = require("./config").Const
Configurator = require './postgres-configurator'
VirtDBConnector = require 'virtdb-connector'
Protocol = require './protocol'
log = VirtDBConnector.log
V_ = log.Variable
util = require 'util'
argv = require('minimist')(process.argv.slice(2))

class GreenplumConfig
    @empty: null

    constructor: (@name, @svcConfigAddress) ->
        VirtDBConnector.onAddress 'CONFIG', 'REQ_REP', @sendEmptyConfigTemplate
        VirtDBConnector.subscribe 'CONFIG', 'PUB_SUB', @onConfig, @name
        VirtDBConnector.connect(@name, @svcConfigAddress)

    sendEmptyConfigTemplate: (name, address) =>
        @empty =
            AppName: @name
        console.log "Got address for CONFIG REQ_REP", name, address
        configToSend = VirtDBConnector.Convert.TemplateToOld @empty
        Protocol.SendConfig address, configToSend, (reply) =>
            if not reply.ConfigData? or reply.ConfigData.length == 0
                @sendConfigTemplate address
            else
                @connect reply

    sendConfigTemplate: (address) =>
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
        configToSend = VirtDBConnector.Convert.TemplateToOld configTemplate
        Protocol.SendConfig address, configToSend

    connect: (config) =>
        if config?
            newConfig = VirtDBConnector.Convert.ToNew config
            configObject = VirtDBConnector.Convert.ToObject newConfig
            if configObject?.Postgres?
                Configurator.getInstance().connect @svcConfigAddress, @name, configObject


    onConfig: (config...) =>
        @connect Protocol.ParseConfig config[1]

    listen: () =>
        VirtDBConnector.onIP () =>
            VirtDBConnector.setupEndpoint @name, Protocol.DBConfigServer, @_onMessage
            VirtDBConnector.setupEndpoint @name, Protocol.DBConfigQueryServer, @_onQuery

    _onMessage: (serverConfig) =>
        try
            new Configurator.getInstance().add serverConfig
        catch e
            log.error "Caught exception", V_(e)

    _onQuery: (configQuery) =>
        try
            Configurator.getInstance().queryConfig configQuery, (err, reply) ->
                if err?
                    log.error "Error happened while querying added tables.", V_(err)
                    return
                Protocol.SendConfigQueryReply reply
        catch e
            log.error "Caught exception", V_(e)

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
