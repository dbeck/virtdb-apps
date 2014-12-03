# pg.connect connectionString, callback(err, client, done)
# pg.Client parametersObject
# pg.cancel queryString
# pg.query queryString, callback(err, result)
class PGMock
    queryCallCount = 0
    constructor: (@badString, @goodString) ->
        @queryCallCount = 0

    connect: (connectionString, callback) =>
        if (connectionString == @badString)
            callback(new Error("Can't connect."), null, () ->)
            return
        if (connectionString == @goodString)
            callback(null, this, () ->)
            return
        return

    Client: (properties) =>
        return new PGMock()

    cancel: (queryString) =>

    query: (queryString, callback) =>
        if (queryString == @badString)
            callback(new Error("Query failed."))
            return
        @queryCallCount += 1
        callback()

module.exports = PGMock
