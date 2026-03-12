//
//  FirestoreProfileService.swift
//  TrainLog
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class FirestoreProfileService: ProfileServiceProtocol {
    private let profiles = Firestore.firestore().collection("profiles")

    func fetchProfiles(userId: String) async throws -> [Profile] {
        let snapshot = try await profiles
            .whereField("userId", isEqualTo: userId)
            .getDocuments()

        let list = snapshot.documents.compactMap { doc in
            try? parseProfile(id: doc.documentID, data: doc.data())
        }
        return list.sorted { $0.createdAt < $1.createdAt }
    }

    func fetchProfile(id: String) async throws -> Profile? {
        guard !id.isEmpty else { return nil }
        let ref = profiles.document(id)
        let snapshot = try await ref.getDocument()
        guard snapshot.exists, let data = snapshot.data() else { return nil }
        return try parseProfile(id: snapshot.documentID, data: data)
    }

    func createProfile(_ profile: Profile) async throws -> Profile {
        let db = Firestore.firestore()
        let coll = db.collection("profiles")
        var data: [String: Any] = [
            "userId": profile.userId,
            "type": profile.type.rawValue,
            "name": profile.name,
            "createdAt": Timestamp(date: profile.createdAt)
        ]
        if let gym = profile.gymName { data["gymName"] = gym }
        if let g = profile.gender { data["gender"] = g.rawValue }
        if let emoji = profile.iconEmoji { data["iconEmoji"] = emoji }
        if let owner = profile.ownerCoachProfileId { data["ownerCoachProfileId"] = owner }
        if let mergedInto = profile.mergedIntoProfileId { data["mergedIntoProfileId"] = mergedInto }
        let ref = try await coll.addDocument(data: data)
        return Profile(
            id: ref.documentID,
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
    }

    func updateProfile(_ profile: Profile) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "FirestoreProfileService", code: -3, userInfo: [NSLocalizedDescriptionKey: "Пользователь не авторизован"])
        }
        let docId = try await documentId(userId: currentUserId, type: profile.type, createdAt: profile.createdAt)
        let ref = profiles.document(docId)
        var data: [String: Any] = [
            "userId": currentUserId,
            "type": profile.type.rawValue,
            "name": profile.name,
            "createdAt": Timestamp(date: profile.createdAt)
        ]
        if let gym = profile.gymName { data["gymName"] = gym }
        if let g = profile.gender { data["gender"] = g.rawValue }
        if let emoji = profile.iconEmoji { data["iconEmoji"] = emoji }
        if let owner = profile.ownerCoachProfileId { data["ownerCoachProfileId"] = owner }
        if let mergedInto = profile.mergedIntoProfileId { data["mergedIntoProfileId"] = mergedInto }
        try await ref.updateData(data)
    }

    func updateProfile(id: String, userId: String, type: ProfileType, name: String, gymName: String?, createdAt: Date, gender: ProfileGender?, iconEmoji: String?) async throws {
        let docId = String(id)
        guard !docId.isEmpty else {
            throw NSError(domain: "FirestoreProfileService", code: -1, userInfo: [NSLocalizedDescriptionKey: "id не может быть пустым"])
        }
        let db = Firestore.firestore()
        let path = ("profiles/" as NSString).appending(docId) as String
        let ref = db.document(path)
        var data: [String: Any] = [
            "userId": userId,
            "type": type.rawValue,
            "name": name,
            "createdAt": Timestamp(date: createdAt)
        ]
        if let gym = gymName { data["gymName"] = gym }
        if let g = gender { data["gender"] = g.rawValue }
        if let emoji = iconEmoji { data["iconEmoji"] = emoji }
        try await ref.setData(data)
    }

    func deleteProfile(_ profile: Profile) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "FirestoreProfileService", code: -3, userInfo: [NSLocalizedDescriptionKey: "Пользователь не авторизован"])
        }
        let docId = try await documentId(userId: currentUserId, type: profile.type, createdAt: profile.createdAt)
        try await profiles.document(docId).delete()
    }

    private func parseProfile(id: String, data: [String: Any]) throws -> Profile? {
        guard let userId = data["userId"] as? String,
              let typeRaw = data["type"] as? String,
              let type = ProfileType(rawValue: typeRaw),
              let name = data["name"] as? String else { return nil }

        let gymName = data["gymName"] as? String
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let genderRaw = data["gender"] as? String
        let gender = genderRaw.flatMap { ProfileGender(rawValue: $0) }
        let iconEmoji = data["iconEmoji"] as? String
        let ownerCoachProfileId = data["ownerCoachProfileId"] as? String
        let mergedIntoProfileId = data["mergedIntoProfileId"] as? String

        return Profile(
            id: id,
            userId: userId,
            type: type,
            name: name,
            gymName: gymName,
            createdAt: createdAt,
            gender: gender,
            iconEmoji: iconEmoji,
            ownerCoachProfileId: ownerCoachProfileId,
            mergedIntoProfileId: mergedIntoProfileId
        )
    }

    /// Находит documentID профиля по userId и type (если один документ — возвращаем его; иначе по createdAt).
    private func documentId(userId: String, type: ProfileType, createdAt: Date) async throws -> String {
        let snapshot = try await profiles
            .whereField("userId", isEqualTo: userId)
            .whereField("type", isEqualTo: type.rawValue)
            .getDocuments()

        let docs = snapshot.documents
        if docs.isEmpty {
            throw NSError(domain: "FirestoreProfileService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Профиль не найден"])
        }
        if docs.count == 1 {
            return docs[0].documentID
        }
        let createdAtTs = createdAt.timeIntervalSince1970
        for doc in docs {
            let data = doc.data()
            guard let ts = (data["createdAt"] as? Timestamp)?.dateValue() else { continue }
            if abs(ts.timeIntervalSince1970 - createdAtTs) < 10 {
                return doc.documentID
            }
        }
        return docs[0].documentID
    }
}
