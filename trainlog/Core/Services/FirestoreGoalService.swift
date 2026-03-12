//
//  FirestoreGoalService.swift
//  TrainLog
//

import Foundation
import FirebaseFirestore

final class FirestoreGoalService: GoalServiceProtocol {
    private let goals = Firestore.firestore().collection("goals")

    func fetchGoals(profileId: String) async throws -> [Goal] {
        let snapshot = try await goals
            .whereField("profileId", isEqualTo: profileId)
            .order(by: "targetDate")
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            parseGoal(id: doc.documentID, data: doc.data())
        }
    }

    func saveGoal(_ goal: Goal) async throws {
        let ref = goals.document(goal.id)
        try await ref.setData([
            "profileId": goal.profileId,
            "measurementType": goal.measurementType,
            "targetValue": goal.targetValue,
            "targetDate": Timestamp(date: goal.targetDate),
            "createdAt": Timestamp(date: goal.createdAt)
        ])
    }

    func deleteGoal(_ goal: Goal) async throws {
        try await goals.document(goal.id).delete()
    }

    func deleteAllGoals(profileId: String) async throws {
        let snapshot = try await goals
            .whereField("profileId", isEqualTo: profileId)
            .getDocuments()
        for doc in snapshot.documents {
            try await doc.reference.delete()
        }
    }

    private func parseGoal(id: String, data: [String: Any]) -> Goal? {
        guard let profileId = data["profileId"] as? String,
              let measurementType = data["measurementType"] as? String,
              let targetValue = data["targetValue"] as? NSNumber,
              let targetDateStamp = data["targetDate"] as? Timestamp else { return nil }
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        return Goal(
            id: id,
            profileId: profileId,
            measurementType: measurementType,
            targetValue: targetValue.doubleValue,
            targetDate: targetDateStamp.dateValue(),
            createdAt: createdAt
        )
    }
}
