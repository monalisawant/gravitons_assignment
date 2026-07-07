//
//  ContentView.swift
//  GravitonesAssignment
//
//  Root view — shows the list when signed in, the login screen otherwise.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var auth: AuthViewModel

    var body: some View {
        Group {
            if auth.isAuthenticated {
                VideoListView()
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
