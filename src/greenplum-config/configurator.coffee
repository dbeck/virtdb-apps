CONST       = require("./config").Const
ERROR       = require("./config").Error
pg          = require 'pg'
async       = require 'async'
VirtDBConnector = require 'virtdb-connector'
log = VirtDBConnector.log
V_ = log.Variable

require('source-map-support').install();

class Configurator
    @instance: null
    postgres: null
    server_config: null
    done: null
    filledConfig: {}
    queue: []
    timeout: null
    working: false

    @getInstance: () =>
        @instance ?= new Configurator()

    connect: (@config_service_url, @appName, @filledConfig) ->
        return

    add: (server_config) =>
        @queue.push server_config
        if not @timeout
            @timeout = setInterval @_work, 100

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

    _work: =>
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

    _SchemaName: (table) =>
        if @filledConfig?.Preferences?.IgnoreSchema or not table.Schema?
            "\"#{@server_config.Name}\""
        else
            "\"#{@server_config.Name}_#{table.Schema}\""

    _TableName: (table) =>
        "\"#{table.Name}\""

    _FullTableName: (table) =>
        "#{@_SchemaName(table)}.#{@_TableName(table)}"

    _Query: (query, callback) =>
        log.info "query", V_(query)
        @postgres.query query, (err, result) =>
            @done()
            if err
                callback? err
                return
            callback?(err, result)

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
        q_get_external_tables = "SELECT location[1] FROM PG_EXTTABLE WHERE location[1] like 'virtdb://#{@config_service_url};#{@queriedProvider}%'"
        @_Query q_get_external_tables, callback

    _CreateImportFunction: (callback) =>
        log.info "_CreateImportFunction called"
        q_create_import_function =
            "CREATE OR REPLACE FUNCTION virtdb_import()
                RETURNS integer as '#{@filledConfig.Extension.Path}',
                'virtdb_import' language C stable"
        @_Query q_create_import_function, callback

    _DropProtocol: (callback) =>
        log.info "Drop protocol called"
        q_drop_protocol = "DROP protocol if exists virtdb;"
        @_Query q_drop_protocol, callback

    _CreateProtocol: (callback) =>
        log.info "Create protocol called"
        q_create_protocol = "
            CREATE TRUSTED PROTOCOL virtdb (
                readfunc='virtdb_import'
            )
        "
        @_Query q_create_protocol, callback

    _DropTables: (callback) =>
        async.each @server_config.Tables, (table, tables_callback) =>
            q_drop_table = "DROP EXTERNAL TABLE IF EXISTS #{@_FullTableName(table)} CASCADE"
            @_Query q_drop_table, tables_callback
        , (err) =>
            log.debug "", @server_config.Tables.length, "tables dropped", V_(err)
            callback()

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
            else
                if field.Desc.Length?
                    "VARCHAR(#{field.Desc.Length})"
                else
                    "VARCHAR"

    _CreateSchema: (callback) =>
        log.info "In create schema"
        async.each @server_config.Tables, (table, tables_callback) =>
            q_create_schema = "CREATE SCHEMA #{@_SchemaName(table)}"
            @_Query q_create_schema, (err) =>
                tables_callback()
        , (err) =>
            log.debug "", @server_config.Tables.length, "schemas created"
            callback(err)



    _CreateTables: (callback) =>
        async.each @server_config.Tables, (table, tables_callback) =>
            q_create_table = "
                CREATE EXTERNAL TABLE #{@_FullTableName(table)} (
            "
            for field in table.Fields
                q_create_table += "\"#{field.Name}\" #{@_PostgresType(field)}, "

            q_create_table = q_create_table.substring(0, q_create_table.length - 2)
            q_create_table += ") location ('virtdb://#{@config_service_url};#{@server_config.Name};#{table.Schema};#{table.Name}') format 'text' (delimiter E'\\001' null '' escape E'\\002') encoding 'UTF8'"
            @_Query q_create_table, tables_callback
        , (err) =>
            log.debug "", @server_config.Tables.length, "tables created"
            callback(err)

    _AddTableComments: (callback) =>
        async.each @server_config.Tables, (table, tables_callback) =>
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
        async.each @server_config.Tables, (table, tables_callback) =>
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

    _Perform: (@server_config, done) =>
        log.info "_Perform called"
        async.series [
            @_Connect,
            @_CreateImportFunction,
            @_DropProtocol,
            @_CreateProtocol,
            @_DropTables,
            @_CreateSchema,
            @_CreateTables,
            @_AddTableComments
            @_AddFieldComments
        ], (err, results) ->
            if err
                log.error "Error happened in perform", V_(err)
            done()

module.exports = Configurator
