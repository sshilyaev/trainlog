//
//  FirebaseAuthService.swift
//  TrainLog
//

import Foundation
import FirebaseAuth

final class FirebaseAuthService: AuthServiceProtocol {
    var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }

    var currentUserDisplayName: String? {
        let u = Auth.auth().currentUser
        if let name = u?.displayName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return name
        }
        return u?.email
    }

    var currentUserEmail: String? {
        Auth.auth().currentUser?.email
    }

    func signIn(email: String, password: String) async throws -> String {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        return result.user.uid
    }

    func signUp(email: String, password: String, displayName: String) async throws -> String {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        let changeRequest = result.user.createProfileChangeRequest()
        changeRequest.displayName = displayName
        try await changeRequest.commitChanges()
        return result.user.uid
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }

    func changePassword(currentPassword: String, newPassword: String) async throws {
        guard let user = Auth.auth().currentUser,
              let email = user.email, !email.isEmpty else {
            throw NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "У аккаунта нет привязанной почты"])
        }
        let credential = EmailAuthProvider.credential(withEmail: email, password: currentPassword)
        try await user.reauthenticate(with: credential)
        try await user.updatePassword(to: newPassword)
    }

    func addAuthStateListener(_ handler: @escaping (String?) -> Void) {
        _ = Auth.auth().addStateDidChangeListener { _, user in
            handler(user?.uid)
        }
    }
}
