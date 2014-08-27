Protocol = require "./protocol"
os = require 'os'

Date::yyyymmdd = () ->
    yyyy = @getFullYear().toString()
    mm = (@getMonth() + 1).toString() # getMonth() is zero-based
    dd = @getDate().toString()
    yyyy + ((if mm[1] then mm else "0" + mm[0])) + ((if dd[1] then dd else "0" + dd[0])) # padding

Date::hhmmss = () ->
    hh = @getHours().toString()
    mm = @getMinutes().toString()
    ss = @getSeconds().toString()
    hh + mm + ss

String::startsWith = (other) ->
    @substring(0, other.length) == other

Object.defineProperty global, "__stack",
    get: ->
        orig = Error.prepareStackTrace
        Error.prepareStackTrace = (_, stack) ->
            stack

        err = new Error
        Error.captureStackTrace err, arguments.callee
        stack = err.stack
        Error.prepareStackTrace = orig
        stack

Object.defineProperty global, "__line",
    get: ->
        __stack[3].getLineNumber()

Object.defineProperty global, "__file",
    get: ->
        name = __stack[3].getFileName()
        name.substring process.cwd().length, name.length

Object.defineProperty global, "__func",
    get: ->
        __stack[3].getFunctionName() or ""


class Diag
    @_startDate = null
    @_startTime = null
    @_random = null
    @_name = null

    @startDate: =>
        if not @_startDate?
            @_startDate = new Date().yyyymmdd()
        @_startDate

    @startTime: =>
        if not @_startTime?
            @_startTime = new Date().hhmmss()
        @_startTime

    @random: =>
        if not @_random?
            @_random = Math.floor(Math.random() * 100000000 + 1)
        @_random

    @process_name: =>
        if not @_name?
            for argument in process.argv
                if argument.startsWith "name="
                    @_name = argument.substring "name=".length, argument.length
        @_name

    @_log: (level, args) =>
        record =
            Process:
                StartDate: @startDate()
                StartTime: @startTime()
                Pid: process.pid
                Random: @random()
                NameSymbol: 4
                HostSymbol: 5
            Symbols: [
                SeqNo: 1
                Value: __file
            ,
                SeqNo: 2
                Value: __func
            ,
                SeqNo: 4
                Value: @process_name()
            ,
                SeqNo: 5
                Value: os.hostname()
            ]
            Headers: [
                SeqNo: 1
                FileNameSymbol: 1
                LineNumber: __line
                FunctionNameSymbol: 2
                Level: level
                LogStringSymbol: 0
                Parts: [
                    IsVariable: false
                    HasData: true
                    Type: 'STRING'
                ]
            ]
            Data: [
                HeaderSeqNo: 1
                ElapsedMicroSec: 50
                ThreadId: 0
                Values: [
                    Type: 'STRING'
                    StringValue: [
                        args[0]
                    ]
                    IsNull: [
                        false
                    ]
                ]
            ]

        Protocol.sendDiag record

    @info: (args...) =>
        @_log 'INFO', args


module.exports = Diag
