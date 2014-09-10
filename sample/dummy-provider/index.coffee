VirtDB = require 'virtdb-connector'
log = VirtDB.log
V = log.Variable

meta_data =
    Tables: [
            Name: "TestTables"
            Fields: [
                Name: "StringField"
                Desc:
                    Type: 'STRING'
            ,
                Name: "Int32Field"
                Desc:
                    Type: 'INT32'
            ,
                Name: "Int64Field"
                Desc:
                    Type: 'INT64'
            ,
                Name: "FloatField"
                Desc:
                    Type: 'FLOAT'
            ,
                Name: "NumericField"
                Desc:
                    Type: 'NUMERIC'
            ,
                Name: "DateField"
                Desc:
                    Type: 'DATE'
            ,
                Name: "TimeField"
                Desc:
                    Type: 'TIME'
            ]
        ]

data = [
    QueryId: 0
    Name: "StringField"
    Data:
        Type: 'STRING'
        StringValue: [
            'asd'
            'fdfd'
            'sdsdsds'
        ]
        IsNull: [
            false
            false
            false
        ]
    SeqNo: 0
    EndOfData: true
,
    QueryId: 0
    Name: "Int32Field"
    Data:
        Type: 'INT32'
        Int32Value: [
            1
            2
            3
        ]
        IsNull: [
            false
            false
            false
        ]
    SeqNo: 0
    EndOfData: true
,
    QueryId: 0
    Name: "Int64Field"
    Data:
        Type: 'INT64'
        Int64Value: [
            641
            642
            643
        ]
        IsNull: [
            false
            false
            false
        ]
    SeqNo: 0
    EndOfData: true
,
    QueryId: 0
    Name: "FloatField"
    Data:
        Type: 'FLOAT'
        FloatValue: [
            1.0
            2.12
            3.14
        ]
        IsNull: [
            false
            false
            false
        ]
    SeqNo: 0
    EndOfData: true
,
    QueryId: 0
    Name: "NumericField"
    Data:
        Type: 'NUMERIC'
        StringValue: [
            "1.34"
            "2.23"
            "3.5454"
        ]
        IsNull: [
            false
            false
            false
        ]
    SeqNo: 0
    EndOfData: true
,
    QueryId: 0
    Name: "DateField"
    Data:
        Type: 'DATE'
        StringValue: [
            "1979.07.14"
            "7/14/79"
            "2/9/2014"
        ]
        IsNull: [
            false
            false
            false
        ]
    SeqNo: 0
    EndOfData: true
,
    QueryId: 0
    Name: "TimeField"
    Data:
        Type: 'TIME'
        StringValue: [
            "11:12:23"
            "12:00"
            "23:59:23.22"
        ]
        IsNull: [
            false
            false
            false
        ]
    SeqNo: 0
    EndOfData: true
]

try
    virtdb = new VirtDB("dummy-provider", "tcp://localhost:65001")

    virtdb.onMetaDataRequest (request) ->
        log.info "Metadata request arrived: ", V(request.Name)
        virtdb.sendMetaData meta_data
        return

    virtdb.onQuery (query) ->
        log.info "Query arrived: ", V(query.QueryId)
        for column in data
            column.QueryId = query.QueryId
            log.debug "Sending data: ", V(column.Data.StringValue?)
            virtdb.sendColumn column

catch e
    virtdb?.close()
    console.log e

process.on "SIGINT", ->
    virtdb?.close()
    return
