//
//  Membership.swift
//  TrainLog
//

import Foundation

enum MembershipStatus: String, Codable, CaseIterable {
    case active
    case finished
    case cancelled
}

/// Абонемент на N занятий, покупается и оплачивается целиком.
struct Membership: Identifiable, Codable, Equatable {
    let id: String
    let coachProfileId: String
    let traineeProfileId: String
    let createdAt: Date
    var totalSessions: Int
    var usedSessions: Int
    /// Информационное поле, не влияет на списание.
    var priceRub: Int?
    var status: MembershipStatus
    /// Номер абонемента для отображения (порядковый номер), например "1", "2".
    var displayCode: String?

    init(
        id: String,
        coachProfileId: String,
        traineeProfileId: String,
        createdAt: Date = Date(),
        totalSessions: Int,
        usedSessions: Int = 0,
        priceRub: Int? = nil,
        status: MembershipStatus = .active,
        displayCode: String? = nil
    ) {
        self.id = id
        self.coachProfileId = coachProfileId
        self.traineeProfileId = traineeProfileId
        self.createdAt = createdAt
        self.totalSessions = max(0, totalSessions)
        self.usedSessions = max(0, usedSessions)
        self.priceRub = priceRub
        self.status = status
        self.displayCode = displayCode
    }

    var remainingSessions: Int {
        max(0, totalSessions - usedSessions)
    }

    var isActive: Bool {
        status == .active && remainingSessions > 0
    }
}

