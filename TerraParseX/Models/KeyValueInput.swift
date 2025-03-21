import Foundation

struct KeyValueInput {
    let key: String
    let value: String.ParsedValue  // Now using the custom type
    let action: String

    func formattedValue() -> String {
        formatValue(value, indentLevel: 0)
    }

    /// Formats a value with proper indentation and order.
    private func formatValue(_ value: String.ParsedValue, indentLevel: Int) -> String {
        let indent = String(repeating: "  ", count: indentLevel)

        switch value {
        case let .bool(boolValue):
            return "\(indent)\(boolValue ? "true" : "false")"
        case let .int(intValue):
            return "\(indent)\(intValue)"
        case let .quotedString(stringValue):
            return "\(indent)\"\(stringValue)\""
        case let .unquotedString(stringValue):
            return "\(indent)\(stringValue)"
        case let .array(arrayValue):
            let items = arrayValue.map { formatValue($0, indentLevel: 0) }
            return "\(indent)[\(items.joined(separator: ", "))]"
        case let .object(dictValue):
            let items = dictValue.map { k, v in
                let formattedVal = formatValue(v, indentLevel: indentLevel + 1)
                return "\(indent)  \(k) = \(formattedVal.trimmingCharacters(in: .whitespaces))"
            }
            return "\(indent){\n\(items.joined(separator: ",\n"))\n\(indent)}"
        }
    }
}
