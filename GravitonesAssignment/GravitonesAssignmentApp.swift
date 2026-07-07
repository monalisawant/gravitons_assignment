//
//  GravitonesAssignmentApp.swift
//  Gravitones Assignment
//

import SwiftUI

@main
struct GravitonesAssignmentApp: App {
    @StateObject private var auth = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(auth)
        }
    }
}
