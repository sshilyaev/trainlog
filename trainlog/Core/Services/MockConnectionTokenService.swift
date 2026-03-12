//
//  MockConnectionTokenService.swift
//  TrainLog
//

import Foundation

final class MockConnectionTokenService: ConnectionTokenServiceProtocol {
    private var storage: [ConnectionToken] = []
    private let tokenLength = 6
    private let validityDuration: TimeInterval = 15 * 60
    private static let alphanumeric = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

    func createToken(traineeProfileId: String) async throws -> ConnectionToken {
        try await Task.sleep(nanoseconds: 200_000_000)
        let token = Self.generateToken(length: tokenLength)
        let now = Date()
        let t = ConnectionToken(
            id: token,
            traineeProfileId: traineeProfileId,
            createdAt: now,
            expiresAt: now.addingTimeInterval(validityDuration),
            used: false
        )
        storage.append(t)
        return t
    }

    func getToken(token: String) async throws -> ConnectionToken? {
        try await Task.sleep(nanoseconds: 100_000_000)
        return storage.first { $0.id == token }
    }

    func markTokenUsed(token: String) async throws {
        try await Task.sleep(nanoseconds: 100_000_000)
        if let i = storage.firstIndex(where: { $0.id == token }) {
            let t = storage[i]
            storage[i] = ConnectionToken(
                id: t.id,
                traineeProfileId: t.traineeProfileId,
                createdAt: t.createdAt,
                expiresAt: t.expiresAt,
                used: true
            )
        }
    }

    private static func generateToken(length: Int) -> String {
        String((0..<length).map { _ in alphanumeric.randomElement()! })
    }
}
