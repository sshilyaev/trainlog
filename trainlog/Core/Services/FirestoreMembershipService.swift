//
//  FirestoreMembershipService.swift
//  TrainLog
//

import Foundation
import FirebaseFirestore

final class FirestoreMembershipService: MembershipServiceProtocol {
    private let memberships = Firestore.firestore().collection("memberships")

    func fetchActiveMembership(coachProfileId: String, traineeProfileId: String) async throws -> Membership? {
        let snapshot = try await memberships
            .whereField("coachProfileId", isEqualTo: coachProfileId)
            .whereField("traineeProfileId", isEqualTo: traineeProfileId)
            .whereField("status", isEqualTo: MembershipStatus.active.rawValue)
            .order(by: "createdAt", descending: true)
            .limit(to: 5)
            .getDocuments()

        let list = snapshot.documents.compactMap { doc in
            parseMembership(id: doc.documentID, data: doc.data())
        }
        return list.first(where: { $0.remainingSessions > 0 }) ?? list.first
    }

    func fetchMemberships(coachProfileId: String, traineeProfileId: String) async throws -> [Membership] {
        let snapshot = try await memberships
            .whereField("coachProfileId", isEqualTo: coachProfileId)
            .whereField("traineeProfileId", isEqualTo: traineeProfileId)
            .getDocuments()

        let list = snapshot.documents.compactMap { doc in
            parseMembership(id: doc.documentID, data: doc.data())
        }
        return list.sorted { $0.createdAt > $1.createdAt }
    }

    func createMembership(coachProfileId: String, traineeProfileId: String, totalSessions: Int, priceRub: Int?) async throws -> Membership {
        let existing = try await fetchMemberships(coachProfileId: coachProfileId, traineeProfileId: traineeProfileId)
        let nextNumber = existing.count + 1
        let displayCode = Self.displayCode(for: nextNumber)

        let createdAt = Date()
        var data: [String: Any] = [
            "coachProfileId": coachProfileId,
            "traineeProfileId": traineeProfileId,
            "createdAt": Timestamp(date: createdAt),
            "totalSessions": max(0, totalSessions),
            "usedSessions": 0,
            "status": MembershipStatus.active.rawValue,
            "displayCode": displayCode
        ]
        if let p = priceRub { data["priceRub"] = p }
        let ref = try await memberships.addDocument(data: data)
        return Membership(
            id: ref.documentID,
            coachProfileId: coachProfileId,
            traineeProfileId: traineeProfileId,
            createdAt: createdAt,
            totalSessions: totalSessions,
            usedSessions: 0,
            priceRub: priceRub,
            status: .active,
            displayCode: displayCode
        )
    }

    /// Формат: только порядковый номер — "1", "2", "3", …
    private static func displayCode(for number: Int) -> String {
        "\(max(1, number))"
    }

    func updateMembership(_ membership: Membership) async throws {
        var data: [String: Any] = [
            "coachProfileId": membership.coachProfileId,
            "traineeProfileId": membership.traineeProfileId,
            "createdAt": Timestamp(date: membership.createdAt),
            "totalSessions": max(0, membership.totalSessions),
            "usedSessions": max(0, membership.usedSessions),
            "status": membership.status.rawValue
        ]
        if let p = membership.priceRub { data["priceRub"] = p }
        if let code = membership.displayCode { data["displayCode"] = code }
        try await memberships.document(membership.id).setData(data)
    }

    private func parseMembership(id: String, data: [String: Any]) -> Membership? {
        guard let coachProfileId = data["coachProfileId"] as? String,
              let traineeProfileId = data["traineeProfileId"] as? String else { return nil }

        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let totalSessions = (data["totalSessions"] as? NSNumber)?.intValue ?? 0
        let usedSessions = (data["usedSessions"] as? NSNumber)?.intValue ?? 0
        let priceRub = (data["priceRub"] as? NSNumber)?.intValue
        let statusRaw = data["status"] as? String
        let status = statusRaw.flatMap { MembershipStatus(rawValue: $0) } ?? .active
        let displayCode = data["displayCode"] as? String

        return Membership(
            id: id,
            coachProfileId: coachProfileId,
            traineeProfileId: traineeProfileId,
            createdAt: createdAt,
            totalSessions: totalSessions,
            usedSessions: usedSessions,
            priceRub: priceRub,
            status: status,
            displayCode: displayCode
        )
    }
}

