CONST       = require("./config").Const
ERROR       = require("./config").Error
pg          = require 'pg'
async       = require 'async'
VirtDBConnector = require 'virtdb-connector'
log = VirtDBConnector.log

require('source-map-support').install();

class Configurator
    postgres: null
    server_config: null
    done: null

    constructor: (@server_config) ->
        return

    Query: (query, callback) =>
        @postgres.query query, (err, result) =>
            @done()
            if err
                callback err
                return
            callback()

    Connect: (callback) =>
        pg.connect CONST.POSTGRES_CONNECTION, (err, client, @done) =>
            if err
                callback err
                return
            @postgres = client
            callback()

    CreateImportFunction: (callback) =>
        q_create_import_function =
            "CREATE OR REPLACE FUNCTION virtdb_import()
                RETURNS integer as #{CONST.SHARED_OBJECT_PATH},
                'virtdb_import' language C stable"
        @Query q_create_import_function, callback

    DropProtocol: (callback) =>
        q_drop_protocol = "DROP protocol virtdb;"
        @Query q_drop_protocol, callback

    CreateProtocol: (callback) =>
        q_create_protocol = "
            CREATE TRUSTED PROTOCOL virtdb (
                readfunc='virtdb_import'
            )
        "
        @Query q_create_protocol, callback

    DropTables: (callback) =>
        async.each @server_config.Tables, (table, tables_callback) =>
            q_drop_table = "DROP EXTERNAL TABLE #{table.Name} CASCADE"
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
            q_create_table += ") location ('virtdb://#{config_service_url};#{server_config.Name};#{table.Schema};#{table.Name}) format 'csv'"
            @Query q_create_table, tables_callback
        , (err) =>
            log.debug "", @server_config.Tables.length, "tables created"
            callback(err)

    Perform: () =>
        async.series [
            @Connect,
            @CreateImportFunction,
            @DropProtocol,
            @CreateProtocol,
            @DropTables,
            @CreateTables
        ], (err, results) ->
            if err
                log.error err

module.exports = Configurator
