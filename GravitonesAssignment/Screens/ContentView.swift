//
//  ContentView.swift
//  GravitonesAssignment > Screens
//
//  Root view. Gates the UI on authentication state.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var auth: AuthViewModel

    var body: some View {
        Group {
            if auth.isAuthenticated {
                HomeView()
            } else {
                LoginView()
            }
        }
        .animation(.default, value: auth.isAuthenticated)
    }
}

#Preview {
    ContentView().environmentObject(AuthViewModel())
}
