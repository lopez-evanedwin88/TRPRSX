//
//  AppData.swift
//  TerraParseX
//
//  Created by Evan Lopez on 4/3/25.
//
import SwiftUI

class AppData: ObservableObject {
    @Published var filePaths: [String] = []
    @Published var modifiedKeys: [String] = []

    func update(filePaths: [String], modifiedKeys: [String]) {
        self.filePaths = filePaths
        self.modifiedKeys = modifiedKeys
    }
}
