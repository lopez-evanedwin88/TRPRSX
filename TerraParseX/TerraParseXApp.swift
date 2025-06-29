//
//  TerraParseXApp.swift
//  TerraParseX
//
//  Created by Evan Lopez on 3/17/25.
//

import SwiftUI

@main
struct TerraParseXApp: App {
    @StateObject private var appData = AppData()
    @StateObject private var operationModalData = OperationModalData()

    var body: some Scene {
        WindowGroup(id: Routes.Selection.rawValue) {
            SelectionScene()
                .environmentObject(appData)
                .environmentObject(operationModalData)
        }
        .commands {
            CommandGroup(replacing: .newItem) {} // Disable Cmd+N
        }

        WindowGroup(id: Routes.Preview.rawValue) {
            PreviewChangesScene(filePaths: appData.filePaths, modifiedKeys: appData.modifiedKeys)
                .environmentObject(appData)
        }

        WindowGroup(id: Routes.Settings.rawValue) {
            // SettingsScene()
        }
    }
}
