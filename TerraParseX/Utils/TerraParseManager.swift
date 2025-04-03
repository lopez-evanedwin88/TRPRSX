import Foundation

class TerraParseManager {
    static let shared = TerraParseManager()

    private init() {}

    /// Finds all `terragrunt.hcl` files in the given directory.
    func findTerragruntFiles(in directoryPath: String) -> [String] {
        let fileManager = FileManager.default
        var terragruntFiles: [String] = []

        let directoryURL = URL(fileURLWithPath: directoryPath)

        guard
            let enumerator = fileManager.enumerator(
                at: directoryURL, includingPropertiesForKeys: nil
            )
        else {
            print("Failed to create enumerator for directory: \(directoryPath)")
            return []
        }

        for case let fileURL as URL in enumerator {
            if fileURL.lastPathComponent == "terragrunt.hcl" {
                terragruntFiles.append(fileURL.path)
            }
        }
        return terragruntFiles
    }

    /// Adds or updates key-value pairs in the specified HCL files using hcledit.
    func submitChanges(
        to files: [String], keyValuePairs: [KeyValueInput], operationModalData: OperationModalData,
        delegate: OperationModalDelegate
    ) {
        do {
            try HCLTool.hcledit.validate()
        } catch {
            print("Error: \(error)")
            return
        }

        for pair in keyValuePairs {
            let keyPath = pair.key // e.g., "inputs.nested.key"

            if keyPath.contains(".") { // Validation if not root-key
                print("classic root key")
                composeHCLConfiguration(
                    files: files, keyValuePairs: keyValuePairs,
                    operationModalData: operationModalData,
                    delegate: delegate
                )
            } else {
                print("custom root key")
                composeCustomConfigurationHCL(
                    files: files, keyValuePairs: keyValuePairs, inputKey: keyPath,
                    operationModalData: operationModalData,
                    delegate: delegate
                )
            }
        }
    }

    /// A compose function that could be used for editing HCL files
    /// This function implements 2-levels of nested key-value pairs
    /// Which was the limitation of hcledit tool
    func composeHCLConfiguration(
        files: [String], keyValuePairs: [KeyValueInput], operationModalData: OperationModalData,
        delegate: OperationModalDelegate
    ) {
        runProcessHCLComposeInBackground(
            files: files,
            keyValuePairs: keyValuePairs,
            onStart: {
                operationModalData.isLoading = true
                operationModalData.statusMessage = "Processing..."
            },
            onProcess: { message in
                operationModalData.statusMessage = message
            },
            onComplete: {
                operationModalData.isLoading = false
                delegate.openWindow(id: Routes.Preview.rawValue)
            }
        )
    }

