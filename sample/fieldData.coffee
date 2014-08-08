class FieldData
    @createInstance: (field) ->
        switch field.Desc.Type
            when "STRING"
                new StringFieldData(field)
            when "INT32"
                new Int32FieldData(field)
            when "INT64"
                new Int64FieldData(field)
            when "UINT32"
                new UInt32FieldData(field)
            when "UINT64"
                new UInt64FieldData(field)
            when "DOUBLE"
                new DoubleFieldData(field)
            when "FLOAT"
                new FloatFieldData(field)
            when "BOOL"
                new BoolFieldData(field)
            when "BYTES"
                new BytesFieldData(field)
            else # "DATE", "TIME", "DATETIME", "NUMERIC", "INET4", "INET6", "MAC", "GEODATA"
                new StringFieldData(field)

    constructor: (field) ->
        @Type = field.Desc.Type
        @FieldName = field.Name
        @IsNull = new Array()

    # Call from not supported descendant classes only
    push: (value) =>
        @IsNull.push true

class StringFieldData extends FieldData
    constructor: (field) ->
        super
        @StringValue = new Array()

    push: (value) =>
        @StringValue.push value
        @IsNull.push (value == "")

    length: () =>
        @StringValue.length

    get: (index) =>
        if !@IsNull[index]
            @StringValue[index]
        else
            null

# Not yet supported - can only store null values
class Int32FieldData extends FieldData
    constructor: (field) ->
        super
        @Int32Value = new Array()

    push: (value) =>
        @Int32Value.push 0
        super

    length: () =>
        @Int32Value.length

    get: (index) =>
        if !@IsNull[index]
            @Int32Value[index]
        else
            null

# Not yet supported - can only store null values
class Int64FieldData extends FieldData
    constructor: (field) ->
        super
        @Int64Value = new Array()

    push: (value) =>
        @Int64Value.push 0
        super

    length: () =>
        @Int64Value.length

    get: (index) =>
        if !@IsNull[index]
            @Int64Value[index]
        else
            null

# Not yet supported - can only store null values
class UInt32FieldData extends FieldData
    constructor: (field) ->
        super
        @UInt32Value = new Array()

    push: (value) =>
        @UInt32Value.push 0
        super

    length: () =>
        @UInt32Value.length

    get: (index) =>
        if !@IsNull[index]
            @UInt32Value[index]
        else
            null

# Not yet supported - can only store null values
class UInt64FieldData extends FieldData
    constructor: (field) ->
        super
        @UInt64Value = new Array()

    push: (value) =>
        @UInt64Value.push 0
        super

    length: () =>
        @UInt64Value.length

    get: (index) =>
        if !@IsNull[index]
            @UInt64Value[index]
        else
            null

# Not yet supported - can only store null values
class DoubleFieldData extends FieldData
    constructor: (field) ->
        super
        @DoubleValue = new Array()

    push: (value) =>
        @DoubleValue.push 0
        super

    length: () =>
        @DoubleValue.length

    get: (index) =>
        if !@IsNull[index]
            @DoubleValue[index]
        else
            null

# Not yet supported - can only store null values
class FloatFieldData extends FieldData
    constructor: (field) ->
        super
        @FloatValue = new Array()

    push: (value) =>
        @FloatValue.push 0
        super

    length: () =>
        @FloatValue.length

    get: (index) =>
        if !@IsNull[index]
            @FloatValue[index]
        else
            null

# Not yet supported - can only store null values
class BoolFieldData extends FieldData
    constructor: (field) ->
        super
        @BoolValue = new Array()

    push: (value) =>
        @BoolValue.push false
        super

    length: () =>
        @BoolValue.length

    get: (index) =>
        if !@IsNull[index]
            @BoolValue[index]
        else
            null

# Not yet supported - can only store null values
class BytesFieldData extends FieldData
    constructor: (field) ->
        super
        @BytesValue = new Array()

    push: (value) =>
        @BytesValue.push 0
        super

    length: () =>
        @BytesValue.length

    get: (index) =>
        if !@IsNull[index]
            @BytesValue[index]
        else
            null

module.exports = FieldData
