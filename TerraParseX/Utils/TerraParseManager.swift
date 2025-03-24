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
    func submitChanges(to files: [String], keyValuePairs: [KeyValueInput], inputKey: String = "") {
        do {
            try HCLTool.hcledit.validate()
        } catch {
            print("Error: \(error)")
            return
        }

        if !inputKey.contains("."), false { // Validation if not root-key
            composeHCLConfiguration(
                files: files, keyValuePairs: keyValuePairs
            )
        } else {
            composeCustomConfigurationHCL(
                files: files, keyValuePairs: keyValuePairs,
                actionInput: inputKey
            )
        }
    }

    /// A compose function that could be used for editing HCL files
    /// This function implements 2-levels of nested key-value pairs
    /// Which was the limitation of hcledit tool
    func composeHCLConfiguration(
        files: [String], keyValuePairs: [KeyValueInput],
        hcleditPath: String = HCLTool.hcledit.executableURL!
    ) {
        for file in files {
            for pair in keyValuePairs {
                let keyPath = pair.key // e.g., "inputs.nested.key"
                let valueStr = pair.formattedValue()
                print("keyPath", keyPath)
                print("valueStr", valueStr)
                let process = Process()
                let pipe = Pipe()

                process.executableURL = URL(fileURLWithPath: hcleditPath)

                // Set hcledit command based on action
                switch pair.action.lowercased() {
                case "add":
                    process.arguments = [
                        "attribute", "append",
                        keyPath, valueStr,
                        "-f", file, "-u", // -f for file input, -u for in-place update
                    ]
                case "modify":
                    process.arguments = [
                        "attribute", "set",
                        keyPath, valueStr,
                        "-f", file, "-u",
                    ]
                case "delete":
                    process.arguments = [
                        "attribute", "rm",
                        keyPath,
                        "-f", file, "-u",
                    ]
                default:
                    print("Unknown action '\(pair.action)' for \(keyPath) in \(file)")
                    continue
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

                    if process.terminationStatus == 0 {
                        print(
                            "Successfully \(pair.action)ed \(keyPath) in \(file) \(pair.action == "delete" ? "" : "to \(valueStr)")"
                        )
                    } else {
                        print(
                            "hcledit failed with status \(process.terminationStatus) for \(keyPath) in \(file)"
                        )
                    }
                } catch {
                    print(
                        "Error running hcledit on \(file) for \(keyPath): \(error.localizedDescription)"
                    )
                }
            }
        }
    }

    /// A custom compose function that will be used for editing HCL files if attribute type config
    /// This will only work for root level key-value pairs
    func composeCustomConfigurationHCL(
        files: [String], keyValuePairs: [KeyValueInput],
        actionInput: String
    ) {
        let hcleditProcess = Process()
        let hcleditPipe = Pipe()

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

        for file in files {
            hcleditProcess.executableURL = URL(fileURLWithPath: hcleditURL)
            hcleditProcess.arguments =
                HCLEditCommand.attributeGet(key: actionInput, file: file).arguments
            hcleditProcess.standardOutput = hcleditPipe
            hcleditProcess.standardError = hcleditPipe

            let hcl2jsonProcess = Process()
            let hcl2jsonPipe = Pipe()

            guard let hcl2jsonURL = HCLTool.hcl2json.executableURL else {
                print("Error: hcl2json executable URL is nil")
                continue
            }
            hcl2jsonProcess.executableURL = URL(fileURLWithPath: hcl2jsonURL)
            hcl2jsonProcess.standardInput = hcleditPipe
            hcl2jsonProcess.standardOutput = hcl2jsonPipe
            hcl2jsonProcess.standardError = hcl2jsonPipe

            do {
                try hcleditProcess.run()
                try hcl2jsonProcess.run()
                hcleditProcess.waitUntilExit()

                var configDict: [String: Any]
                let jsonData = hcl2jsonPipe.fileHandleForReading.readDataToEndOfFile()
                if let jsonString = String(data: jsonData, encoding: .utf8)?.trimmingCharacters(
                    in: .whitespacesAndNewlines), !jsonString.isEmpty,
                    let json = try? JSONSerialization.jsonObject(
                        with: jsonString.data(using: .utf8)!) as? [String: Any]
                {
                    configDict = json
                    print("test123", configDict)
                } else {
                    print("\(file): No existing config for '\(actionInput)' or conversion failed")
                    print("Error parsing JSON: \(String(data: jsonData, encoding: .utf8) ?? "")")
                    configDict = [:]
                }
                //
                // for pair in keyValuePairs {
                //     let keyPath = pair.key // e.g., "inputs.nested.key"
                //     let valueStr = pair.formattedValue()
                //
                //     switch pair.action.lowercased() {
                //     case "add", "modify":
                //         configDict[keyPath] = valueStr
                //     case "delete":
                //         configDict.removeValue(forKey: keyPath)
                //     default:
                //         print("Unknown action '\(pair.action)' for \(pair.key) in \(file)")
                //         continue
                //     }
                // }
                // let updatedJsonData = try! JSONSerialization.data(
                //     withJSONObject: configDict, options: [.prettyPrinted]
                // )
                // let updatedJsonString = String(data: updatedJsonData, encoding: .utf8)!
                //     .replacingOccurrences(of: "\n", with: "") // Compact it
                //     .replacingOccurrences(of: " ", with: "") // Remove spaces
                //
                // let keyValueInputs = [
                //     KeyValueInput(
                //         key: actionInput,
                //         value: updatedJsonString.parseValue(),
                //         action: "add"
                //     ),
                // ]
                // composeHCLConfiguration(files: [file], keyValuePairs: keyValueInputs)
            } catch {
                print("Error processing \(file): \(error)")
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

// Enums
enum HCLTool {
    case hcledit
    case hcl2json

    var executableURL: String? {
        let path: String?
        switch self {
        case .hcledit:
            path = getEmbeddedHcleditPath()
        case .hcl2json:
            path = getEmbeddedHcl2jsonPath()
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

    var arguments: [String] {
        switch self {
        case let .attributeGet(key, file):
            return ["attribute", "get", key, "-f", file]
        case let .attributeSet(key, value, file):
            return ["attribute", "set", key, value, "-f", file, "-u"]
        }
    }
}