    /// A compose function that is wrapped in a background task
    func runProcessHCLComposeInBackground(
        files: [String],
        keyValuePairs: [KeyValueInput],
        onStart: @escaping () -> Void,
        onProcess: @escaping (String) -> Void,
        onComplete: @escaping () -> Void
    ) {
        onStart() // Trigger loading state

        Task.detached(priority: .userInitiated) {
            for file in files {
                for pair in keyValuePairs {
                    let hcleditPath: String = HCLTool.hcledit.executableURL!
                    let keyPath = pair.key // e.g., "inputs.nested.key"
                    let valueStr = pair.formattedValue()

                    let process = Process()
                    let pipe = Pipe()

                    process.executableURL = URL(fileURLWithPath: hcleditPath)

                    // Set hcledit command based on action
                    switch pair.action.lowercased() {
                    case Operations.Add.rawValue:
                        process.arguments = [
                            "attribute", "append",
                            keyPath, valueStr,
                            "-f", file, "-u", // -f for file input, -u for in-place update
                        ]
                    case Operations.Modify.rawValue:
                        process.arguments = [
                            "attribute", "set",
                            keyPath, valueStr,
                            "-f", file, "-u",
                        ]
                    case Operations.Delete.rawValue:
                        process.arguments = [
                            "attribute", "rm",
                            keyPath,
                            "-f", file, "-u",
                        ]
                    default:
                        await MainActor.run {
                            onProcess("Unknown action '\(pair.action)' for \(keyPath) in \(file)")
                        }
                        return
                    }

                    process.standardOutput = pipe
                    process.standardError = pipe

                    do {
                        try process.run()
                        process.waitUntilExit()

                        let data = pipe.fileHandleForReading.readDataToEndOfFile()
                        if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                            print("hcledit output for \(file): \(output)")
                        }

                        let message: String
                        if process.terminationStatus == 0 {
                            message =
                                "Successfully \(pair.action)ed \(keyPath) in \(file) \(pair.action == "delete" ? "" : "to \(valueStr)")"
                            print(message)
                        } else {
                            message =
                                "Failed with status \(process.terminationStatus) for \(keyPath) in \(file)"
                            print(message)
                        }

                        await MainActor.run {
                            onProcess(message)
                        }
                    } catch {
                        let errorMessage =
                            "Error running hcledit on \(file) for \(keyPath): \(error.localizedDescription)"
                        print(errorMessage)
                        await MainActor.run {
                            onProcess(errorMessage)
                        }
                    }
                }
            }
            await MainActor.run {
                onComplete()
            }
        }
    }

    /// A custom compose function that will be used for editing HCL files if attribute type config
    /// This will only work for root level key-value pairs
    func composeCustomConfigurationHCL(
        files: [String], keyValuePairs: [KeyValueInput],
        inputKey: String,
        operationModalData: OperationModalData,
        delegate: OperationModalDelegate
    ) {
        // Validate tools
        do {
            try HCLTool.hcl2json.validate()
        } catch {
            print("Error: \(error)")
        }

        guard let hcleditURL = HCLTool.hcledit.executableURL else {
            print("Error: hcledit executable URL is nil")
            return
        }

        // Run hcledit
        runProcessCustomHCLComposeInBackground(
            files: files,
            keyValuePairs: keyValuePairs,
            inputKey: inputKey,
            hcleditURL: hcleditURL,
            operationModalData: operationModalData,
            delegate: delegate,
            onStart: {
                operationModalData.isLoading = true
                operationModalData.statusMessage = "Processing using custom..."
            },
            onProcess: { message in
                operationModalData.statusMessage = message
            },
            onComplete: {
                operationModalData.isLoading = false
                delegate.openWindow(id: Routes.Preview.rawValue)
            }
        )
    }

    func runProcessCustomHCLComposeInBackground(
        files: [String],
        keyValuePairs: [KeyValueInput],
        inputKey: String,
        hcleditURL: String,
        operationModalData _: OperationModalData,
        delegate _: OperationModalDelegate,
        onStart: @escaping () -> Void,
        onProcess: @escaping (String) -> Void,
        onComplete: @escaping () -> Void
    ) {
        onStart() // Trigger loading state

        Task.detached(priority: .userInitiated) {
            for file in files {
                let hcleditProcess = Process()
                let hcleditPipe = Pipe()

                hcleditProcess.executableURL = URL(fileURLWithPath: hcleditURL)
                hcleditProcess.arguments =
                    HCLEditCommand.attributeGet(key: inputKey, file: file).arguments
                hcleditProcess.standardOutput = hcleditPipe
                hcleditProcess.standardError = hcleditPipe

                let hcl2jsonProcess = Process()
                let hcl2jsonPipe = Pipe()
                let hcl2jsonInputPipe = Pipe() // Pipe for hcl2json stdin

                guard let hcl2jsonURL = HCLTool.hcl2json.executableURL else {
                    print("Error: hcl2json executable URL is nil")
                    continue
                }
                hcl2jsonProcess.executableURL = URL(fileURLWithPath: hcl2jsonURL)
                hcl2jsonProcess.standardInput = hcl2jsonInputPipe
                hcl2jsonProcess.standardOutput = hcl2jsonPipe
                hcl2jsonProcess.standardError = hcl2jsonPipe

                do {
                    try hcleditProcess.run()
                    hcleditProcess.waitUntilExit()

                    let hclData = hcleditPipe.fileHandleForReading.readDataToEndOfFile()
                    guard
                        let hclString = String(data: hclData, encoding: .utf8)?.trimmingCharacters(
                            in: .whitespacesAndNewlines),
                        !hclString.isEmpty
                    else {
                        print("\(file): No HCL output from hcledit for '\(inputKey)'")
                        continue
                    }

                    // Wrap root key with `=` e.g. "inputs ="
                    let wrappedHCL = "\(inputKey) = \(hclString)"
                    // Pipe wrappedHCL to hcl2json stdin
                    let inputHandle = hcl2jsonInputPipe.fileHandleForWriting
                    if let wrappedData = wrappedHCL.data(using: .utf8) {
                        inputHandle.write(wrappedData)
                    }
                    inputHandle.closeFile() // Signal EOF to hcl2json

                    try hcl2jsonProcess.run()
                    hcleditProcess.waitUntilExit()

                    var configDict: [String: Any]
                    let jsonData = hcl2jsonPipe.fileHandleForReading.readDataToEndOfFile()
                    guard
                        let jsonString = String(data: jsonData, encoding: .utf8)?
                        .trimmingCharacters(
                            in: .whitespacesAndNewlines),
                        !jsonString.isEmpty
                    else {
                        print("\(file): No JSON output from hcl2json for '\(inputKey)'")
                        continue
                    }
                    if let jsonDataConverted = jsonString.data(using: .utf8), // Convert back to Data
                       let json = try JSONSerialization.jsonObject(with: jsonDataConverted)
                       as? [String: Any]
                    {
                        configDict = json
                    } else {
                        print("\(file): JSON is not a [String: Any]: \(jsonString)")
                        continue
                    }

                    for pair in keyValuePairs {
                        let keyPath = pair.key // e.g., "inputs.nested.key"
                        let valueStr = pair.formattedValue()

                        guard let hclData = valueStr.data(using: .utf8) else {
                            print("\(file): Failed to convert valueStr to data: \(valueStr)")
                            continue
                        }

                        switch pair.action.lowercased() {
                        case Operations.Add.rawValue, Operations.Modify.rawValue:
                            let jsonData = try hclToJSON(hclData: hclData)
                            let jsonObject =
                                try JSONSerialization.jsonObject(with: jsonData)
                                    as? [String: Any]
                            var inputsDict = (configDict[inputKey] as? [String: Any]) ?? [:]
                            for (key, value) in jsonObject! {
                                inputsDict[key] = value
                            }
                            configDict[inputKey] = inputsDict
                        case Operations.Delete.rawValue:
                            let components = keyPath.split(separator: ".").map(String.init)
                            if components.count == 1 {
                                configDict.removeValue(forKey: keyPath)
                            } else if components.count == 2 {
                                let rootKey = components[0]
                                let nestedKey = components[1]
                                if var inputsDict = configDict[rootKey] as? [String: Any] {
                                    inputsDict.removeValue(forKey: nestedKey)
                                    if inputsDict.isEmpty {
                                        configDict.removeValue(forKey: rootKey)
                                    } else {
                                        configDict[rootKey] = inputsDict
                                    }
                                }
                            } else {
                                print("\(file): Unsupported nested depth for delete: \(keyPath)")
                                continue
                            }
                        default:
                            print("Unknown action '\(pair.action)' for \(pair.key) in \(file)")
                            continue
                        }
                    }

                    let theJSONData = try? JSONSerialization.data(
                        withJSONObject: configDict as Any, options: .prettyPrinted
                    )
                    let data = String(data: theJSONData!, encoding: .utf8)!
                    // if DEBUG working jqFilter
                    // let jqFilter = """
                    // .inputs | to_entries | map("\\(.key) = " + (if .value | type == \"string\" then (if .value | test(\"^\\\\$\\\\{.*\\\\}$\") then .value else @json end) else (.value | tostring) end)) | join(", ")
                    // """
                    // A jqFilter that recursively wraps values to hcl-format
                    let jqFilter = """
                    def to_hcl:
                        if type == \"object\" then
                            "{\n" + (to_entries | map("\\(.key) = \\(.value | to_hcl)") | join(",\n")) + "\n}"
                        elif type == \"array\" then
                            "[\n" + (map(to_hcl) | join(",\n")) + "\n]"
                        elif type == \"string\" and test(\"^\\\\$\\\\{.*\\\\}$\") then
                            .[2:-1]
                        elif type == \"string\" then
                            @json
                        else
                            tostring
                        end;
                    .\(inputKey) | to_hcl
                    """

                    if let hclOutput = jsonToHcl(
                        jsonInput: data,
                        jqFilter: jqFilter,
                        inputKey: inputKey
                    ) {
                        let process = Process()
                        let pipe = Pipe()

                        process.executableURL = URL(fileURLWithPath: HCLTool.hcledit.executableURL!)
                        process.arguments = [
                            "attribute", "append",
                            inputKey,
                            hclOutput.replacingOccurrences(of: "\(inputKey) = ", with: ""),
                            "-f", file, "-u", // -f for file input, -u for in-place update
                        ]

                        process.standardOutput = pipe
                        process.standardError = pipe
                        try process.run()
                        process.waitUntilExit()

                        let message: String
                        if process.terminationStatus == 0 {
                            message =
                                "Successfully \(keyValuePairs.first!.action)ed \(inputKey) in \(file) "
                            print(message)
                        } else {
                            message =
                                "Failed with status \(process.terminationStatus) for \(inputKey) in \(file)"
                            print(message)
                        }

                        await MainActor.run {
                            onProcess(message)
                        }
                    }
                } catch {
                    let message: String
                    message = "Error processing \(file): \(error)"
                    await MainActor.run {
                        onProcess(message)
                        // onComplete()
                    }
                }
            }
            await MainActor.run {
                onComplete()
            }
        }
    }

    /// For debugging: Reads and prints the file content.
    private func readFile(_ filePath: String) -> String {
        do {
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            print("Content of \(filePath):\n\(content)")
            return content
        } catch {
            print("Error reading file \(filePath): \(error)")
            return ""
        }
    }

    /// Reads the file content and returns an AttributedString with modified keys highlighted.
    func displayFileContent(_ filePath: String, modifiedKeys: [String]) -> AttributedString {
        do {
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            var attributedString = AttributedString(content)

            // Split content into lines for easier processing
            let lines = content.components(separatedBy: .newlines)

            for line in lines {
                for key in modifiedKeys {
                    // Check if the line contains the key (e.g., "inputs.count" or just "count")
                    if line.contains(key) || line.contains(key.split(separator: ".").last ?? "") {
                        // Find the range of the entire line in the content
                        if let range = content.range(of: line) {
                            let nsRange = NSRange(range, in: content)
                            let attrRange = Range(nsRange, in: attributedString)!
                            attributedString[attrRange].foregroundColor = .blue
                            attributedString[attrRange].font = .system(.body, design: .monospaced)
                                .bold()
                        }
                    }
                }
            }

            return attributedString
        } catch {
            print("Error reading file \(filePath): \(error)")
            return AttributedString("Error loading file content.")
        }
    }
}

