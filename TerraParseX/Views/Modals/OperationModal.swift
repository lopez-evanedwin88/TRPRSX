import SwiftUI

struct OperationModal: View {
    @Binding var showModal: Bool
    @Binding var keyValuePairs: [KeyValueInput]
    let directoryPath: String?
    let operation: String?

    @State private var keyInput: String = ""
    @State private var valueInput: String = "" // Simplified for demo; we'll parse it
    private let manager = TerraParseManager.shared

    var body: some View {
        let operationValue = (operation ?? "").lowercased()

        VStack {
            Text("Key-Value pair to \"\(operationValue)\" on config")
                .font(.headline)
                .padding()

            VStack(alignment: .leading, spacing: 10) {
                Text("Key:")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                TextField("(e.g., inputs.count)", text: $keyInput)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                Text("Value:")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                TextField("(e.g., 42 or [a, b] or {enabled = true})", text: $valueInput)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            .padding(.horizontal)

            List(keyValuePairs, id: \.key) { pair in
                Text("\(pair.key) = \(pair.formattedValue())")
            }
            .frame(height: 100)

            HStack {
                Button(action: {
                    showModal.toggle()
                }) {
                    Text("Cancel")
                        .frame(maxWidth: 80)
                        .padding(10)
                        .background(Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 10)

                Button(action: {
                    // showModal.toggle()
                    addKeyValuePair()
                    // let terraFiles = TerraParseManager.shared.findTerragruntFiles(
                    //     in: "/Users/evanlopez/Development/test-project/environments/")
                    // TerraParseManager.shared.submitChanges(
                    //     to: terraFiles,
                    //     keyValuePairs: [
                    //         KeyValueInput(key: "region", value: "\"us-west-2\""),
                    //         KeyValueInput(key: "environment", value: "\"production\""),
                    //     ]
                    // )
                }) {
                    Text("Apply")
                        .frame(maxWidth: 80)
                        .padding(10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()

            // NavigationLink(
            //     destination: PreviewChangesScene(
            //         filePaths: applyChanges(),
            //         modifiedKeys: keyValuePairs.map { $0.key }
            //     )
            // ) {
            //     Text("Preview Changes")
            //         .padding()
            //         .background(Color.blue)
            //         .foregroundColor(.white)
            //         .cornerRadius(8)
            // }
            // .disabled(keyValuePairs.isEmpty)

            Spacer()
        }
        .padding(.horizontal, 20)
        .frame(width: 400, height: 500)
        .cornerRadius(10)
    }

    /// Adds a key-value pair, parsing the value type from the string input.
    func addKeyValuePair() {
        guard !keyInput.isEmpty, !valueInput.isEmpty else { return }

        let trimmedValue = valueInput.trimmingCharacters(in: .whitespaces)
        let value: Any

        // Parse the value type
        if trimmedValue.lowercased() == "true" || trimmedValue.lowercased() == "false" {
            value = trimmedValue.lowercased() == "true"
        } else if let intValue = Int(trimmedValue) {
            value = intValue
        } else {
            value = trimmedValue // Default to string
        }

        keyValuePairs.append(KeyValueInput(key: keyInput, value: value))
        keyInput = ""
        valueInput = ""
    }

    /// Applies changes to all files and returns their paths.
    func applyChanges() -> [String] {
        let files = manager.findTerragruntFiles(in: directoryPath!)
        guard !files.isEmpty else { return [] }

        manager.submitChanges(to: files, keyValuePairs: keyValuePairs)
        return files
    }
}

struct OperationModal_Previews: PreviewProvider {
    @State static var showModal = true
    @State static var keyValuePairs: [KeyValueInput] = [
        KeyValueInput(key: "inputs", value: "test = {}"),
    ]
    @State static var directoryPath = ""

    static var previews: some View {
        OperationModal(
            showModal: $showModal,
            keyValuePairs: $keyValuePairs,
            directoryPath: directoryPath,
            operation: "Add"
        )
    }
}
