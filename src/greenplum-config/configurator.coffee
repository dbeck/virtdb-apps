CONST       = require("./config").Const
ERROR       = require("./config").Error
pg          = require 'pg'
async       = require 'async'
VirtDBConnector = require 'virtdb-connector'
log = VirtDBConnector.log
V_ = log.Variable

require('source-map-support').install();

class Configurator
    postgres: null
    server_config: null
    done: null

    constructor: (@server_config, @config_service_url) ->
        return

    Query: (query, callback) =>
        log.info "query", V_(query)
        @postgres.query query, (err, result) =>
            @done()
            if err
                callback err
                return
            callback()

    Connect: (callback) =>
        log.info "Connect called"
        pg.connect CONST.POSTGRES_CONNECTION, (err, client, @done) =>
            if err
                callback err
                return
            @postgres = client
            callback()

    CreateImportFunction: (callback) =>
        log.info "CreateImportFunction called"
        q_create_import_function =
            "CREATE OR REPLACE FUNCTION virtdb_import()
                RETURNS integer as '#{CONST.SHARED_OBJECT_PATH}',
                'virtdb_import' language C stable"
        @Query q_create_import_function, callback

    DropProtocol: (callback) =>
        log.info "Drop protocol called"
        q_drop_protocol = "DROP protocol if exists virtdb;"
        @Query q_drop_protocol, callback

    CreateProtocol: (callback) =>
        log.info "Create protocol called"
        q_create_protocol = "
            CREATE TRUSTED PROTOCOL virtdb (
                readfunc='virtdb_import'
            )
        "
        @Query q_create_protocol, callback

    DropTables: (callback) =>
        async.each @server_config.Tables, (table, tables_callback) =>
            q_drop_table = "DROP EXTERNAL TABLE IF EXISTS #{table.Name} CASCADE"
            @Query q_drop_table, tables_callback
        , (err) =>
            log.debug "", @server_config.Tables.length, "tables dropped"
            callback(err)

    CreateTables: (callback) =>
        async.each @server_config.Tables, (table, tables_callback) =>
            q_create_table = "
                CREATE EXTERNAL TABLE #{table.Name} (
            "
            for field in table.Fields
                switch field.Desc.Type
                    when 'INT32', 'UINT32'
                        q_create_table += "\"" + field.Name + "\"" + " INTEGER, "
                    when 'INT64', 'UINT64'
                        q_create_table += "\"" + field.Name + "\"" + " BIGINT, "
                    when 'FLOAT'
                        q_create_table += "\"" + field.Name + "\"" + " FLOAT4, "
                    when 'DOUBLE'
                        q_create_table += "\"" + field.Name + "\"" + " FLOAT8, "
                    when 'NUMERIC'
                        q_create_table += "\"" + field.Name + "\"" + " NUMERIC, "
                    when 'DATE'
                        q_create_table += "\"" + field.Name + "\"" + " DATE, "
                    when 'TIME'
                        q_create_table += "\"" + field.Name + "\"" + " TIME, "
                    else
                        q_create_table += "\"" + field.Name + "\"" + " VARCHAR, "

            q_create_table = q_create_table.substring(0, q_create_table.length - 2)
            q_create_table += ") location ('virtdb://#{@config_service_url};#{@server_config.Name};#{table.Schema};#{table.Name}') format 'text' (delimiter E'\\001' null '' escape E'\\002') encoding 'UTF8'"
            # q_create_table += ") location ('virtdb://#{@config_service_url};#{@server_config.Name};#{table.Schema};#{table.Name}') format 'csv' (delimiter E'\\001')"
            @Query q_create_table, tables_callback
        , (err) =>
            log.debug "", @server_config.Tables.length, "tables created"
            callback(err)

    Perform: () =>
        log.info "Perform called"
        async.series [
            @Connect,
            @CreateImportFunction,
            @DropProtocol,
            @CreateProtocol,
            @DropTables,
            @CreateTables
        ], (err, results) ->
            if err
                log.error "Error happened in perform", V_(err)

module.exports = Configurator
