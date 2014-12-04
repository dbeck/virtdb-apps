async  = require 'async'
log    = (require 'virtdb-connector').log
V_     = log.Variable

class PostgresConnection
    @queryTimeout: null

    # WE Expect pg to have the following interface:
    # pg.connect connectionString, callback(err, client, done)
    # pg.Client parametersObject
    # pg.cancel queryString
    # pg.query queryString, callback(err, result)
    pg: null

    postgres: null

    # The worker queue. We store tasks in this queue and perform them one at a time
    # this is needed as otherwise our queries would interfere with each other in the DB engine
    queue: []

    timeout: null
    working: false

    constructor: (@connectionString, @pg, @queryTimeout = 60000) ->

    Perform: (commands, args..., perform_done) =>
        @queue.push { commands: commands, payload: args, callback: perform_done }
        @working = true
        while @queue.length > 0
            current = @queue.shift()
            log.info "Starting new task. Queue length: ", V_(@queue.length)
            @_DoPerform current.commands, current.payload, (err, results) =>
                current.callback?(err, results)
        @working = false

    _DoPerform: (commands, args, perform_done) =>
        @pg.connect @connectionString, (err, client, done) =>
            if err
                log.error "Error while connecting to postgres server", V_(err)
                done(err)
                perform_done(err)
                return
            @postgres = client
            log.info "#of commands to be completed: ", V_(commands.length)
            err = null
            results = []
            async.series commands, (err, results) ->
                done(err)
                perform_done(err, results)
            , args

    Query: (queryString, callback, ignoreError = false, client = @pg) =>
        log.info "query", V_(queryString)
        timedOut = false
        timeout = setTimeout () =>
            timedOut = true
            log.info "Could not process query in time, cancelling", V_(queryString)
            newpg = new @pg.Client({ port: client.port, host: client.host})
            newpg.cancel queryString
            log.info "Cancel sent."
            callback(new Error("Query timed out"))
        , @queryTimeout
        @postgres.query queryString, (err, result) =>
            if not timedOut
                clearTimeout timeout
                if ignoreError
                    err = null
                if err
                    callback? err
                    return
                callback?(err, result)

module.exports = PostgresConnection
