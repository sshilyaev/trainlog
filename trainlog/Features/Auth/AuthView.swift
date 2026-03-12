//
//  AuthView.swift
//  TrainLog
//

import SwiftUI

struct AuthView: View {
    @State private var showRegister = false
    var onSignIn: (String, String) async throws -> Void
    var onSignUp: (String, String, String) async throws -> Void

    var body: some View {
        if showRegister {
            RegisterView(
                onSignUp: onSignUp,
                onBack: { showRegister = false }
            )
        } else {
            LoginView(
                onSignIn: onSignIn,
                onSignUp: { showRegister = true }
            )
        }
    }
}

#Preview {
    AuthView(
        onSignIn: { _, _ in },
        onSignUp: { _, _, _ in }
    )
}
