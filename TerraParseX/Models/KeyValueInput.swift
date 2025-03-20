import Foundation

struct KeyValueInput {
    var key: String
    var value: Any

    // Formats the value as an HCL-compatible string.
    func formattedValue() -> String {
        switch value {
        case let boolValue as Bool:
            return boolValue ? "true" : "false"
        case let intValue as Int:
            return "\(intValue)"
        case let stringValue as String:
            return "\"\(stringValue)\"" // Strings are quoted
        case let arrayValue as [Any]:
            let formattedArray = arrayValue.map { v in
                if let s = v as? String { return "\"\(s)\"" }
                if let b = v as? Bool { return b ? "true" : "false" }
                if let i = v as? Int { return "\(i)" }
                return "\(v)" // Fallback
            }
            return "[\(formattedArray.joined(separator: ", "))]"
        case let dictValue as [String: Any]:
            let formattedDict = dictValue.map { k, v in
                let valStr: String
                if let s = v as? String {
                    valStr = "\"\(s)\""
                } else if let b = v as? Bool {
                    valStr = b ? "true" : "false"
                } else if let i = v as? Int {
                    valStr = "\(i)"
                } else {
                    valStr = "\(v)"
                }
                return "\(k) = \(valStr)"
            }
            return "{\n  \(formattedDict.joined(separator: "\n  "))\n}"
        default:
            return "\(value)" // Fallback for other types (e.g., floats)
        }
    }
}
