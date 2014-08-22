CONST       = require("./config").Const
protocol    = require "./protocol"
log         = require 'loglevel'
pg          = require 'pg'
conString   = "postgres://localhost/vagrant"
require('source-map-support').install();

protocol.on CONST.DB_CONFIG.MESSAGE, (data) ->
    for table in data.Tables
        log.info table.Name, ": "
        # for field in table.Fields
        #     log.info field.Name, ": ", field.Desc.Type

    # if not server
    #     if extension
    #         drop extension
    #     create extensio
    #     create server
    # drop foreign table
    # create foreign table

    pg.connect conString, (err, client, done) ->
        if err
            log.error err
            return
        q_create_extension =
            text: "CREATE EXTENSION IF NOT EXISTS " + data.Type
            values: []

        client.query q_create_extension, (err, result) ->
            done()
            if err.code != '42710' # duplicate object
                log.error err
                return

            q_create_server =
                text: "CREATE SERVER " + data.Name + "_srv foreign data wrapper " + data.Type
                values: []

            client.query q_create_server, (err, result) ->
                done()
                if err.code != '42710' # duplicate object
                    log.error err
                    return

                for table in data.Tables
                    q_drop_table = "DROP FOREIGN TABLE IF EXISTS " + table.Name + " CASCADE"

                    client.query q_drop_table, (err, result) ->
                        if err
                            log.error err
                            return
                        q_create_table = "CREATE FOREIGN TABLE " + table.Name + "("
                        log.debug table.Fields[0].Name
                        for field in table.Fields
                            q_create_table += "\"" + field.Name + "\"" + " VARCHAR, "
                        q_create_table = q_create_table.substring(0, q_create_table.length - 2)
                        q_create_table += ") server " + data.Name + "_srv"
                        client.query q_create_table, (err, result) ->
                            if err
                                log.error err
                                return
                            log.debug result



            # rowString = ""
            # for columnName of result.rows[0]
            #     rowString += columnName + ", "
            # log.debug rowString
            # for row in result.rows
            #     rowString = ""
            #     for field of row
            #         rowString += row[field] + ", "
            #     log.debug rowString
            # return

# # Run fdw.sql
# psql <<< "DROP SERVER virtdb_srv CASCADE;"
# psql <<< "DROP EXTENSION \"virtdb_fdw\" CASCADE ;"
# psql <<< "CREATE EXTENSION \"virtdb_fdw\";"
# psql <<< "CREATE SERVER virtdb_srv foreign data wrapper virtdb_fdw;"
#
#
# psql <<< "DROP FOREIGN TABLE A CASCADE;"
# psql <<< "CREATE FOREIGN TABLE A ( \"INTA\" INTEGER , \"INTB\" INTEGER, \"VARCHARC\" VARCHAR(2)) server virtdb_srv;"
#
