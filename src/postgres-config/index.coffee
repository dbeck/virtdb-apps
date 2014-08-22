CONST       = require("./config").Const
ERROR       = require("./config").Error
protocol    = require "./protocol"
log         = require 'loglevel'
pg          = require 'pg'
async       = require 'async'
conString   = "postgres://localhost/vagrant"
require('source-map-support').install();

class Configurator
    postgres: null
    server_config: null
    done: null

    constructor: (@server_config) ->
        return

    Connect: (callback) =>
        pg.connect conString, (err, client, @done) =>
            if err
                callback err
                return
            @postgres = client
            callback()

    CreateExtension: (callback) =>
        q_create_extension =
            text: "CREATE EXTENSION IF NOT EXISTS " + @server_config.Type
            values: []

        @postgres.query q_create_extension, (err, result) =>
            @done()
            if err and err.code != ERROR.Duplicate_Object
                callback err
                return
            callback()

    CreateServer: (callback) =>
        q_create_server =
            text: "CREATE SERVER " + @server_config.Name + "_srv foreign data wrapper " + @server_config.Type
            values: []

        @postgres.query q_create_server, (err, result) =>
            @done()
            if err and err.code != ERROR.Duplicate_Object # duplicate object
                callback err
                return
            callback()

    DropTables: (callback) =>
        async.each @server_config.Tables, (table, tables_callback) =>
            q_drop_table = "DROP FOREIGN TABLE IF EXISTS " + table.Name + " CASCADE"

            @postgres.query q_drop_table, (err, result) =>
                @done()
                if err
                    tables_callback err
                    return
                tables_callback()
        , (err) =>
            log.debug "", @server_config.Tables.length, "tables dropped"
            callback(err)

    CreateTables: (callback) =>
        async.each @server_config.Tables, (table, tables_callback) =>
            q_create_table = "CREATE FOREIGN TABLE " + table.Name + "("
            for field in table.Fields
                q_create_table += "\"" + field.Name + "\"" + " VARCHAR, "
            q_create_table = q_create_table.substring(0, q_create_table.length - 2)
            q_create_table += ") server " + @server_config.Name + "_srv"
            @postgres.query q_create_table, (err, result) ->
                if err
                    tables_callback err
                    return
                tables_callback()
        , (err) =>
            log.debug "", @server_config.Tables.length, "tables created"
            callback(err)

    Perform: () =>
        async.series [
            @Connect,
            @CreateExtension,
            @CreateServer,
            @DropTables,
            @CreateTables
        ], (err, results) ->
            if err
                log.error err


protocol.on CONST.DB_CONFIG.MESSAGE, (server_config) ->
    new Configurator(server_config).Perform()
