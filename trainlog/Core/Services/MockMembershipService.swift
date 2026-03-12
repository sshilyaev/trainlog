//
//  MockMembershipService.swift
//  TrainLog
//

import Foundation

final class MockMembershipService: MembershipServiceProtocol {
    private var store: [Membership] = []

    func fetchActiveMembership(coachProfileId: String, traineeProfileId: String) async throws -> Membership? {
        store
            .filter { $0.coachProfileId == coachProfileId && $0.traineeProfileId == traineeProfileId }
            .sorted { $0.createdAt > $1.createdAt }
            .first(where: { $0.isActive })
    }

    func fetchMemberships(coachProfileId: String, traineeProfileId: String) async throws -> [Membership] {
        store
            .filter { $0.coachProfileId == coachProfileId && $0.traineeProfileId == traineeProfileId }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func createMembership(coachProfileId: String, traineeProfileId: String, totalSessions: Int, priceRub: Int?) async throws -> Membership {
        let existing = try await fetchMemberships(coachProfileId: coachProfileId, traineeProfileId: traineeProfileId)
        let displayCode = Self.displayCode(for: existing.count + 1)
        let m = Membership(
            id: UUID().uuidString,
            coachProfileId: coachProfileId,
            traineeProfileId: traineeProfileId,
            totalSessions: totalSessions,
            usedSessions: 0,
            priceRub: priceRub,
            status: .active,
            displayCode: displayCode
        )
        store.append(m)
        return m
    }

    private static func displayCode(for number: Int) -> String {
        "\(max(1, number))"
    }

    func updateMembership(_ membership: Membership) async throws {
        if let idx = store.firstIndex(where: { $0.id == membership.id }) {
            store[idx] = membership
        } else {
            store.append(membership)
        }
    }
}

