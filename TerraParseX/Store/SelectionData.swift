//
//  OperationModalData.swift
//  TerraParseX
//
//  Created by Evan Lopez on 4/3/25.
//
import SwiftUI

class OperationModalData: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var statusMessage: String = "Ready"
}
