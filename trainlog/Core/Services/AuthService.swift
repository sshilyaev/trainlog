//
//  AuthService.swift
//  TrainLog
//

import Foundation

protocol AuthServiceProtocol {
    var currentUserId: String? { get }
    /// Имя или email текущего пользователя для приветствия на экране выбора профиля.
    var currentUserDisplayName: String? { get }
    /// Email текущего пользователя (для отображения и смены пароля).
    var currentUserEmail: String? { get }
    func signIn(email: String, password: String) async throws -> String
    func signUp(email: String, password: String, displayName: String) async throws -> String
    func signOut() throws
    /// Сменить пароль в приложении (текущий + новый). Требует повторной аутентификации.
    func changePassword(currentPassword: String, newPassword: String) async throws
    func addAuthStateListener(_ handler: @escaping (String?) -> Void)
}
