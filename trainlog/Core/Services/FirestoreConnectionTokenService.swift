//
//  FirestoreConnectionTokenService.swift
//  TrainLog
//

import Foundation
import FirebaseFirestore

@MainActor
final class FirestoreConnectionTokenService: ConnectionTokenServiceProtocol {
    private var tokens: CollectionReference {
        Firestore.firestore().collection("connectionTokens")
    }

    private let tokenLength = 6
    private let validityDuration: TimeInterval = 15 * 60 // 15 minutes

    private static let alphanumeric = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

    func createToken(traineeProfileId: String) async throws -> ConnectionToken {
        let now = Date()
        let expiresAt = now.addingTimeInterval(validityDuration)
        let data: [String: Any] = [
            "traineeProfileId": traineeProfileId,
            "createdAt": Timestamp(date: now),
            "expiresAt": Timestamp(date: expiresAt),
            "used": false
        ]
        var token: String
        var ref: DocumentReference
        var attempts = 0
        let maxAttempts = 10
        repeat {
            token = Self.generateToken(length: tokenLength)
            ref = tokens.document(token)
            let snapshot = try await ref.getDocument()
            if !snapshot.exists { break }
            attempts += 1
            if attempts >= maxAttempts { throw NSError(domain: "ConnectionToken", code: -1, userInfo: [NSLocalizedDescriptionKey: "Не удалось сгенерировать уникальный код"]) }
        } while true
        try await ref.setData(data)
        return ConnectionToken(
            id: token,
            traineeProfileId: traineeProfileId,
            createdAt: now,
            expiresAt: expiresAt,
            used: false
        )
    }

    func getToken(token: String) async throws -> ConnectionToken? {
        let ref = tokens.document(token)
        let snapshot = try await ref.getDocument()
        guard snapshot.exists, let data = snapshot.data() else { return nil }
        return parseToken(id: snapshot.documentID, data: data)
    }

    func markTokenUsed(token: String) async throws {
        let ref = tokens.document(token)
        try await ref.updateData(["used": true])
    }

    private static func generateToken(length: Int) -> String {
        String((0..<length).map { _ in alphanumeric.randomElement()! })
    }

    private func parseToken(id: String, data: [String: Any]) -> ConnectionToken? {
        guard let traineeProfileId = data["traineeProfileId"] as? String,
              let createdAt = (data["createdAt"] as? Timestamp)?.dateValue(),
              let expiresAt = (data["expiresAt"] as? Timestamp)?.dateValue(),
              let used = data["used"] as? Bool else { return nil }
        return ConnectionToken(
            id: id,
            traineeProfileId: traineeProfileId,
            createdAt: createdAt,
            expiresAt: expiresAt,
            used: used
        )
    }
}
