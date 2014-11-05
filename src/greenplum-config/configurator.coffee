CONST       = require("./config").Const
ERROR       = require("./config").Error
pg          = require 'pg'
async       = require 'async'
VirtDBConnector = require 'virtdb-connector'
log = VirtDBConnector.log
V_ = log.Variable
util = require "util"

require('source-map-support').install();

class PostgresConfigurator
    @instance: null
    postgres: null
    filledConfig: null
    done: null
    queue: []
    timeout: null
    working: false
    config_data: null
    ConfigQueries: null
    cica: null

    constructor: () ->
        @ConfigQueries = [
            @_CreateExtension
            @_CreateServer
            @_DropTables
            @_CreateTables
            @_AddTableComments
            @_AddFieldComments
        ]

    connect: (@config_service_url, @appName, @filledConfig) ->
        return

    add: (server_config) =>
        if not @filledConfig?
            log.error "Greenplum configurator is not yet configured."
            return
        @queue.push server_config
        if not @timeout
            log.info "Queue exists?", V_(@queue)
            @timeout = setInterval =>
                log.info "In _work, queue:", V_(@queue)
                if @queue.length == 0
                    clearInterval @timeout
                    @timeout = null
                    return
                if @working
                    return
                @working = true
                current = @queue.shift()
                @_Perform current, =>
                    @working = false
            , 100


    @getInstance: () =>
        @instance ?= new PostgresConfigurator()

    _CreateExtension: (callback) =>
        @_Query "CREATE EXTENSION IF NOT EXISTS virtdb_fdw", callback

    _CreateServer: (callback) =>
        @_Query "CREATE SERVER #{@config_data.Name}_srv foreign data wrapper virtdb_fdw", callback

    _DropTables: (callback) =>
        async.each @config_data.Tables, (table, tables_callback) =>
            @_Query "DROP FOREIGN TABLE IF EXISTS #{@_FullTableName(table)} CASCADE", tables_callback
        , (err) =>
            log.debug "", @config_data.Tables.length, "tables dropped", V_(err)
            callback()

    _CreateTables: (callback) =>
        async.each @config_data.Tables, (table, tables_callback) =>
            q_create_table = "
                CREATE FOREIGN TABLE #{@_FullTableName(table)} (
            "
            for field in table.Fields
                q_create_table += "\"#{field.Name}\" #{@_PostgresType(field)}, "

            q_create_table = q_create_table.substring(0, q_create_table.length - 2)
            q_create_table += ") server #{config_data.Name}_srv"
            @_Query q_create_table, tables_callback
        , (err) =>
            log.debug "", @config_data.Tables.length, "tables created"
            callback(err)

    _Query: (query, callback, ignoreError = false) =>
        # log.info "query", V_(query)
        timedOut = false
        @filledConfig.Preferences.QueryTimeout ?= 60000
        queryTimeout = setTimeout () =>
            timedOut = true
            log.info "Could not process query in time, cancelling"
            newpg = new pg.Client({ port: @postgres.port, host: @postgres.host})
            newpg.cancel query
            log.info "Cancel sent."
            callback(new Error("Query timed out"))
        , @filledConfig.Preferences.QueryTimeout
        @postgres.query query, (err, result) =>
            if not timedOut
                clearTimeout queryTimeout
                @done()
                if ignoreError
                    err = null
                if err
                    callback? err
                    return
                callback?(err, result)

    _work: =>
        log.info "In _work, queue:", V_(@queue)
        if @queue.length == 0
            clearInterval @timeout
            @timeout = null
            return
        if @working
            return
        @working = true
        current = @queue.shift()
        @_Perform current, =>
            @working = false

    _Perform: (@config_data, perform_done) =>
        log.info "Connecting to Postgres."
        pgconf = @filledConfig.Postgres
        @cica = "cicamica"
        connectionString = "postgres://#{pgconf.User}:#{pgconf.Password}@#{pgconf.Host}:#{pgconf.Port}/#{pgconf.Catalog}"
        pg.connect connectionString, (err, client, @done) =>
            if err
                log.error "Error while connecting to postgres server", V_(err)
                perform_done()
                return
            @postgres = client
            log.info "ConfigQueries.lenghth: ", V_(@ConfigQueries.length)
            async.series @ConfigQueries, (err, results) =>
                if err
                    log.error "Error happened in perform", V_(err)
                done()
                perform_done()

    _SchemaName: (table) =>
        if @filledConfig?.Preferences?.IgnoreSchema or not table.Schema?
            "\"#{@config_data.Name}\""
        else
            "\"#{@config_data.Name}_#{table.Schema}\""

    _TableName: (table) =>
        "\"#{table.Name}\""

    _FullTableName: (table) =>
        "#{@_SchemaName(table)}.#{@_TableName(table)}"

    _PostgresType: (field) =>
        switch field.Desc.Type
            when 'INT32', 'UINT32'
                "INTEGER"
            when 'INT64', 'UINT64'
                "BIGINT"
            when 'FLOAT'
                "FLOAT4"
            when 'DOUBLE'
                "FLOAT8"
            when 'NUMERIC'
                if field.Desc.Length?
                    field.Desc.Scale ?= 0
                    "NUMERIC(#{field.Desc.Length}, #{field.Desc.Scale})"
                else
                    "NUMERIC"
            when 'DATE'
                "DATE"
            when 'TIME'
                "TIME"
            when "DATETIME"
                "TIMESTAMP"
            when "BYTES"
                "BYTEA"
            else
                if field.Desc.Length?
                    "VARCHAR(#{field.Desc.Length})"
                else
                    "VARCHAR"

    _AddTableComments: (callback) =>
        log.info "config_data", V_(@config_data)
        async.each @config_data.Tables, (table, tables_callback) =>
            if table.Comments?[0]?.Text?
                comment = table.Comments[0]
                q_table_comment = "COMMENT ON TABLE #{@_FullTableName(table)} IS '#{comment.Text}'"
                @_Query q_table_comment, tables_callback
            else
                tables_callback()
        , (err) =>
            log.debug "table comment added"
            callback(err)

    _AddFieldComments: (callback) =>
        async.each @config_data.Tables, (table, tables_callback) =>
            async.each table.Fields, (field, fields_callback) =>
                if field.Comments?[0]?.Text?
                    comment = field.Comments[0]
                    q_comment = "COMMENT ON COLUMN #{@_FullTableName(table)}.\"#{field.Name}\" IS '#{comment.Text}'"
                    @_Query q_comment, fields_callback
                else
                    fields_callback()
            , (err) =>
                tables_callback(err)
        , (err) =>
            log.debug "field comment added"
            callback(err)

