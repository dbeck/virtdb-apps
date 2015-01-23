class FieldTypeDetector
    samplesNeeded: 0
    samples: null

    constructor: (@samplesNeeded)->
        @samples = {}

    enoughSamplesCollected: =>
        minLength = null
        for field of @samples
            minLength = @samples[field].Values.length if not minLength? or @samples[field].Values.length < minLength
        minLength >= @samplesNeeded

    addField = (samples, field, name) ->
        samples[field] =
            Name: name
            Values: []
        return

    addHeader: (dataArray) =>
        for field of dataArray
            if not @samples[field]?
                addField @samples, field, dataArray[field]

    addSample: (dataArray) =>
        for field of dataArray
            if not @samples[field]?
                addField @samples, field, field
            @samples[field].Values.push dataArray[field]

    fieldTypes = (value) ->
        possibleTypes =
            UINT32: false
            UINT64: false
            INT32: false
            INT64: false
            FLOAT: false
            DOUBLE: false
        if value != ''
            numberValue = Number value
        switch  typeof numberValue
            when 'number'
                if isFinite(numberValue)
                    if numberValue % 1 == 0
                        if numberValue > 0
                            if numberValue < 4294967295
                                possibleTypes['UINT32'] = true
                            possibleTypes['UINT64'] = true
                            if numberValue < 2147483647
                                possibleTypes['INT32'] = true
                            if numberValue < 9223372036854775807
                                possibleTypes['INT64'] = true
                        else
                            if numberValue > -2147483648
                                possibleTypes['INT32'] = true
                            if numberValue > -9223372036854775808
                                possibleTypes['INT64'] = true
                else
                    if numberValue.length < 7
                        possibleTypes['FLOAT'] = true
                    if numberValue.lenght <16
                        possibleTypes['DOUBLE'] = true
        return possibleTypes

    getFieldType: (name) =>
        for index of @samples
            field = @samples[index]
            if field.Name == name and field.Values.length > 0
                possibleTypes =
                    UINT32: true
                    UINT64: true
                    INT32: true
                    INT64: true
                    FLOAT: true
                    DOUBLE: true
                for value in field.Values
                    possibleFieldTypes = fieldTypes(value)
                    for type of possibleTypes
                        possibleTypes[type] = false if not possibleFieldTypes[type]
                for type of possibleTypes
                    return type if possibleTypes[type]
                return 'STRING'
        return null

module.exports = FieldTypeDetector
