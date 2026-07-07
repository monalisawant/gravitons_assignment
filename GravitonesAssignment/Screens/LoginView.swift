//
//  LoginView.swift
//  GravitonesAssignment
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var auth: AuthViewModel

    @State private var email = ""
    @State private var password = ""
    @FocusState private var focusedField: Field?

    private enum Field { case email, password }

    private var isLoading: Bool { auth.state == .loading }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                header
                form
                signInButton
                errorMessage
                Spacer()
            }
            .padding(.horizontal, 24)
            .navigationTitle("Sign In")
            .animation(.default, value: auth.state)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { focusedField = .email }
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 12) {
            (Text("g").foregroundStyle(brandRed) + Text("ravitones"))
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .tracking(0.5)
            Text("Sign in to browse and play videos")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var brandRed: Color { Color(red: 0.80, green: 0.16, blue: 0.24) }

    private var form: some View {
        VStack(spacing: 12) {
            TextField("Email", text: $email)
                .textContentType(.username)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .email)
                .submitLabel(.next)
                .onSubmit { focusedField = .password }

            SecureField("Password", text: $password)
                .textContentType(.password)
                .focused($focusedField, equals: .password)
                .submitLabel(.go)
                .onSubmit(submit)
        }
        .textFieldStyle(.roundedBorder)
        .disabled(isLoading)
    }

    private var signInButton: some View {
        Button(action: submit) {
            Group {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text("Sign In").fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 28)
        }
        .buttonStyle(.borderedProminent)
        .disabled(isLoading)
    }

    @ViewBuilder
    private var errorMessage: some View {
        if case let .error(message) = auth.state {
            Text(message)
                .font(.callout)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
                .transition(.opacity)
        }
    }

    // MARK: - Actions

    private func submit() {
        focusedField = nil
        Task { await auth.login(email: email, password: password) }
    }
}

#Preview {
    LoginView().environmentObject(AuthViewModel())
}
