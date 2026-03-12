//
//  GoalService.swift
//  TrainLog
//

import Foundation

protocol GoalServiceProtocol {
    func fetchGoals(profileId: String) async throws -> [Goal]
    func saveGoal(_ goal: Goal) async throws
    func deleteGoal(_ goal: Goal) async throws
    func deleteAllGoals(profileId: String) async throws
}
