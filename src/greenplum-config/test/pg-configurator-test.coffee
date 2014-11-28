Configurator = require "../postgres-configurator"
PostgresConnection = require "../postgres-connection"
PGMock = require "./pg-mock"

require 'chai'
expect = require('chai').expect

class PGConfigTestMock extends PGMock
    @queryCallCount: 0
    connect: (connectionString, callback) =>
        @queryCallCount = 0
        callback(null, null, () ->)

    Query: (queryString, callback) =>
        if queryString == @badString
            callback(new Error("Query failed."))
            return
        if queryString.indexOf("test1_srv") > 0
            callback(null, {
                    rows: [ {
                        option_name: 'schema'
                        schema_name: 'testSchema'
                        table_name: 'testTable'
                    }]
                })
            return
        if queryString.indexOf("test2_srv") > 0
            # console.log "query called test2", queryString
            @queryCallCount += 1
            callback()
            return
        # console.log "query called", queryString
        @queryCallCount += 1
        callback(null, [])

describe "Postgres configurator", ->
    pg = new PGConfigTestMock "bad", ""

    it "should work with empty config query", ->
        error = ""
        reply = {}
        configObject = {
            Postgres: {
            }
        }
        Configurator.getInstance().connect "", "Postgres configurator test", configObject, pg
        configQuery = {}
        Configurator.getInstance().queryConfig configQuery, (err, theReply) ->
            reply = theReply
            if err
                error = err
        error.should.not.equal("")
        expect(reply).to.be.undefined()
        pg.queryCallCount.should.equal(0)

    it "should be able to give back tables", ->
        error = ""
        reply = {}
        configObject = {
            Postgres: {
            }
        }
        Configurator.getInstance().connect "", "Postgres configurator test", configObject, pg
        configQuery = {
            Name: "test1"
        }
        Configurator.getInstance().queryConfig configQuery, (err, theReply) ->
            reply = theReply
            if err
                error = err
        error.should.equal("")
        reply.Servers.should.have.length(1)
        reply.Servers[0].Name.should.equal('test1')
        reply.Servers[0].Tables.should.have.length(1)
        reply.Servers[0].Tables[0].Name.should.equal('testTable')

    it "should survive empty config_data", ->
        reply = {}
        configObject = {
            Postgres: {
            }
        }
        # Tables undefined
        error = ""
        Configurator.getInstance().connect "", "Postgres configurator test", configObject, pg
        config = {
        }
        Configurator.getInstance().add config, (err) ->
            if err
                error = err

        error.should.not.equal("")
        expect(pg.queryCallCount).not.to.be.null()
        pg.queryCallCount.should.equal(0)

    it "should survive empty tables", ->
        reply = {}
        configObject = {
            Postgres: {
            }
        }

        error = ""
        Configurator.getInstance().connect "", "Postgres configurator test", configObject, pg
        config = {
            Tables: []
        }
        Configurator.getInstance().add config, (err) ->
            if err
                error = err

        error.should.not.equal("")
        expect(pg.queryCallCount).not.to.be.null()
        pg.queryCallCount.should.equal(0)

    it "should survive tables with empty fields", ->
        reply = {}
        configObject = {
            Postgres: {
            }
        }

        error = ""
        Configurator.getInstance().connect "", "Postgres configurator test", configObject, pg
        config = {
            Tables: [
                Name: "testtable"
            ]
        }
        Configurator.getInstance().add config, (err) ->
            if err
                error = err

        error.should.not.equal("")

    it "should create all needed artifacts with a correct config", ->
        error = ""
        reply = {}
        configObject = {
            Postgres: {
            }
        }
        Configurator.getInstance().connect "", "Postgres configurator test", configObject, pg
        config = {
            Name: "test2"
            Tables: [
                Name: "testtable"
                Fields: [
                    Name: "stringfield"
                    Desc:
                        Type: "STRING"
                ,
                    Name: "int32field"
                    Desc:
                        Type: "INT32"
                ]
            ]
        }
        Configurator.getInstance().add config, (err) ->
            if err
                error = err

        error.should.equal("")
        expect(pg.queryCallCount).not.to.be.null()
        pg.queryCallCount.should.equal(8)
