Protocol = require "./protocol"
os = require 'os'

class Variable
    constructor: (@content) ->

    toString: () ->
        @content

Date::yyyymmdd = () ->
    yyyy = @getFullYear().toString()
    mm = (@getMonth() + 1).toString() # getMonth() is zero-based
    dd = @getDate().toString()
    yyyy + ((if mm[1] then mm else "0" + mm[0])) + ((if dd[1] then dd else "0" + dd[0])) # padding

Date::hhmmss = () ->
    hh = ('0'+@getHours().toString()).slice(-2)
    mm = ('0'+@getMinutes().toString()).slice(-2)
    ss = ('0'+@getSeconds().toString()).slice(-2)
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
    @_startHR = null
    @_startDate = null
    @_startTime = null
    @_random = null
    @_name = null
    @_symbols = {}
    @_newSymbols = []
    @_headers = {}
    @_newHeaders = []

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


    @_getProcessInfo: () =>
        Process =
            StartDate: @startDate()
            StartTime: @startTime()
            Pid: process.pid
            Random: @random()
            NameSymbol: @_getSymbolSeqNo @process_name()
            HostSymbol: @_getSymbolSeqNo os.hostname()
        return Process

    @_getNewSymbols: () =>
        Symbols = []
        for symbol in @_newSymbols
            Symbols.push symbol
        @_newSymbols = []
        return Symbols

    @_getNewHeaders: () =>
        Headers = []
        for header in @_newHeaders
            Headers.push header
        @_newHeaders = []
        return Headers

    @_getSymbolSeqNo: (symbolValue) =>
        if symbolValue not of @_symbols
            @_symbols[symbolValue] = Object.keys(@_symbols).length
            @_newSymbols.push
                SeqNo: @_symbols[symbolValue]
                Value: symbolValue
        return @_symbols[symbolValue]

    @_getHeaderSeqNo: (file, func, line, level, args) =>
        key = '' + file + func + line + level + args.length
        if key not of @_headers
            @_headers[key] =
                SeqNo: Object.keys(@_headers).length
                FileNameSymbol: @_getSymbolSeqNo file
                LineNumber: line
                FunctionNameSymbol: @_getSymbolSeqNo func
                Level: level
                LogStringSymbol: 0
                Parts: []
            for argument in args
                switch typeof argument
                    when 'object'
                        @_headers[key].Parts.push
                            IsVariable: true
                            HasData: true
                            Type: 'STRING'
                    else
                        @_headers[key].Parts.push
                            IsVariable: false
                            HasData: false
                            Type: 'STRING'
                            PartSymbol: @_getSymbolSeqNo argument
            @_newHeaders.push @_headers[key]
        return @_headers[key].SeqNo

    @_value: (argument) ->
        switch  typeof argument
            when 'string'
                ret =
                    Type: 'STRING'
                    StringValue: [
                        argument
                    ]
                    IsNull: [
                        false
                    ]
            when 'number'
                if not isFinite(argument)
                    ret =
                        Type: 'STRING'
                        StringValue: [
                            argument
                        ]
                        IsNull: [
                            false
                        ]
                else if argument % 1 == 0
                    ret =
                        Type: 'INT64'
                        Int64Value: [
                            argument
                        ]
                        IsNull: [
                            false
                        ]
                else
                    ret =
                        Type: 'DOUBLE'
                        DoubleValue: [
                            argument
                        ]
                        IsNull: [
                            false
                        ]
            else
                ret =
                    Type: 'STRING'
                    StringValue: [
                        argument.toString()
                    ]
                    IsNull: [
                        false
                    ]

    @_ellapsedMicrosec: () =>
        if not @_startHR?
            @_startHR = process.hrtime()
        ellapsed = process.hrtime(@_startHR)
        return (ellapsed[0] * 1e9 + ellapsed[1]) / 1000

    @_log: (level, args) =>
        console.time "log"
        record = {}
        record.Process = @_getProcessInfo()
        record.Data = [
                HeaderSeqNo: @_getHeaderSeqNo(__file, __func, __line, level, args)
                ElapsedMicroSec: @_ellapsedMicrosec()
                ThreadId: 0
                Values: []
            ]
        for argument in args
            type = typeof(argument)
            switch  type
                when 'object'
                    record.Data[0].Values.push @_value(argument.content)

        record.Symbols = @_getNewSymbols()
        record.Headers = @_getNewHeaders()

        Protocol.sendDiag record
        console.timeEnd "log"


class Log
    @levels =
        SILENT: 'silent'
        TRACE: 'trace'
        DEBUG: 'debug'
        INFO: 'info'
        WARN: 'warn'
        ERROR: 'error'

    @level = 'trace'

    @trace: (args...) ->
        if @level in ['trace']
            Diag._log 'SIMPLE_TRACE', args

    @debug: (args...) ->
        if @level in ['trace', 'debug']
            Diag._log 'SIMPLE_TRACE', args

    @info: (args...) ->
        if @level in ['trace', 'debug', 'info']
            Diag._log 'INFO', args

    @warn: (args...) ->
        if @level in ['trace', 'debug', 'info', 'warn']
            Diag._log 'INFO', args

    @error: (args...) ->
        if @level in ['trace', 'debug', 'info', 'warn', 'error']
            Diag._log 'ERROR', args

    @setLevel: (level) =>
        @level = level.toLowerCase?()

    @enableAll: () =>
        @setLevel @levels.TRACE

    @disableAll: () =>
        @setLevel @levels.SILENT

    @Variable = (param) ->
        new Variable(param)


module.exports = Log