class GreenplumConfigurator extends PostgresConfigurator
    constructor: () ->
        log.info "GreenplumConfigurator ctr"
        @ConfigQueries = [
            @_CreateImportFunction
            # @_DropProtocol
            @_CreateProtocol
            @_DropTables
            @_CreateSchema
            @_CreateTables
            @_AddTableComments
            @_AddFieldComments
        ]

    _AddTableComments: (callback) =>
        super(callback)

    _AddFieldComments: (callback) =>
        super(callback)

    @getInstance: () =>
        log.info "Getinstance"
        @instance ?= new GreenplumConfigurator()

    queryConfig: (query, callback) =>
        @queriedProvider = query.Name
        async.series [
            @_Connect,
            @_QueryExternalTables
        ], (err, results) ->
            if err
                log.error "Error happened in perform", V_(err)
            reply =
                Servers: []
            orderedResults = {}
            for result in results
                if result?.rows?
                    for row in result.rows
                        meta = {}
                        value = row.location.split(";")
                        server_name = value[value.length - 3]
                        meta.Schema = value[value.length - 2]
                        meta.Name = value[value.length - 1]
                        orderedResults[server_name] ?= []
                        orderedResults[server_name].push meta
                        # reply.Servers[0].Tables.push meta
            for serverName, meta of orderedResults
                server =
                    Type: ""
                    Name: serverName
                    Tables: meta
                reply.Servers.push server
            callback reply

    _Connect: (callback) =>
        pgconf = @filledConfig.Postgres
        connectionString = "postgres://#{pgconf.User}:#{pgconf.Password}@#{pgconf.Host}:#{pgconf.Port}/#{pgconf.Catalog}"
        log.info "_Connect called", V_(connectionString)
        pg.connect connectionString, (err, client, @done) =>
            if err
                callback err
                return
            @postgres = client
            callback(err)

    _QueryExternalTables: (callback) =>
        q_get_external_tables = "SELECT location[1] FROM PG_EXTTABLE WHERE location[1] like 'virtdb://#{@config_service_url};#{@queriedProvider};%'"
        @_Query q_get_external_tables, callback

    _CreateImportFunction: (callback) =>
        log.info "_CreateImportFunction called"
        q_create_import_function =
            "CREATE FUNCTION virtdb_import()
                RETURNS integer as '#{@filledConfig.Extension.Path}',
                'virtdb_import' language C stable"
        @_Query q_create_import_function, (err, results) =>
            callback()

    _DropProtocol: (callback) =>
        log.info "Drop protocol called"
        q_drop_protocol = "DROP protocol if exists virtdb;"
        @_Query q_drop_protocol, callback

    _CreateProtocol: (callback) =>
        @_Query "select routine_name from information_schema.routines where specific_name = 'virtdb_import_'||(select ptcreadfn from pg_extprotocol where ptcname = 'virtdb');", (err, results) =>
            if err or results?.rows?[0]?.routine_name isnt 'virtdb_import'
                @_Query "CREATE TRUSTED PROTOCOL virtdb ( readfunc='virtdb_import' ) ", callback
            else
                callback()

    _DropTables: (callback) =>
        async.each @config_data.Tables, (table, tables_callback) =>
            q_drop_table = "DROP EXTERNAL TABLE IF EXISTS #{@_FullTableName(table)} CASCADE"
            @_Query q_drop_table, tables_callback
        , (err) =>
            log.debug "", @config_data.Tables.length, "tables dropped", V_(err)
            callback()

    _CreateSchema: (callback) =>
        log.info "In create schema", V_(@config_data)
        async.each @config_data.Tables, (table, tables_callback) =>
            q_create_schema = "CREATE SCHEMA #{@_SchemaName(table)}"
            @_Query q_create_schema, (err) =>
                tables_callback()
        , (err) =>
            log.debug "", @config_data.Tables.length, "schemas created"
            callback(err)

    _CreateTables: (callback) =>
        async.each @config_data.Tables, (table, tables_callback) =>
            q_create_table = "
                CREATE EXTERNAL TABLE #{@_FullTableName(table)} (
            "
            for field in table.Fields
                q_create_table += "\"#{field.Name}\" #{@_PostgresType(field)}, "

            q_create_table = q_create_table.substring(0, q_create_table.length - 2)
            q_create_table += ") location ('virtdb://#{@config_service_url};#{@config_data.Name};#{table.Schema};#{table.Name}') format 'text' (delimiter E'\\001' null '' escape OFF) encoding 'UTF8'"
            @_Query q_create_table, tables_callback
        , (err) =>
            log.debug "", @config_data.Tables.length, "tables created"
            callback(err)

module.exports = GreenplumConfigurator
