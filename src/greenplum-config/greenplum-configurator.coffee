pg          = require 'pg'
async       = require 'async'
log = (require 'virtdb-connector').log
V_ = log.Variable
PostgresConfigurator = require './postgres-configurator'

class GreenplumConfigurator extends PostgresConfigurator
    path: ""
    constructor: () ->

    connect: (config_service_url, appName, filledConfig, pgModule = pg) =>
        pgConf = filledConfig.Postgres
        @path = pgConf.Extension?.Path
        super(config_service_url, appName, filledConfig, pgModule)
        return

    add: (server_config, callback) =>
        if not server_config.Tables? or server_config.Tables.length is 0 or not server_config.Name?
            callback new Error("Invalid config object (it does not contain any tables): #{server_config}")
            return
        log.info "Connecting to Postgres."
        configQueries = [
            @_CreateImportFunction
            # @_DropProtocol
            @_CreateProtocol
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

    _AddTableComments: (config_data, callback) =>
        super(config_data, callback)

    _AddViewComments: (config_data, callback) =>
        super(config_data, callback)

    _AddTableFieldComments: (config_data, callback) =>
        super(config_data, callback)

    _AddViewFieldComments: (config_data, callback) =>
        super(config_data, callback)

    @getInstance: () =>
        @instance ?= new GreenplumConfigurator()

    queryConfig: (query, callback) =>
        @queriedProvider = query.Name
        if not query.Name?
            callback(new Error("Invalid query config object (it does not contain Name: #{query})"))
            return
        log.info "Connecting to Postgres in query_config."
        @pgConnection.Perform [@_QueryExternalTables], query, (err, results) =>
            if err
                log.error "Error happened in perform", V_(err)
                callback(err, results)
                return
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
            callback null,reply

    _QueryExternalTables: (query, callback) =>
        q_get_external_tables = "SELECT location[1] FROM PG_EXTTABLE WHERE location[1] like 'virtdb://#{@config_service_url};#{query.Name};%'"
        @pgConnection.Query q_get_external_tables, callback

    _CreateImportFunction: (config_data, callback) =>
        log.info "_CreateImportFunction called"
        q_create_import_function =
            "CREATE FUNCTION virtdb_import()
                RETURNS integer as '#{@path}',
                'virtdb_import' language C stable"
        @pgConnection.Query q_create_import_function, (err, results) =>
            callback()

    _DropProtocol: (config_data, callback) =>
        log.info "Drop protocol called"
        q_drop_protocol = "DROP protocol if exists virtdb;"
        @pgConnection.Query q_drop_protocol, callback

    _CreateProtocol: (config_data, callback) =>
        @pgConnection.Query "select routine_name from information_schema.routines where specific_name = 'virtdb_import_'||(select ptcreadfn from pg_extprotocol where ptcname = 'virtdb');", (err, results) =>
            if err or results?.rows?[0]?.routine_name isnt 'virtdb_import'
                @pgConnection.Query "CREATE TRUSTED PROTOCOL virtdb ( readfunc='virtdb_import' ) ", callback
            else
                callback()

    _DropTables: (config_data, callback) =>
        async.each config_data.Tables, (table, tables_callback) =>
            q_drop_table = "DROP EXTERNAL TABLE IF EXISTS #{@_FullTableName(config_data.Name, table)} CASCADE"
            @pgConnection.Query q_drop_table, tables_callback
        , (err) =>
            log.debug "", config_data.Tables.length, "tables dropped", V_(err)
            callback()

    _CreateSchema: (config_data, callback) =>
        super(config_data, callback)

    _CreateViews: (config_data, callback) =>
        super(config_data, callback)

    _CreateTables: (config_data, callback) =>
        async.each config_data.Tables, (table, tables_callback) =>
            if not table.Fields? or table.Fields.length is 0
                tables_callback(new Error("Invalid table data, no fields"))
                return
            q_create_table = "
                CREATE EXTERNAL TABLE #{@_FullTableName(config_data.Name, table)} (
            "
            for field in table.Fields
                q_create_table += "\"#{field.Name}\" #{@_PostgresType(field)}, "

            q_create_table = q_create_table.substring(0, q_create_table.length - 2)
            q_create_table += ")
                LOCATION ('virtdb://#{@config_service_url};#{config_data.Name};#{table.Schema};#{table.Name}')
                FORMAT 'text' (delimiter E'\\001' null '' escape 'OFF')
                ENCODING 'UTF8'
            "
            if config_data.Preferences?.ErrorTable?
                q_create_table += "LOG ERRORS INTO #{config_data.Preferences.ErrorTable}"
            if config_data.Preferences?.RejectLimit?
                q_create_table += "
                    SEGMENT REJECT LIMIT #{config_data.Preferences.RejectLimit} ROWS
                "
            @pgConnection.Query q_create_table, tables_callback
        , (err) =>
            if (err)
                log.error "Error happened while creating tables", V_(err)
            else
                log.debug "", config_data.Tables.length, "tables created"
            callback(err)

module.exports = GreenplumConfigurator
