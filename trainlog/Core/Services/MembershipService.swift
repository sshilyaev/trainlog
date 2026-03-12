//
//  MembershipService.swift
//  TrainLog
//

import Foundation

protocol MembershipServiceProtocol {
    /// Активный абонемент (если есть).
    func fetchActiveMembership(coachProfileId: String, traineeProfileId: String) async throws -> Membership?
    /// Все абонементы клиента у конкретного тренера (включая завершённые).
    func fetchMemberships(coachProfileId: String, traineeProfileId: String) async throws -> [Membership]
    /// Создать новый абонемент (оплачен целиком).
    func createMembership(coachProfileId: String, traineeProfileId: String, totalSessions: Int, priceRub: Int?) async throws -> Membership
    func updateMembership(_ membership: Membership) async throws
}

