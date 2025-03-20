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
    func submitChanges(to files: [String], keyValuePairs: [KeyValueInput]) {
        guard let hcleditPath = getEmbeddedHcleditPath() else {
            print("hcledit not found in app bundle")
            return
        }

        for file in files {
            for pair in keyValuePairs {
                let keyPath = pair.key // e.g., "inputs.nested.key"
                let valueStr = pair.formattedValue()

                // Use hcledit to set the attribute
                let process = Process()
                let pipe = Pipe()
                process.executableURL = URL(fileURLWithPath: hcleditPath)
                process.arguments = [
                    "attribute", "set",
                    keyPath, valueStr,
                    "-f", file, "-u", // -f for file input, -u for in-place update
                ]
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
                        print("Successfully updated \(keyPath) in \(file) to \(valueStr)")
                    } else {
                        print("hcledit failed with status \(process.terminationStatus)")
                    }
                } catch {
                    print("Error running hcledit on \(file): \(error.localizedDescription)")
                }
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
