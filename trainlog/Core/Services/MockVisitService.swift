//
//  MockVisitService.swift
//  TrainLog
//

import Foundation

final class MockVisitService: VisitServiceProtocol {
    private var store: [Visit] = []
    private let membershipService: MembershipServiceProtocol

    init(membershipService: MembershipServiceProtocol = MockMembershipService()) {
        self.membershipService = membershipService
    }

    func fetchVisits(coachProfileId: String, traineeProfileId: String) async throws -> [Visit] {
        store
            .filter { $0.coachProfileId == coachProfileId && $0.traineeProfileId == traineeProfileId }
            .sorted { $0.date > $1.date }
    }

    func createVisit(coachProfileId: String, traineeProfileId: String, date: Date) async throws -> Visit {
        let v = Visit(
            id: UUID().uuidString,
            coachProfileId: coachProfileId,
            traineeProfileId: traineeProfileId,
            date: date
        )
        store.append(v)
        return v
    }

    func updateVisit(_ visit: Visit) async throws {
        if let idx = store.firstIndex(where: { $0.id == visit.id }) {
            store[idx] = visit
        } else {
            store.append(visit)
        }
    }

    func markVisitDone(_ visit: Visit) async throws {
        var updated = visit
        updated.status = .done

        if let m = try await membershipService.fetchActiveMembership(coachProfileId: visit.coachProfileId, traineeProfileId: visit.traineeProfileId),
           m.remainingSessions > 0 {
            updated.paymentStatus = .paid
            updated.membershipId = m.id
            updated.membershipDisplayCode = m.displayCode
        } else {
            updated.paymentStatus = .debt
            updated.membershipId = nil
        }
        try await updateVisit(updated)
    }

    func markVisitDoneWithMembership(_ visit: Visit, membershipId: String) async throws {
        var updated = visit
        updated.status = .done
        let memberships = try await membershipService.fetchMemberships(coachProfileId: visit.coachProfileId, traineeProfileId: visit.traineeProfileId)
        guard let m = memberships.first(where: { $0.id == membershipId && $0.remainingSessions > 0 }) else {
            updated.paymentStatus = .debt
            try await updateVisit(updated)
            return
        }
        updated.paymentStatus = .paid
        updated.membershipId = m.id
        updated.membershipDisplayCode = m.displayCode
        var updatedMembership = m
        updatedMembership.usedSessions += 1
        if updatedMembership.usedSessions >= updatedMembership.totalSessions {
            updatedMembership.status = .finished
        }
        try await membershipService.updateMembership(updatedMembership)
        try await updateVisit(updated)
    }

    func markVisitPaid(_ visit: Visit) async throws {
        var updated = visit
        updated.paymentStatus = .paid
        try await updateVisit(updated)
    }

    func markVisitPaidWithMembership(_ visit: Visit, membershipId: String) async throws {
        guard visit.paymentStatus == .debt else { return }
        guard let m = try await membershipService.fetchMemberships(coachProfileId: visit.coachProfileId, traineeProfileId: visit.traineeProfileId)
            .first(where: { $0.id == membershipId }),
              m.remainingSessions > 0 else { return }
        var updatedMembership = m
        updatedMembership.usedSessions += 1
        if updatedMembership.usedSessions >= updatedMembership.totalSessions {
            updatedMembership.status = .finished
        }
        try await membershipService.updateMembership(updatedMembership)
        var updatedVisit = visit
        updatedVisit.paymentStatus = .paid
        updatedVisit.membershipId = m.id
        updatedVisit.membershipDisplayCode = m.displayCode
        try await updateVisit(updatedVisit)
    }

    func cancelVisit(_ visit: Visit) async throws {
        var updated = visit

        if visit.status == .done, visit.paymentStatus == .paid, let mId = visit.membershipId {
            if let m = try await membershipService.fetchMemberships(coachProfileId: visit.coachProfileId, traineeProfileId: visit.traineeProfileId)
                .first(where: { $0.id == mId }) {
                var updatedMembership = m
                updatedMembership.usedSessions = max(0, updatedMembership.usedSessions - 1)
                if updatedMembership.status == .finished, updatedMembership.remainingSessions > 0 {
                    updatedMembership.status = .active
                }
                try await membershipService.updateMembership(updatedMembership)
            }
        }

        updated.status = .cancelled
        updated.paymentStatus = .unpaid
        updated.membershipId = nil
        updated.membershipDisplayCode = nil
        try await updateVisit(updated)
    }
}

