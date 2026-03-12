//
//  MockGoalService.swift
//  TrainLog
//

import Foundation

final class MockGoalService: GoalServiceProtocol {
    private var storage: [Goal] = []

    func fetchGoals(profileId: String) async throws -> [Goal] {
        try await Task.sleep(nanoseconds: 200_000_000)
        return storage.filter { $0.profileId == profileId }
    }

    func saveGoal(_ goal: Goal) async throws {
        storage.removeAll { $0.id == goal.id }
        storage.append(goal)
    }

    func deleteGoal(_ goal: Goal) async throws {
        storage.removeAll { $0.id == goal.id }
    }

    func deleteAllGoals(profileId: String) async throws {
        storage.removeAll { $0.profileId == profileId }
    }
}
