import SwiftUI

struct OperationModal: View {
    @Binding var showModal: Bool
    @Binding var keyValuePairs: [KeyValueInput]
    @Binding var actionInput: String
    let directoryPath: String?

    @State private var keyInput: String = ""
    @State private var valueInput: String = ""

    @EnvironmentObject private var appData: AppData
    @Environment(\.openWindow) var openWindow

    private let manager = TerraParseManager.shared

    var body: some View {
        let operationValue = actionInput

        VStack {
            Text("Key-Value pair to \"\(operationValue)\" on config")
                .font(.headline)
                .padding()

            VStack(alignment: .leading, spacing: 10) {
                Text("Key:")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                TextField("(e.g., inputs or inputs.count", text: $keyInput)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                if actionInput != "delete" { // Hide value input for delete
                    Text("Value:")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    TextField("(e.g., 42 or [a, b] or {enabled = true})", text: $valueInput)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            }
            .padding(.horizontal)

            List(keyValuePairs, id: \.key) { pair in
                Text(
                    "\(pair.action) \(pair.key) \(pair.action == "delete" ? "" : "= \(pair.formattedValue())")"
                )
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
                    addKeyValuePair()
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

            Button(action: {
                // showModal.toggle()
                appData.update(
                    filePaths: applyChanges(), modifiedKeys: keyValuePairs.map { $0.key }
                )
                openWindow(id: "Preview")
            }) {
                Text("Preview Changes")
            }
            .disabled(keyValuePairs.isEmpty)
        }
        .padding(.horizontal, 20)
        .frame(width: 400, height: 500)
        .cornerRadius(10)
    }

    /// Applies changes to all files and returns their paths.
    func applyChanges(inputKey _: String = "") -> [String] {
        let files = manager.findTerragruntFiles(in: directoryPath!)
        guard !files.isEmpty else { return [] }

        manager.submitChanges(to: files, keyValuePairs: keyValuePairs)
        return files
    }

    /// Adds a key-value pair, parsing the value type from the string input.
    func addKeyValuePair() {
        guard !keyInput.isEmpty else { return }
        if actionInput != "delete" && valueInput.isEmpty { return }

        let value =
            actionInput == "delete"
                ? String.ParsedValue.unquotedString("") : valueInput.parseValue()

        if let existingIndex = keyValuePairs.firstIndex(where: { $0.key == keyInput }) {
            keyValuePairs[existingIndex] = KeyValueInput(
                key: keyInput, value: value, action: actionInput
            )
        } else {
            keyValuePairs.append(
                KeyValueInput(key: keyInput, value: value, action: actionInput))
        }

        keyInput = ""
        valueInput = ""
    }
}

struct OperationModal_Previews: PreviewProvider {
    @State static var showModal = true
    @State static var keyValuePairs: [KeyValueInput] = []
    @State static var actionInput = "modify"
    @State static var directoryPath = ""

    static var previews: some View {
        OperationModal(
            showModal: $showModal,
            keyValuePairs: $keyValuePairs,
            actionInput: $actionInput,
            directoryPath: directoryPath
        )
    }
}
