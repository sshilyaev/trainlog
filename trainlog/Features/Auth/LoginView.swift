//
//  LoginView.swift
//  TrainLog
//

import SwiftUI

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    var onSignIn: (String, String) async throws -> Void
    var onSignUp: () -> Void

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                        .frame(minHeight: 40)

                    VStack(spacing: AppDesign.sectionSpacing) {
                        Text("Вход")
                            .font(.title.bold())

                        TextField("Email", text: $email)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)

                        PasswordField(title: "Пароль", text: $password, textContentType: .password)

                        PrimaryActionButton(
                            title: "Войти",
                            isLoading: isLoading,
                            isDisabled: email.isEmpty || password.isEmpty,
                            action: { Task { await signIn() } }
                        )

                        if let msg = errorMessage {
                            Text(msg)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                        }

                        Button("Нет аккаунта? Регистрация", action: onSignUp)
                            .font(.subheadline)
                    }
                    .padding(.horizontal, 24)
                    .frame(maxWidth: 400)

                    Spacer(minLength: 0)
                        .frame(minHeight: 40)
                }
                .frame(minHeight: geo.size.height)
            }
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnTap()
        }
        .onChange(of: email) { _, _ in errorMessage = nil }
        .onChange(of: password) { _, _ in errorMessage = nil }
    }

    private func signIn() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await onSignIn(email, password)
        } catch {
            errorMessage = AppErrors.userMessage(for: error)
        }
    }
}

#Preview {
    LoginView(
        onSignIn: { _, _ in },
        onSignUp: {}
    )
}
