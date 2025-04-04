//
//  PreviewChangesScene.swift
//  TerraParseX
//
//  Created by Evan Lopez on 3/17/25.
//

import SwiftUI

struct PreviewChangesScene: View {
    private let manager = TerraParseManager.shared
    let filePaths: [String]
    let modifiedKeys: [String]
    @State private var selectedFilePath: String? // Track selected file
    // @SceneStorage("sidebarWidth") private var sidebarWidth: Double = 250

    private var groupedFiles: [String: [String]] {
        Dictionary(grouping: filePaths) { path in
            URL(fileURLWithPath: path).deletingLastPathComponent().path
        }
    }

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Modified Files")
                    .font(.headline)
                    .foregroundColor(.gray)
                    .padding(.top, 10)
                    .padding(.horizontal)

                if filePaths.isEmpty {
                    Text("No terragrunt.hcl files found.")
                        .foregroundColor(.gray)
                        .frame(maxHeight: .infinity)
                } else {
                    List(selection: $selectedFilePath) {
                        ForEach(groupedFiles.keys.sorted(), id: \.self) { directory in
                            Section(header: Text(directory).font(.subheadline)) {
                                ForEach(groupedFiles[directory] ?? [], id: \.self) { filePath in
                                    Text(URL(fileURLWithPath: filePath).lastPathComponent)
                                        .font(.body)
                                        .tag(filePath)
                                }
                            }
                        }
                    }
                    .listStyle(SidebarListStyle())
                }
            }
            .frame(minWidth: 250)
        } detail: {
            // Detail View (Right Panel)
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text(
                        selectedFilePath.map {
                            URL(fileURLWithPath: $0).deletingLastPathComponent().path
                        }
                            ?? "No file selected"
                    )
                    .font(.title2)
                    .foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(nsColor: .darkGray))

                if let selectedFilePath = selectedFilePath {
                    let attributedContent = manager.displayFileContent(
                        selectedFilePath, modifiedKeys: modifiedKeys
                    )
                    GeometryReader { geometry in
                        ScrollView([.vertical, .horizontal]) {
                            HStack(alignment: .top, spacing: 15) {
                                Text(lineNumbers(for: attributedContent))
                                    .font(.system(size: 16, weight: .light, design: .monospaced))
                                    .lineSpacing(5)
                                    .foregroundColor(.gray)
                                    .padding(.leading, 15)
                                    .padding(.top, 15)
                                    .frame(alignment: .leading)

                                Text(attributedContent)
                                    .font(.system(size: 16, weight: .light, design: .monospaced))
                                    .lineSpacing(5)
                                    .textSelection(.enabled)
                                    .frame(alignment: .leading)
                                    .padding(.vertical, 15)
                                    .padding(.trailing, 15)
                            }
                            .frame(
                                minWidth: geometry.size.width, minHeight: geometry.size.height,
                                alignment: .topLeading
                            )
                            .background(Color(nsColor: .textBackgroundColor))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Text("Select a file to preview its changes.")
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(nsColor: .textBackgroundColor))
                }
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 1300, minHeight: 900) // Keep the larger window
    }

    // Generate line numbers based on content
    private func lineNumbers(for content: AttributedString) -> String {
        let plainString = String(content.characters)
        // Split by newlines and preserve empty lines
        let lines = plainString.components(separatedBy: .newlines)
        // Generate numbers for all lines, including trailing empty ones if present
        return (1 ... lines.count).map { "\($0)" }.joined(separator: "\n")
    }
}

struct PreviewChangesScene_Previews: PreviewProvider {
    static var previews: some View {
        PreviewChangesScene(
            filePaths: [
                "/path/to/project1/terragrunt1.hcl",
                "/path/to/project2/terragrunt2.hcl",
                "/path/to/project1/terragrunt3.hcl",
            ],
            modifiedKeys: ["inputs.simple", "inputs.count"]
        )
    }
}
