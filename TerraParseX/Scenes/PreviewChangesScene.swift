//
//  PreviewFilesScene.swift
//  TerraParseX
//
//  Created by Evan Lopez on 3/17/25.
//

import SwiftUI
import XcodebuildNvimPreview

// struct PreviewChangesScene: View {
//     @State private var editorText = """
//     // Sample Code
//     import Foundation
//
//     func helloWorld() {
//         print("Hello, world!")
//     }
//
//     helloWorld()
//     """
//
//     var body: some View {
//         VStack {
//             Text("Preview Scene")
//                 .font(.largeTitle)
//                 .bold()
//
//             TextEditor(text: $editorText)
//                 .frame(height: 300)
//                 .padding()
//                 .border(Color.gray, width: 1)
//                 .font(.system(size: 16, weight: .light, design: .monospaced))
//                 .foregroundColor(.black)
//                 .background(Color.white)
//                 .cornerRadius(8)
//
//             Spacer()
//         }
//         .padding()
//     }
// }
//
// struct PreviewScene_Previews: PreviewProvider {
//     static var previews: some View {
//         PreviewChangesScene().setupNvimPreview {
//             PreviewChangesScene()
//         }
//     }
// }

struct PreviewChangesScene: View {
    private let manager = TerraParseManager.shared
    let filePaths: [String] // Paths to all modified terragrunt.hcl files
    let modifiedKeys: [String] // Keys that were changed
    @State private var selectedFileIndex: Int = 0 // For tabbed navigation

    var body: some View {
        VStack {
            Text("Preview Scene")
                .font(.largeTitle)
                .bold()

            if filePaths.isEmpty {
                Text("No terragrunt.hcl files found.")
                    .foregroundColor(.gray)
                    .frame(height: 300)
            } else {
                TabView(selection: $selectedFileIndex) {
                    ForEach(filePaths.indices, id: \.self) { index in
                        ScrollView {
                            Text(
                                manager.displayFileContent(
                                    filePaths[index], modifiedKeys: modifiedKeys
                                )
                            )
                            .font(.system(size: 16, weight: .light, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .border(Color.gray, width: 1)
                            .background(Color.white)
                            .cornerRadius(8)
                        }
                        .frame(height: 300)
                        .tabItem {
                            Text(URL(fileURLWithPath: filePaths[index]).lastPathComponent)
                        }
                        .tag(index)
                    }
                }
            }

            Spacer()
        }
        .padding()
    }
}

struct PreviewScene_Previews: PreviewProvider {
    static var previews: some View {
        PreviewChangesScene(
            filePaths: ["/path/to/project/terragrunt1.hcl", "/path/to/project/terragrunt2.hcl"],
            modifiedKeys: ["inputs.simple", "inputs.count"]
        )
        .frame(width: 500, height: 400)
    }
}
