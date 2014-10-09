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

    PostgresType: (field) =>
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

    CreateTables: (callback) =>
        async.each @server_config.Tables, (table, tables_callback) =>
            q_create_table = "
                CREATE EXTERNAL TABLE #{table.Name} (
            "
            for field in table.Fields
                q_create_table += "\"#{field.Name}\" #{@PostgresType(field)}, "

            q_create_table = q_create_table.substring(0, q_create_table.length - 2)
            q_create_table += ") location ('virtdb://#{@config_service_url};#{@server_config.Name};#{table.Schema};#{table.Name}') format 'text' (delimiter E'\\001' null '' escape E'\\002') encoding 'UTF8'"
            # q_create_table += ") location ('virtdb://#{@config_service_url};#{@server_config.Name};#{table.Schema};#{table.Name}') format 'csv' (delimiter E'\\001')"
            @Query q_create_table, tables_callback
        , (err) =>
            log.debug "", @server_config.Tables.length, "tables created"
            callback(err)

    AddComments: (callback) =>
        async.each @server_config.Tables, (table, tables_callback) =>
            async.each table.Fields, (field, fields_callback) =>
                if field.Comments?
                    comment = field.Comments[0]
                    q_comment = "COMMENT ON COLUMN #{table.Name}.\"#{field.Name}\" IS '#{comment.Text}'"
                    @Query q_comment, fields_callback
                else
                    fields_callback()
            , (err) =>
                tables_callback(err)
        , (err) =>
            log.debug "comment added"
            callback(err)

    Perform: () =>
        log.info "Perform called"
        async.series [
            @Connect,
            @CreateImportFunction,
            @DropProtocol,
            @CreateProtocol,
            @DropTables,
            @CreateTables,
            @AddComments
        ], (err, results) ->
            if err
                log.error "Error happened in perform", V_(err)

module.exports = Configurator
