//
//  FirestoreCoachTraineeLinkService.swift
//  TrainLog
//

import Foundation
import FirebaseFirestore

@MainActor
final class FirestoreCoachTraineeLinkService: CoachTraineeLinkServiceProtocol {
    private var links: CollectionReference {
        Firestore.firestore().collection("coachTraineeLinks")
    }

    func fetchTraineeProfileIds(coachProfileId: String) async throws -> [String] {
        let links = try await fetchLinks(coachProfileId: coachProfileId)
        return links.map(\.traineeProfileId)
    }

    func fetchLinks(coachProfileId: String) async throws -> [CoachTraineeLink] {
        let snapshot = try await links
            .whereField("coachProfileId", isEqualTo: coachProfileId)
            .getDocuments()
        return snapshot.documents.compactMap { doc -> CoachTraineeLink? in
            let data = doc.data()
            guard let coachId = data["coachProfileId"] as? String,
                  let traineeId = data["traineeProfileId"] as? String else { return nil }
            let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            let displayName = data["displayName"] as? String
            let note = data["note"] as? String
            let isArchived = data["archived"] as? Bool ?? false
            return CoachTraineeLink(
                id: doc.documentID,
                coachProfileId: coachId,
                traineeProfileId: traineeId,
                createdAt: createdAt,
                displayName: displayName,
                note: note,
                isArchived: isArchived
            )
        }
    }

    func fetchLinksForTrainee(traineeProfileId: String) async throws -> [CoachTraineeLink] {
        let snapshot = try await links
            .whereField("traineeProfileId", isEqualTo: traineeProfileId)
            .getDocuments()
        return snapshot.documents.compactMap { doc -> CoachTraineeLink? in
            let data = doc.data()
            guard let coachId = data["coachProfileId"] as? String,
                  let traineeId = data["traineeProfileId"] as? String else { return nil }
            let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            let displayName = data["displayName"] as? String
            let note = data["note"] as? String
            let isArchived = data["archived"] as? Bool ?? false
            return CoachTraineeLink(
                id: doc.documentID,
                coachProfileId: coachId,
                traineeProfileId: traineeId,
                createdAt: createdAt,
                displayName: displayName,
                note: note,
                isArchived: isArchived
            )
        }
    }

    func addLink(coachProfileId: String, traineeProfileId: String, displayName: String?, note: String?) async throws {
        var data: [String: Any] = [
            "coachProfileId": coachProfileId,
            "traineeProfileId": traineeProfileId,
            "createdAt": Timestamp(date: Date())
        ]
        if let d = displayName, !d.isEmpty { data["displayName"] = d }
        if let n = note, !n.isEmpty { data["note"] = n }
        data["archived"] = false
        _ = try await links.addDocument(data: data)
    }

    func removeLink(coachProfileId: String, traineeProfileId: String) async throws {
        let snapshot = try await links
            .whereField("coachProfileId", isEqualTo: coachProfileId)
            .whereField("traineeProfileId", isEqualTo: traineeProfileId)
            .getDocuments()
        for doc in snapshot.documents {
            try await doc.reference.delete()
        }
    }

    func setArchived(coachProfileId: String, traineeProfileId: String, isArchived: Bool) async throws {
        let snapshot = try await links
            .whereField("coachProfileId", isEqualTo: coachProfileId)
            .whereField("traineeProfileId", isEqualTo: traineeProfileId)
            .getDocuments()
        for doc in snapshot.documents {
            try await doc.reference.updateData(["archived": isArchived])
        }
    }
}
