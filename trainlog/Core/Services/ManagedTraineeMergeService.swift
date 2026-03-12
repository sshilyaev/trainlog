//
//  ManagedTraineeMergeService.swift
//  TrainLog
//

import Foundation

protocol ManagedTraineeMergeServiceProtocol {
    /// Переносит все данные managed-подопечного в реальный профиль подопечного.
    /// Меняет ссылки в measurements/goals/memberships/visits/coachTraineeLinks и помечает managed-профиль как merged.
    func mergeManagedTrainee(
        coachProfileId: String,
        managedTraineeProfileId: String,
        realTraineeProfileId: String
    ) async throws
}

#if canImport(FirebaseFirestore)
import FirebaseFirestore

@MainActor
final class FirestoreManagedTraineeMergeService: ManagedTraineeMergeServiceProtocol {
    private let db = Firestore.firestore()

    func mergeManagedTrainee(coachProfileId: String, managedTraineeProfileId: String, realTraineeProfileId: String) async throws {
        guard !coachProfileId.isEmpty, !managedTraineeProfileId.isEmpty, !realTraineeProfileId.isEmpty else { return }
        if managedTraineeProfileId == realTraineeProfileId { return }

        // Переносим по коллекциям.
        try await migrateByField(collection: "measurements", field: "profileId", from: managedTraineeProfileId, to: realTraineeProfileId)
        try await migrateByField(collection: "goals", field: "profileId", from: managedTraineeProfileId, to: realTraineeProfileId)

        try await migrateCoachTraineePair(collection: "memberships", coachProfileId: coachProfileId, from: managedTraineeProfileId, to: realTraineeProfileId)
        try await migrateCoachTraineePair(collection: "visits", coachProfileId: coachProfileId, from: managedTraineeProfileId, to: realTraineeProfileId)
        try await migrateCoachTraineePair(collection: "coachTraineeLinks", coachProfileId: coachProfileId, from: managedTraineeProfileId, to: realTraineeProfileId)

        // Помечаем managed-профиль как объединённый.
        try await db.collection("profiles").document(managedTraineeProfileId).updateData([
            "mergedIntoProfileId": realTraineeProfileId,
            "mergedAt": Timestamp(date: Date())
        ])
    }

    private func migrateByField(collection: String, field: String, from: String, to: String) async throws {
        let coll = db.collection(collection)
        let snapshot = try await coll.whereField(field, isEqualTo: from).getDocuments()
        try await applyBatches(docs: snapshot.documents) { batch, doc in
            batch.updateData([field: to], forDocument: doc.reference)
        }
    }

    private func migrateCoachTraineePair(collection: String, coachProfileId: String, from: String, to: String) async throws {
        let coll = db.collection(collection)
        let snapshot = try await coll
            .whereField("coachProfileId", isEqualTo: coachProfileId)
            .whereField("traineeProfileId", isEqualTo: from)
            .getDocuments()
        try await applyBatches(docs: snapshot.documents) { batch, doc in
            batch.updateData(["traineeProfileId": to], forDocument: doc.reference)
        }
    }

    private func applyBatches(docs: [QueryDocumentSnapshot], apply: (WriteBatch, QueryDocumentSnapshot) -> Void) async throws {
        guard !docs.isEmpty else { return }
        let chunkSize = 450 // запас до 500
        var index = 0
        while index < docs.count {
            let end = min(index + chunkSize, docs.count)
            let chunk = Array(docs[index..<end])
            let batch = db.batch()
            for doc in chunk {
                apply(batch, doc)
            }
            try await batch.commit()
            index = end
        }
    }
}
#endif

final class MockManagedTraineeMergeService: ManagedTraineeMergeServiceProtocol {
    func mergeManagedTrainee(coachProfileId: String, managedTraineeProfileId: String, realTraineeProfileId: String) async throws {
        // no-op for previews/tests
    }
}

