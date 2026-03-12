//
//  RegisterView.swift
//  TrainLog
//

import SwiftUI

struct RegisterView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    var onSignUp: (String, String, String) async throws -> Void
    var onBack: () -> Void

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                        .frame(minHeight: 40)

                    VStack(spacing: AppDesign.sectionSpacing) {
                        Text("Регистрация")
                            .font(.title.bold())

                        TextField("Имя", text: $displayName)
                            .textContentType(.name)
                            .textFieldStyle(.roundedBorder)

                        TextField("Email", text: $email)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)

                        PasswordField(title: "Пароль", text: $password, textContentType: .newPassword)

                        PrimaryActionButton(
                            title: "Создать аккаунт",
                            isLoading: isLoading,
                            isDisabled: email.isEmpty || password.isEmpty || displayName.isEmpty,
                            action: { Task { await signUp() } }
                        )

                        Button("Уже есть аккаунт? Войти", action: onBack)
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
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    onBack()
                } label: {
                    Label("Назад", systemImage: "chevron.left")
                }
            }
        }
        .alert("Ошибка регистрации", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            if let msg = errorMessage { Text(msg) }
        }
    }

    private func signUp() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await onSignUp(displayName, email, password)
        } catch {
            errorMessage = AppErrors.userMessage(for: error)
        }
    }
}

#Preview {
    RegisterView(onSignUp: { _, _, _ in }, onBack: {})
}
