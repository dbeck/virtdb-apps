pg          = require 'pg'
async       = require 'async'
log = (require 'virtdb-connector').log
PostgresConnection = require './postgres-connection'
V_ = log.Variable

class PostgresConfigurator
    @instance: null
    pgConnection: null
    ignoreSchema: false

    constructor: () ->

    connect: (@config_service_url, @appName, filledConfig, pgModule = pg) =>
        @ignoreSchema = filledConfig?.Preferences?.IgnoreSchema
        pgconf = filledConfig.Postgres
        connectionString = "postgres://#{pgconf.User}:#{pgconf.Password}@#{pgconf.Host}:#{pgconf.Port}/#{pgconf.Catalog}"
        @pgConnection = new PostgresConnection connectionString, pgModule
        return

    add: (server_config, callback) =>
        if not server_config.Tables? or server_config.Tables.length is 0 or not server_config.Name?
            callback new Error("Invalid config object (it does not contain any tables): #{server_config}")
            return
        log.info "Connecting to Postgres."
        configQueries = [
            @_CreateExtension
            @_CreateServer
            @_DropTables
            @_CreateSchema
            @_CreateTables
            @_CreateViews
            @_AddTableComments
            @_AddViewComments
            @_AddTableFieldComments
            @_AddViewFieldComments
        ]
        @pgConnection.Perform configQueries, server_config, callback

    @getInstance: () =>
        @instance ?= new PostgresConfigurator()

    _CreateExtension: (config_data, callback) =>
        @pgConnection.Query "SELECT fdwname FROM pg_foreign_data_wrapper", (err, results) =>
            if err then return callback(err, results)
            if results.rows?
                for row in results.rows
                    if row.fdwname is 'virtdb_fdw'
                        return callback()

            @pgConnection.Query "CREATE EXTENSION virtdb_fdw", (err, results) =>
                if err then return callback(err, results)
                @pgConnection.Query "ALTER FOREIGN DATA WRAPPER virtdb_fdw OPTIONS ( url '#{@config_service_url}')", callback

    _CreateServer: (config_data, callback) =>
        @pgConnection.Query "CREATE SERVER \"#{config_data.Name}_srv\"
                 FOREIGN DATA WRAPPER virtdb_fdw
        ", (err, results) =>
            callback()

    _DropTables: (config_data, callback) =>
        async.each config_data.Tables, (table, tables_callback) =>
            @pgConnection.Query "DROP FOREIGN TABLE IF EXISTS #{@_FullTableName(config_data.Name, table)} CASCADE", tables_callback
        , (err) =>
            log.debug "", config_data.Tables.length, "tables dropped", V_(err)
            callback()

    _CreateTables: (config_data, callback) =>
        async.each config_data.Tables, (table, tables_callback) =>
            if not table.Fields? or table.Fields.length is 0
                tables_callback(new Error("Invalid table data, no fields"))
                return
            log.info "Creating table: ", V_(table)
            q_create_table = "
                CREATE FOREIGN TABLE #{@_FullTableName(config_data.Name, table)} (
            "
            for field in table.Fields
                q_create_table += "\"#{field.Name}\" #{@_PostgresType(field)}, "

            q_create_table = q_create_table.substring(0, q_create_table.length - 2)
            q_create_table += ") server \"#{config_data.Name}_srv\""
            q_create_table += " OPTIONS ( provider '#{config_data.Name}'"
            if table.Schema? and table.Schema isnt ""
                q_create_table += ", schema '#{table.Schema}'"
            q_create_table += ")"
            @pgConnection.Query q_create_table, tables_callback
        , (err) =>
            log.debug "", config_data.Tables.length, "tables created"
            callback(err)

    _CreateViews: (config_data, callback) =>
        async.each config_data.Tables, (table, tables_callback) =>
            log.info "Creating views: ", V_(table)
            @pgConnection.Query "CREATE VIEW #{@_FullViewName(config_data.Name, table)} AS SELECT * FROM #{@_FullTableName(config_data.Name, table)}", tables_callback
        , (err) =>
            log.debug "", config_data.Tables.length, "views created"
            callback(err)

    _CreateSchema: (config_data, callback) =>
        log.info "In create schema", V_(config_data)
        async.each config_data.Tables, (table, tables_callback) =>
            q_create_schema = "CREATE SCHEMA #{@_SchemaName(config_data.Name, table)}"
            @pgConnection.Query q_create_schema, (err) =>
                tables_callback()
        , (err) =>
            log.debug "", config_data.Tables.length, "schemas created"
            callback(err)

    _SchemaName: (provider, table) =>
        if @ignoreSchema or not table.Schema?
            "\"#{provider}\""
        else
            "\"#{provider}_#{table.Schema}\""

    _TableName: (table) =>
        "\"#{table.Name}\""

    _ViewName: (table) =>
        "\"#{table.Name}_v\""

    _FullTableName: (provider, table) =>
        "#{@_SchemaName(provider, table)}.#{@_TableName(table)}"

    _FullViewName: (provider, table) =>
        "#{@_SchemaName(provider, table)}.#{@_ViewName(table)}"

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

    _AddTableComments: (config_data, callback) =>
        async.each config_data.Tables, (table, tables_callback) =>
            if table.Comments?[0]?.Text?
                comment = table.Comments[0]
                @pgConnection.Query "COMMENT ON TABLE #{@_FullTableName(config_data.Name, table)} IS '#{comment.Text}'", tables_callback
            else
                tables_callback()
        , (err) =>
            log.debug "table comment added"
            callback(err)

    _AddViewComments: (config_data, callback) =>
        async.each config_data.Tables, (table, tables_callback) =>
            if table.Comments?[0]?.Text?
                comment = table.Comments[0]
                @pgConnection.Query "COMMENT ON VIEW #{@_FullViewName(config_data.Name, table)} IS '#{comment.Text}'", tables_callback
            else
                tables_callback()
        , (err) =>
            log.debug "view comment added"
            callback(err)

    _AddTableFieldComments: (config_data, callback) =>
        async.each config_data.Tables, (table, tables_callback) =>
            async.each table.Fields, (field, fields_callback) =>
                if field.Comments?[0]?.Text?
                    comment = field.Comments[0]
                    @pgConnection.Query "COMMENT ON COLUMN #{@_FullTableName(config_data.Name, table)}.\"#{field.Name}\" IS '#{comment.Text}'", fields_callback
                else
                    fields_callback()
            , (err) =>
                tables_callback(err)
        , (err) =>
            log.debug "field comment added"
            callback(err)

    _AddViewFieldComments: (config_data, callback) =>
        async.each config_data.Tables, (table, tables_callback) =>
            async.each table.Fields, (field, fields_callback) =>
                if field.Comments?[0]?.Text?
                    comment = field.Comments[0]
                    @pgConnection.Query "COMMENT ON COLUMN #{@_FullViewName(config_data.Name, table)}.\"#{field.Name}\" IS '#{comment.Text}'", fields_callback
                else
                    fields_callback()
            , (err) =>
                tables_callback(err)
        , (err) =>
            log.debug "view field comment added"
            callback(err)

    _GetExternalTables: (query, callback) =>
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
        @pgConnection.Query q_get_external_tables, callback

    queryConfig: (query, callback) =>
        if not query.Name?
            callback(new Error("Invalid query config object (it does not contain Name: #{query})"))
            return
        log.info "Connecting to Postgres in query_config."
        @pgConnection.Perform [@_GetExternalTables], query, (err, results) =>
            if err
                log.error "Error happened in querying tables", V_(err)
                callback(err)
                return
            try
                reply =
                    Servers: []
                orderedResults = {}
                for result in results
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
            catch ex
                err = ex
            callback err, reply



module.exports = PostgresConfigurator
