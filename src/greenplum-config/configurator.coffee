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

    constructor: () ->
        @ConfigQueries = [
            @_CreateExtension
            @_CreateServer
            @_DropTables
            @_CreateSchema
            @_CreateTables
            @_CreateViews
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
        @_Query "SELECT fdwname FROM pg_foreign_data_wrapper", (err, results) =>
            if err then return callback(err, results)
            if results.rows?
                for row in results.rows
                    if row.fdwname is 'virtdb_fdw'
                        return callback()

            @_Query "CREATE EXTENSION virtdb_fdw", (err, results) =>
                if err then return callback(err, results)
                @_Query "ALTER FOREIGN DATA WRAPPER virtdb_fdw OPTIONS ( url '#{@config_service_url}')", callback

    _CreateServer: (callback) =>
        @_Query "CREATE SERVER \"#{@config_data.Name}_srv\"
                 FOREIGN DATA WRAPPER virtdb_fdw
        ", (err, results) =>
            callback()

    _DropTables: (callback) =>
        async.each @config_data.Tables, (table, tables_callback) =>
            @_Query "DROP FOREIGN TABLE IF EXISTS #{@_FullTableName(table)} CASCADE", tables_callback
        , (err) =>
            log.debug "", @config_data.Tables.length, "tables dropped", V_(err)
            callback()

    _CreateTables: (callback) =>
        async.each @config_data.Tables, (table, tables_callback) =>
            log.info "Creating table: ", V_(table)
            q_create_table = "
                CREATE FOREIGN TABLE #{@_FullTableName(table)} (
            "
            for field in table.Fields
                q_create_table += "\"#{field.Name}\" #{@_PostgresType(field)}, "

            q_create_table = q_create_table.substring(0, q_create_table.length - 2)
            q_create_table += ") server \"#{@config_data.Name}_srv\""
            q_create_table += " OPTIONS ( provider '#{@config_data.Name}'"
            if table.Schema? and table.Schema isnt ""
                q_create_table += ", schema '#{table.Schema}'"
            q_create_table += ")"
            @_Query q_create_table, tables_callback
        , (err) =>
            log.debug "", @config_data.Tables.length, "tables created"
            callback(err)

    _CreateViews: (callback) =>
        async.each @config_data.Tables, (table, tables_callback) =>
            log.info "Creating views: ", V_(table)
            @_Query "CREATE VIEW #{@_FullViewName(table)} AS SELECT * FROM #{@_FullTableName(table)}", tables_callback
        , (err) =>
            log.debug "", @config_data.Tables.length, "views created"
            callback(err)

    _CreateSchema: (callback) =>
        log.info "In create schema", V_(@config_data)
        async.each @config_data.Tables, (table, tables_callback) =>
            q_create_schema = "CREATE SCHEMA #{@_SchemaName(table)}"
            @_Query q_create_schema, (err) =>
                tables_callback()
        , (err) =>
            log.debug "", @config_data.Tables.length, "schemas created"
            callback(err)

    _Query: (query, callback, ignoreError = false, client = @postgres) =>
        log.info "query", V_(query)
        timedOut = false
        @filledConfig.Preferences.QueryTimeout ?= 60000
        queryTimeout = setTimeout () =>
            timedOut = true
            log.info "Could not process query in time, cancelling"
            newpg = new pg.Client({ port: client.port, host: client.host})
            newpg.cancel query
            log.info "Cancel sent."
            callback(new Error("Query timed out"))
        , @filledConfig.Preferences.QueryTimeout
        client.query query, (err, result) =>
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

    _ViewName: (table) =>
        "\"#{table.Name}_v\""

    _FullTableName: (table) =>
        "#{@_SchemaName(table)}.#{@_TableName(table)}"

    _FullViewName: (table) =>
        "#{@_SchemaName(table)}.#{@_ViewName(table)}"

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
                @_Query "COMMENT ON TABLE #{@_FullTableName(table)} IS '#{comment.Text}'", tables_callback
            else
                tables_callback()
        , (err) =>
            log.debug "table comment added"
            callback(err)

        async.each @config_data.Tables, (table, tables_callback) =>
            if table.Comments?[0]?.Text?
                comment = table.Comments[0]
                @_Query "COMMENT ON VIEW #{@_FullViewName(table)} IS '#{comment.Text}'", tables_callback
            else
                tables_callback()
        , (err) =>
            log.debug "view comment added"
            callback(err)

    _AddFieldComments: (callback) =>
        async.each @config_data.Tables, (table, tables_callback) =>
            async.each table.Fields, (field, fields_callback) =>
                if field.Comments?[0]?.Text?
                    comment = field.Comments[0]
                    @_Query "COMMENT ON COLUMN #{@_FullTableName(table)}.\"#{field.Name}\" IS '#{comment.Text}'", fields_callback
                else
                    fields_callback()
            , (err) =>
                tables_callback(err)
        , (err) =>
            log.debug "field comment added"
            callback(err)

        async.each @config_data.Tables, (table, tables_callback) =>
            async.each table.Fields, (field, fields_callback) =>
                if field.Comments?[0]?.Text?
                    comment = field.Comments[0]
                    @_Query "COMMENT ON COLUMN #{@_FullViewName(table)}.\"#{field.Name}\" IS '#{comment.Text}'", fields_callback
                else
                    fields_callback()
            , (err) =>
                tables_callback(err)
        , (err) =>
            log.debug "view field comment added"
            callback(err)

    queryConfig: (query, callback) =>
        log.info "Connecting to Postgres in query_config."
        pgconf = @filledConfig.Postgres
        connectionString = "postgres://#{pgconf.User}:#{pgconf.Password}@#{pgconf.Host}:#{pgconf.Port}/#{pgconf.Catalog}"
        pg.connect connectionString, (err, client, @done) =>
            if err
                log.error "Error while connecting to postgres server", V_(err)
                callback()
                return

            q_get_external_tables = "
                SELECT
                    opt.option_name,
                    opt.option_value AS schema_name,
                    tbl.foreign_table_name AS table_name
                FROM
                    information_schema.foreign_table_options opt,
                    information_schema.foreign_tables tbl
                WHERE
                    opt.foreign_table_schema = tbl.foreign_table_schema
                    AND opt.foreign_table_name = tbl.foreign_table_name
                    AND tbl.foreign_server_name = '#{query.Name}_srv'
                    AND
                        (opt.option_name = 'schema'
                        or (opt.option_name = 'provider'
                            and opt.foreign_table_name not in
			                      (select foreign_table_name
		                           from information_schema.foreign_table_options opt
	                               where option_name = 'schema')))
            "
            @_Query q_get_external_tables, (err, result) ->
                if err
                    log.error "Error happened in querying tables", V_(err)
                    callback()
                    return
                reply =
                    Servers: []
                orderedResults = {}
                if result?.rows?
                    for row in result.rows
                        meta = {}
                        server_name = query.Name
                        if row.option_name is 'schema'
                            meta.Schema = row.schema_name
                        meta.Name = row.table_name
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
            , false, client


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
            @_CreateViews
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
        super(callback)

    _CreateViews: (callback) =>
        super(callback)

    _CreateTables: (callback) =>
        async.each @config_data.Tables, (table, tables_callback) =>
            q_create_table = "
                CREATE EXTERNAL TABLE #{@_FullTableName(table)} (
            "
            for field in table.Fields
                q_create_table += "\"#{field.Name}\" #{@_PostgresType(field)}, "

            q_create_table = q_create_table.substring(0, q_create_table.length - 2)
            q_create_table += ") location ('virtdb://#{@config_service_url};#{@config_data.Name};#{table.Schema};#{table.Name}') format 'text' (delimiter E'\\001' null '' escape 'OFF') encoding 'UTF8'"
            @_Query q_create_table, tables_callback
        , (err) =>
            log.debug "", @config_data.Tables.length, "tables created"
            callback(err)

module.exports = PostgresConfigurator
