exports.dumpExpression = (expression, indent) =>
    console.log indent, "Operand:", expression.Operand
    if expression.Composite
        console.log indent, "Composite:"
        indent += "    "
        dumpExpression expression.Composite.Left, indent
        dumpExpression expression.Composite.Right, indent
    if expression.Simple
        console.log indent, "Simple:"
        indent += "  "
        console.log indent, "Variable: ", expression.Simple.Variable
        console.log indent, "Value: ", expression.Simple.Value

exports.dumpQuery = (query) =>
    console.log "Query:"
    indent = "  "
    console.log indent, "QueryId:", query.QueryId
    console.log indent, "Table:", query.Table
    for filter in query.Filter
        console.log  indent, "Filter:"
        exports.dumpExpression filter, indent + "  "
    if query.Fields.length > 0
        console.log indent, "Columns:"
    for field in query.Fields
        console.log indent + "  ", field
    if query.Limit
        console.log indent, "Limit: ", query.Limit
