extension String {
    /// Custom type to track value intent (quoted vs unquoted).
    enum ParsedValue {
        case bool(Bool)
        case int(Int)
        case quotedString(String)  // Originally had quotes
        case unquotedString(String)  // No quotes (e.g., HCL variable or number)
        case array([ParsedValue])
        case object([String: ParsedValue])
    }

    /// Parses the string into a typed value with quote intent.
    func parseValue() -> ParsedValue {
        let trimmedValue = trimmingCharacters(in: .whitespaces)

        if trimmedValue.lowercased() == "true" || trimmedValue.lowercased() == "false" {
            return .bool(trimmedValue.lowercased() == "true")
        } else if let intValue = Int(trimmedValue) {
            return .int(intValue)  // Unquoted number
        } else if trimmedValue.hasPrefix("[") && trimmedValue.hasSuffix("]") {
            let inner = String(trimmedValue.dropFirst().dropLast()).split(separator: ",")
            var array: [ParsedValue] = []
            for item in inner {
                let trimmedItem = item.trimmingCharacters(in: .whitespaces)
                array.append(trimmedItem.parseValue())
            }
            return .array(array)
        } else if trimmedValue.hasPrefix("{") && trimmedValue.hasSuffix("}") {
            let inner = String(trimmedValue.dropFirst().dropLast())
            return .object(parseNestedObject(inner))
        } else if trimmedValue.hasPrefix("\"") && trimmedValue.hasSuffix("\"") {
            let stripped = String(trimmedValue.dropFirst().dropLast())
            return .quotedString(stripped)  // Originally quoted
        } else if trimmedValue.contains(".") && !trimmedValue.hasPrefix("\"")
            && !trimmedValue.hasSuffix("\"")
        {
            return .unquotedString(trimmedValue)  // HCL variable reference
        } else {
            return .unquotedString(trimmedValue)  // Treat as unquoted string (e.g., number or variable)
        }
    }

    /// Helper to parse nested HCL-like objects into [String: ParsedValue].
    private func parseNestedObject(_ input: String) -> [String: ParsedValue] {
        var dict: [String: ParsedValue] = [:]
        var currentKey: String?
        var buffer = ""
        var braceCount = 0
        var bracketCount = 0

        for char in input {
            if char == "{" {
                braceCount += 1
                if braceCount == 1, currentKey != nil {
                    buffer = "{"
                } else {
                    buffer.append(char)
                }
            } else if char == "}" {
                braceCount -= 1
                if braceCount == 0, currentKey != nil {
                    let valueStr = buffer + "}"
                    dict[currentKey!] = valueStr.parseValue()
                    currentKey = nil
                    buffer = ""
                } else {
                    buffer.append(char)
                }
            } else if char == "[" {
                bracketCount += 1
                buffer.append(char)
            } else if char == "]" {
                bracketCount -= 1
                buffer.append(char)
            } else if char == "=", braceCount == 0, bracketCount == 0 {
                currentKey = buffer.trimmingCharacters(in: .whitespaces)
                buffer = ""
            } else if char == ",", braceCount == 0, bracketCount == 0 {
                if let key = currentKey, !buffer.isEmpty {
                    let trimmedValue = buffer.trimmingCharacters(in: .whitespaces)
                    dict[key] = trimmedValue.parseValue()
                    currentKey = nil
                    buffer = ""
                }
            } else {
                buffer.append(char)
            }
        }

        if let key = currentKey, !buffer.isEmpty {
            let trimmedValue = buffer.trimmingCharacters(in: .whitespaces)
            dict[key] = trimmedValue.parseValue()
        }

        return dict
    }
}