func jsonToHcl(jsonInput: String, jqFilter: String, inputKey: String = "") -> String? {
    let jqProcess = Process()
    let hclProcess = Process()

    let jqPipe = Pipe() // jq output -> hcledit input
    let outputPipe = Pipe() // Final output
    let jqInputPipe = Pipe() // Pipe for jq stdin
    let hclInputPipe = Pipe() // Pipe for hcledit stdin

    // Configure jq -r "*filter"
    jqProcess.executableURL = URL(fileURLWithPath: HCLTool.jq.executableURL!)
    jqProcess.arguments = HCLEditCommand.jq(filter: jqFilter).arguments
    jqProcess.standardInput = jqInputPipe
    jqProcess.standardOutput = jqPipe

    // Configure hcledit fmt
    hclProcess.executableURL = URL(fileURLWithPath: HCLTool.hcledit.executableURL!)
    hclProcess.arguments = HCLEditCommand.fmt.arguments
    hclProcess.standardInput = hclInputPipe
    hclProcess.standardOutput = outputPipe

    do {
        try jqProcess.run()

        let jqInputHandle = jqInputPipe.fileHandleForWriting
        if let wrappedData = jsonInput.data(using: .utf8) {
            jqInputHandle.write(wrappedData)
        }
        jqInputHandle.closeFile() // Signal EOF to jq
        jqProcess.waitUntilExit()

        let data = jqPipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8), !output.isEmpty else {
            throw NSError(
                domain: "JQProcess", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "No output from jq"]
            )
        }

        try hclProcess.run()
        let hclfmtHandle = hclInputPipe.fileHandleForWriting
        let wrappedIt = "\(inputKey) = \(output)"
        if let wrappedData = wrappedIt.data(using: .utf8) {
            hclfmtHandle.write(wrappedData)
        }

        hclfmtHandle.closeFile()
        hclProcess.waitUntilExit()

        let hcleditData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: hcleditData, encoding: .utf8), !output.isEmpty else {
            throw NSError(
                domain: "JQProcess", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "No output from hcledit"]
            )
        }
        return output
    } catch {
        print("Error running jq and hcledit: \(error)")
        return nil
    }
}

