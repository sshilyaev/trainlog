//
//  MockCoachTraineeLinkService.swift
//  TrainLog
//

import Foundation

final class MockCoachTraineeLinkService: CoachTraineeLinkServiceProtocol {
    private var storage: [CoachTraineeLink] = []

    func fetchTraineeProfileIds(coachProfileId: String) async throws -> [String] {
        let links = try await fetchLinks(coachProfileId: coachProfileId)
        return links.map(\.traineeProfileId)
    }

    func fetchLinks(coachProfileId: String) async throws -> [CoachTraineeLink] {
        try await Task.sleep(nanoseconds: 150_000_000)
        return storage.filter { $0.coachProfileId == coachProfileId }
    }

    func fetchLinksForTrainee(traineeProfileId: String) async throws -> [CoachTraineeLink] {
        try await Task.sleep(nanoseconds: 100_000_000)
        return storage.filter { $0.traineeProfileId == traineeProfileId }
    }

    func addLink(coachProfileId: String, traineeProfileId: String, displayName: String?, note: String?) async throws {
        try await Task.sleep(nanoseconds: 100_000_000)
        let id = UUID().uuidString
        storage.append(CoachTraineeLink(
            id: id,
            coachProfileId: coachProfileId,
            traineeProfileId: traineeProfileId,
            createdAt: Date(),
            displayName: displayName,
            note: note,
            isArchived: false
        ))
    }

    func removeLink(coachProfileId: String, traineeProfileId: String) async throws {
        try await Task.sleep(nanoseconds: 100_000_000)
        storage.removeAll {
            $0.coachProfileId == coachProfileId && $0.traineeProfileId == traineeProfileId
        }
    }

    func setArchived(coachProfileId: String, traineeProfileId: String, isArchived: Bool) async throws {
        try await Task.sleep(nanoseconds: 100_000_000)
        if let idx = storage.firstIndex(where: { $0.coachProfileId == coachProfileId && $0.traineeProfileId == traineeProfileId }) {
            var link = storage[idx]
            link.isArchived = isArchived
            storage[idx] = link
        }
    }
}
