//
//  HomeView.swift
//  GravitonesAssignment > Screens
//
//  Placeholder authenticated screen so the login/logout flow is exercisable
//  end-to-end. The video list & player land in later branches; this screen's
//  only real responsibility here is signing out.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @State private var isLoggingOut = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.green)
                Text("You're signed in")
                    .font(.title3.weight(.semibold))

                if let user = auth.currentUser {
                    VStack(spacing: 4) {
                        Text(user.name).font(.headline)
                        Text(user.email).foregroundStyle(.secondary)
                    }
                }

                Text("Video list & player arrive in later branches.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            .padding()
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Log Out", role: .destructive, action: logout)
                        .disabled(isLoggingOut)
                }
            }
        }
    }

    private func logout() {
        isLoggingOut = true
        Task {
            await auth.logout()
            isLoggingOut = false
        }
    }
}

#Preview {
    HomeView().environmentObject(AuthViewModel())
}
