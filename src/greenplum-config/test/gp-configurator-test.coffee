Configurator = require "../greenplum-configurator"
PostgresConnection = require "../postgres-connection"
PGMock = require "./pg-mock"

require 'chai'
expect = require('chai').expect

class GPConfigTestMock extends PGMock
    @queryCallCount: 0
    connect: (connectionString, callback) =>
        @queryCallCount = 0
        callback(null, this, () ->)

    query: (queryString, callback) =>
        if queryString == @badString
            callback(new Error("Query failed."))
            return
        if queryString.indexOf(";test1;") > 0
            callback(null, {
                    rows: [ {
                        location: 'test1;testSchema;testTable'
                    }]
                })
            return
        if queryString.indexOf("test2_srv") > 0
            @queryCallCount += 1
            callback()
            return
        @queryCallCount += 1
        callback(null, [])

describe "Greenplum configurator", ->
    pg = new GPConfigTestMock "bad", ""

    it "should work with empty config query", ->
        error = ""
        reply = {}
        configObject = {
            Postgres: {
            }
        }
        Configurator.getInstance().connect "", "Greenplum configurator test", configObject, pg
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
        configObject =
            Postgres:
                Extension:
                    Path: ""
        Configurator.getInstance().connect "", "Greenplum configurator test", configObject, pg
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
        configObject =
            Postgres:
                Extension:
                    Path: ""
        # Tables undefined
        error = ""
        Configurator.getInstance().connect "", "Greenplum configurator test", configObject, pg
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
        configObject =
            Postgres:
                Extension:
                    Path: ""

        error = ""
        Configurator.getInstance().connect "", "Greenplum configurator test", configObject, pg
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
        configObject =
            Postgres:
                Extension:
                    Path: ""

        error = ""
        Configurator.getInstance().connect "", "Greenplum configurator test", configObject, pg
        config = {
            Name: "test2"
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
        configObject =
            Postgres:
                Extension:
                    Path: ""
        Configurator.getInstance().connect "", "Greenplum configurator test", configObject, pg
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
        pg.queryCallCount.should.equal(7)