// Helper to simulate hcl2json (replace with actual hcl2json call if needed)
func hclToJSON(hclData: Data) throws -> Data {
    guard
        let hclString = String(data: hclData, encoding: .utf8)?
        .replacingOccurrences(of: "\n", with: "")
        .replacingOccurrences(of: "\r", with: "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
    else {
        throw NSError(
            domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid HCL data"]
        )
    }

    // Cleans a string by removing escaped quotes and wrapping unquoted values in ${}
    func cleanString(_ value: String) -> String {
        var trimmed = value.trimmingCharacters(in: .whitespaces)

        // Remove escaped quotes (\") from strings
        if trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"") {
            trimmed = String(trimmed.dropFirst().dropLast()) // Remove surrounding quotes
        } else {
            // Wrap unquoted values in ${}, excluding numbers & booleans
            if !trimmed.isEmpty, !isBooleanOrNumber(trimmed) {
                trimmed = "${\(trimmed)}"
            }
        }
        return trimmed
    }

    // Checks if a value is a number or boolean
    func isBooleanOrNumber(_ value: String) -> Bool {
        return value == "true" || value == "false" || Int(value) != nil
    }

    // Parses arrays from HCL
    func parseArray(_ input: String) -> [Any] {
        let items =
            input
                .dropFirst().dropLast() // Remove surrounding brackets []
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }

        return items.map(parseScalarValue)
    }

    // Parses scalar values (boolean, number, string)
    func parseScalarValue(_ value: String) -> Any {
        if value == "true" { return true }
        if value == "false" { return false }
        if let num = Int(value) { return num }
        return cleanString(value)
    }

    // Recursively parses HCL into a dictionary
    func parseHCL(_ input: String) throws -> [String: Any] {
        guard input.hasPrefix("{") && input.hasSuffix("}") else {
            throw NSError(
                domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "HCL must be an object"]
            )
        }

        var result: [String: Any] = [:]
        let content = input.dropFirst().dropLast().trimmingCharacters(in: .whitespaces)

        let pairs = content.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        for pair in pairs {
            let parts = pair.split(separator: "=", maxSplits: 1).map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            guard parts.count == 2 else {
                throw NSError(
                    domain: "", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid HCL pair: \(pair)"]
                )
            }

            let key = parts[0]
            let valueStr = parts[1]

            if valueStr.hasPrefix("{") && valueStr.hasSuffix("}") {
                result[key] = try parseHCL(valueStr) // Nested object
            } else if valueStr.hasPrefix("[") && valueStr.hasSuffix("]") {
                result[key] = parseArray(valueStr) // Array
            } else {
                result[key] = parseScalarValue(valueStr) // Scalar value
            }
        }
        return result
    }

    // Convert parsed HCL to JSON
    let dict = try parseHCL(hclString)
    return try JSONSerialization.data(withJSONObject: dict, options: [])
}

