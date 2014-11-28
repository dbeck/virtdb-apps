chai = require "chai"

PostgresConnection = require "../postgres-connection"
PGMock = require "./pg-mock"

chai.should()

badString = "badbadstring"
goodString = "ayeayeiamgood"

class CommandList
    @StaticOKCount = 0
    OKCount = 0
    @pgConnection = null

    constructor: () ->
        OKCount = 0

    @BadQuery: (callback) =>
        @pgConnection.Query badString, callback

    @GoodQuery: (callback) =>
        @pgConnection.Query goodString, callback

    @StaticOKCommand1: (callback) =>
        @StaticOKCount += 1
        callback()

    @StaticOKCommand2: (callback) =>
        @StaticOKCount += 1
        callback()

    OKCommand1: (callback) =>
        @OKCount += 1
        callback()

    OKCommand2: (callback) =>
        @OKCount += 1
        callback()

describe "Postgres connection", ->
    pg = new PGMock badString, goodString

    it "should report error when getting wrong connection string", ->
        error = ""
        pgConnection = new PostgresConnection badString, pg
        pgConnection.Perform [], (err) =>
            error = err
        error.should.not.equal("")

    it "should not report error when getting good connection string", ->
        error = ""
        pgConnection = new PostgresConnection goodString, pg
        pgConnection.Perform [], (err) =>
            if (err)
                error = err
        error.should.equal("")

    it "should call static commands", ->
        error = ""
        pgConnection = new PostgresConnection goodString, pg
        CommandList.pgConnection = pgConnection
        commands = [
            CommandList.StaticOKCommand1
            CommandList.StaticOKCommand2
        ]
        CommandList.StaticOKCount = 0
        pgConnection.Perform commands, (err) =>
            if (err)
                error = err
        error.should.equal("")
        CommandList.StaticOKCount.should.equal(2)

    it "should call non-static commands", ->
        error = ""
        pgConnection = new PostgresConnection goodString, pg
        CommandList.pgConnection = pgConnection
        commandList = new CommandList pgConnection

        commands = [
            commandList.OKCommand1
            commandList.OKCommand2
        ]
        commandList.OKCount = 0
        pgConnection.Perform commands, (err) =>
            if (err)
                error = err
        error.should.equal("")
        commandList.OKCount.should.equal(2)

    it "should fail with error if querying with bad string", ->
        error = ""
        pgConnection = new PostgresConnection goodString, pg
        CommandList.pgConnection = pgConnection

        commands = [
            CommandList.BadQuery
        ]
        pgConnection.Perform commands, (err) =>
            if (err)
                error = err
        error.should.not.equal("")

    it "should work if querying with good string", ->
        error = ""
        pgConnection = new PostgresConnection goodString, pg
        CommandList.pgConnection = pgConnection

        commands = [
            CommandList.GoodQuery
        ]
        pgConnection.Perform commands, (err) =>
            if (err)
                error = err
        error.should.equal("")
