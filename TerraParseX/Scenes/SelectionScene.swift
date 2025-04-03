//
//  SelectionScene.swift
//  TerraParseX
//
//  Created by Evan Lopez on 3/17/25.
//

import Cocoa
import SwiftUI

struct SelectionScene: View {
    @State private var selectedEnvironment = ""
    @State private var selectedAccount = ""
    @State private var selectedRegion = ""
    @State private var selectedCluster = ""
    @State private var selectedService = ""
    @State private var isSubmitDisabled = false

    let environments = ["Production", "Staging", "Development", "Testing"]
    let accounts = ["Account A", "Account B", "Account C"]
    let regions = ["US East", "US West", "Europe", "Asia"]
    let clusters = ["Cluster 1", "Cluster 2", "Cluster 3"]
    let services = ["Service X", "Service Y", "Service Z"]
    let operations = ["add", "modify", "delete"]

    @State private var showModal: Bool = false
    @State private var keyValuePairs: [KeyValueInput] = []
    @State private var selectedDirectory: URL?
    @State private var selectedOperation: String = "modify"

    var body: some View {
        VStack(spacing: 20) {
            Text("File Selector")
                .font(.largeTitle)
                .bold()
                .padding(.top, 30)

            if let selectedDirectory = selectedDirectory {
                Text("Selected Directory: \(selectedDirectory.path)")
            } else {
                Text("No directory selected")
            }

            Button("Select Directory") {
                selectedDirectory = selectDirectory()
            }

            Picker(selection: $selectedEnvironment) {
                ForEach(environments, id: \.self) { environment in
                    Text(environment)
                }
            } label: {
                Text("Environment").frame(width: 90, alignment: .leading)
            }
            .pickerStyle(MenuPickerStyle())
            .padding()
            .frame(width: 350)
            .background(RoundedRectangle(cornerRadius: 10).stroke(Color.gray))

            Picker(selection: $selectedAccount) {
                ForEach(accounts, id: \.self) { account in
                    Text(account)
                }
            } label: {
                Text("Account").frame(width: 90, alignment: .leading)
            }
            .pickerStyle(MenuPickerStyle())
            .padding()
            .frame(width: 350)
            .background(RoundedRectangle(cornerRadius: 10).stroke(Color.gray))

            Picker(selection: $selectedRegion) {
                ForEach(regions, id: \.self) { region in
                    Text(region)
                }
            } label: {
                Text("Region").frame(width: 90, alignment: .leading)
            }
            .pickerStyle(MenuPickerStyle())
            .padding()
            .frame(width: 350)
            .background(RoundedRectangle(cornerRadius: 10).stroke(Color.gray))

            Picker(selection: $selectedCluster) {
                ForEach(clusters, id: \.self) { cluster in
                    Text(cluster)
                }
            } label: {
                Text("Cluster").frame(width: 90, alignment: .leading)
            }
            .pickerStyle(MenuPickerStyle())
            .padding()
            .frame(width: 350)
            .background(RoundedRectangle(cornerRadius: 10).stroke(Color.gray))

            Picker(selection: $selectedService) {
                ForEach(services, id: \.self) { service in
                    Text(service)
                }
            } label: {
                Text("Service").frame(width: 90, alignment: .leading)
            }
            .pickerStyle(MenuPickerStyle())
            .padding()
            .frame(width: 350)
            .background(RoundedRectangle(cornerRadius: 10).stroke(Color.gray))

            HStack {
                Spacer()
                Text("Operation:")
                    .font(.headline)
                    .padding(.trailing, 10)
                    .frame(alignment: .center)

                HStack {
                    ForEach(operations, id: \.self) { operation in
                        Button(action: {
                            selectedOperation = operation
                        }) {
                            HStack {
                                Image(
                                    systemName: selectedOperation == operation
                                        ? "circle.inset.filled" : "circle")
                                Text(operation.capitalized)
                                    .padding(.leading, 5)
                            }.padding(5)
                        }
                        .foregroundColor(.black)
                    }
                }
                Spacer()
            }

            HStack {
                Button(action: {
                    resetForm()
                }) {
                    Text("Clear")
                        .frame(maxWidth: 100)
                        .padding(12)
                        .background(Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 10)

                Button(action: {
                    showModal = true
                }) {
                    Text("Find")
                        .frame(maxWidth: 100)
                        .padding(12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isSubmitDisabled)
            }
            .padding(.vertical, 20)
            .padding(.bottom, 10)
        }
        .frame(width: 450)
        .sheet(isPresented: $showModal) {
            if let url = selectedDirectory, !url.path.isEmpty {
                OperationModal(
                    showModal: $showModal,
                    keyValuePairs: $keyValuePairs,
                    actionInput: $selectedOperation,
                    directoryPath: url.path
                )
            } else {
                VStack {
                    Text("No valid URL selected")
                        .padding()
                    Button("Close") {
                        showModal = false // Dismiss the sheet
                    }
                    .padding()
                }
                .onAppear {
                    if selectedDirectory == nil {
                        print("Log: URL is nil")
                    } else if selectedDirectory!.path.isEmpty {
                        print("Log: URL path is empty")
                    }
                }
            }
        }
        .onAppear {
            selectedDirectory = selectDirectory()
        }
    }

    func selectDirectory() -> URL? {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false

        if openPanel.runModal() == .OK {
            return openPanel.url
        }
        return nil
    }

    private func resetForm() {
        selectedEnvironment = ""
        selectedAccount = ""
        selectedRegion = ""
        selectedCluster = ""
        selectedService = ""
        selectedOperation = "modify"
    }
}

struct SelectionScene_Previews: PreviewProvider {
    static var previews: some View {
        SelectionScene()
    }
}
