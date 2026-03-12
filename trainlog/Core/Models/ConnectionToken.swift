//
//  ConnectionToken.swift
//  TrainLog
//

import Foundation

/// Временный токен для привязки профиля подопечного к тренеру (QR или код).
struct ConnectionToken: Identifiable, Equatable {
    /// Строка кода (6–8 символов), совпадает с documentId в Firestore.
    let id: String
    let traineeProfileId: String
    let createdAt: Date
    let expiresAt: Date
    let used: Bool

    var isExpired: Bool { Date() >= expiresAt }
    var isValid: Bool { !used && !isExpired }
}