func getEmbeddedHcleditPath() -> String? {
    guard let path = Bundle.main.path(forResource: "hcledit", ofType: nil, inDirectory: "Libs")
    else {
        print("hcledit not found in Libs/")
        return nil
    }
    // Ensure it's executable
    let fileManager = FileManager.default
    if !fileManager.isExecutableFile(atPath: path) {
        do {
            try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)
        } catch {
            print("Failed to make hcledit executable: \(error)")
            return nil
        }
    }
    return path
}

func getEmbeddedHcl2jsonPath() -> String? {
    guard let path = Bundle.main.path(forResource: "hcl2json", ofType: nil, inDirectory: "Libs")
    else {
        print("hcl2json not found in Libs/")
        return nil
    }
    let fileManager = FileManager.default
    if !fileManager.isExecutableFile(atPath: path) {
        do {
            try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)
        } catch {
            print("Failed to make hcl2json executable: \(error)")
            return nil
        }
    }
    return path
}

func getEmbeddedjqPath() -> String? {
    guard let path = Bundle.main.path(forResource: "jq", ofType: nil, inDirectory: "Libs")
    else {
        print("jq not found in Libs/")
        return nil
    }
    let fileManager = FileManager.default
    if !fileManager.isExecutableFile(atPath: path) {
        do {
            try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)
        } catch {
            print("Failed to make jq executable: \(error)")
            return nil
        }
    }
    return path
}

// Enums
enum HCLTool {
    case hcledit
    case hcl2json
    case jq

    var executableURL: String? {
        let path: String?
        switch self {
        case .hcledit:
            path = getEmbeddedHcleditPath()
        case .hcl2json:
            path = getEmbeddedHcl2jsonPath()
        case .jq:
            path = getEmbeddedjqPath()
        }
        return path
    }

    func validate() throws {
        guard let url = executableURL else {
            throw HCLToolError.toolNotFound(name: String(describing: self))
        }
        guard FileManager.default.fileExists(atPath: url) else {
            throw HCLToolError.toolNotFound(name: String(describing: self))
        }
    }
}

enum HCLToolError: Error {
    case toolNotFound(name: String)
}

enum HCLEditCommand {
    case attributeGet(key: String, file: String)
    case attributeSet(key: String, value: String, file: String)
    case jq(filter: String)
    case fmt

    var arguments: [String] {
        switch self {
        case let .attributeGet(key, file):
            return ["attribute", "get", key, "-f", file]
        case let .attributeSet(key, value, file):
            return ["attribute", "set", key, value, "-f", file, "-u"]
        case let .jq(filter):
            return ["-r", filter] // `-r` for raw output (HCL-compatible)
        case .fmt:
            return ["fmt"]
        }
    }
}
