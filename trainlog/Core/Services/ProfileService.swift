//
//  ProfileService.swift
//  TrainLog
//

import Foundation

protocol ProfileServiceProtocol {
    func fetchProfiles(userId: String) async throws -> [Profile]
    func fetchProfile(id: String) async throws -> Profile?
    /// Создаёт документ через addDocument (id в документе не хранится, только userId). Возвращает профиль с id = documentID.
    func createProfile(_ profile: Profile) async throws -> Profile
    func updateProfile(_ profile: Profile) async throws
    func updateProfile(id: String, userId: String, type: ProfileType, name: String, gymName: String?, createdAt: Date, gender: ProfileGender?, iconEmoji: String?) async throws
    func deleteProfile(_ profile: Profile) async throws
}
