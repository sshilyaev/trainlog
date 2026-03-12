//
//  MockProfileService.swift
//  TrainLog
//

import Foundation

/// Для разработки без Firebase. In-memory хранилище.
final class MockProfileService: ProfileServiceProtocol {
    private var storage: [Profile] = []

    func fetchProfiles(userId: String) async throws -> [Profile] {
        try await Task.sleep(nanoseconds: 300_000_000)
        return storage.filter { $0.userId == userId }
    }

    func fetchProfile(id: String) async throws -> Profile? {
        try await Task.sleep(nanoseconds: 100_000_000)
        return storage.first { $0.id == id }
    }

    func createProfile(_ profile: Profile) async throws -> Profile {
        try await Task.sleep(nanoseconds: 200_000_000)
        let id = UUID().uuidString
        let created = Profile(
            id: id,
            userId: profile.userId,
            type: profile.type,
            name: profile.name,
            gymName: profile.gymName,
            createdAt: profile.createdAt,
            gender: profile.gender,
            iconEmoji: profile.iconEmoji,
            ownerCoachProfileId: profile.ownerCoachProfileId,
            mergedIntoProfileId: profile.mergedIntoProfileId
        )
        storage.append(created)
        return created
    }

    func updateProfile(_ profile: Profile) async throws {
        if let i = storage.firstIndex(where: { $0.id == profile.id }) {
            storage[i] = profile
        }
    }

    func updateProfile(id: String, userId: String, type: ProfileType, name: String, gymName: String?, createdAt: Date, gender: ProfileGender?, iconEmoji: String?) async throws {
        if let i = storage.firstIndex(where: { $0.id == id }) {
            storage[i] = Profile(id: id, userId: userId, type: type, name: name, gymName: gymName, createdAt: createdAt, gender: gender, iconEmoji: iconEmoji)
        }
    }

    func deleteProfile(_ profile: Profile) async throws {
        storage.removeAll { $0.id == profile.id }
    }
}
