//
//  MockAuthService.swift
//  TrainLog
//

import Foundation

/// Для разработки без Firebase. Замени на FirebaseAuthService после настройки.
final class MockAuthService: AuthServiceProtocol {
    var currentUserId: String? = nil
    var currentUserDisplayName: String? = "Тестовый пользователь"
    var currentUserEmail: String? = "test@example.com"
    private var handler: ((String?) -> Void)?

    func signIn(email: String, password: String) async throws -> String {
        try await Task.sleep(nanoseconds: 500_000_000)
        let id = "mock-user-\(UUID().uuidString.prefix(8))"
        currentUserId = id
        handler?(id)
        return id
    }

    func signUp(email: String, password: String, displayName: String) async throws -> String {
        try await signIn(email: email, password: password)
    }

    func signOut() throws {
        currentUserId = nil
        handler?(nil)
    }

    func changePassword(currentPassword: String, newPassword: String) async throws {
        try await Task.sleep(nanoseconds: 400_000_000)
    }

    func addAuthStateListener(_ h: @escaping (String?) -> Void) {
        handler = h
        h(currentUserId)
    }
}
