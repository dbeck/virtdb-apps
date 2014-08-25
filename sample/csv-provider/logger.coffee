exports.dumpExpression = (expression, indent) ->
    ret = ""
    ret += indent + "Operand: " + expression.Operand + "\n"
    if expression.Composite
        ret += indent + "Composite:" + "\n"
        indent += "    "
        dumpExpression expression.Composite.Left, indent
        dumpExpression expression.Composite.Right, indent
    if expression.Simple
        ret += indent + "Simple:" + "\n"
        indent += "  "
        ret += indent + "Variable: " + expression.Simple.Variable + "\n"
        ret += indent + "Value: " + expression.Simple.Value + "\n"

exports.dumpQuery = (query) ->
    ret = ""
    ret += "Query:" + "\n"
    indent = "  "
    ret += indent + "QueryId: " + query.QueryId + "\n"
    ret += indent + "Table: " + query.Table + "\n"
    for filter in query.Filter
        ret +=  indent + "Filter:" + "\n"
        ret += exports.dumpExpression filter, indent + "  "
    if query.Fields.length > 0
        ret += indent + "Columns:" + "\n"
    for field in query.Fields
        ret += indent + "  " + JSON.stringify(field) + "\n"
    if query.Limit
        ret += indent + "Limit: " + query.Limit + "\n"
    ret
