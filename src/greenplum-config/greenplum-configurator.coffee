pg          = require 'pg'
async       = require 'async'
log = (require 'virtdb-connector').log
V_ = log.Variable


PostgresConfigurator = require './postgres-configurator'

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
            @_AddViewComments
            @_AddTableFieldComments
            @_AddViewFieldComments
        ]

    _AddTableComments: (callback) =>
        super(callback)

    _AddViewComments: (callback) =>
        super(callback)

    _AddTableFieldComments: (callback) =>
        super(callback)

    _AddViewFieldComments: (callback) =>
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
            q_create_table += ")
                LOCATION ('virtdb://#{@config_service_url};#{@config_data.Name};#{table.Schema};#{table.Name}')
                FORMAT 'text' (delimiter E'\\001' null '' escape 'OFF')
                ENCODING 'UTF8'
                LOG ERRORS INTO #{@filledConfig.Preferences.ErrorTable}
                SEGMENT REJECT LIMIT #{@filledConfig.Preferences.RejectLimit} ROWS
            "
            @_Query q_create_table, tables_callback
        , (err) =>
            log.debug "", @config_data.Tables.length, "tables created"
            callback(err)

module.exports = GreenplumConfigurator
