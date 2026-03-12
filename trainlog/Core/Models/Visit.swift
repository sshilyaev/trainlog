//
//  Visit.swift
//  TrainLog
//

import Foundation

enum VisitStatus: String, Codable, CaseIterable {
    case planned
    case done
    case cancelled
    case noShow
}

enum VisitPaymentStatus: String, Codable, CaseIterable {
    /// Используется для разовых визитов (или визитов в долг) до отметки оплаты.
    case unpaid
    /// Визит оплачен (либо абонементом, либо вручную отмечен тренером).
    case paid
    /// Визит в долг (абонемент закончился/отсутствует).
    case debt
}

/// Посещение ведёт тренер. При `done` списывается занятие с активного абонемента,
/// иначе визит помечается как долг/неоплаченный.
struct Visit: Identifiable, Codable, Equatable {
    let id: String
    let coachProfileId: String
    let traineeProfileId: String
    let createdAt: Date
    var date: Date
    var status: VisitStatus
    var paymentStatus: VisitPaymentStatus
    /// Если визит списан с абонемента — ссылка на него.
    var membershipId: String?
    /// Номер абонемента для отображения (например "A1"), заполняется при списании с абонемента.
    var membershipDisplayCode: String?

    init(
        id: String,
        coachProfileId: String,
        traineeProfileId: String,
        createdAt: Date = Date(),
        date: Date,
        status: VisitStatus = .planned,
        paymentStatus: VisitPaymentStatus = .unpaid,
        membershipId: String? = nil,
        membershipDisplayCode: String? = nil
    ) {
        self.id = id
        self.coachProfileId = coachProfileId
        self.traineeProfileId = traineeProfileId
        self.createdAt = createdAt
        self.date = date
        self.status = status
        self.paymentStatus = paymentStatus
        self.membershipId = membershipId
        self.membershipDisplayCode = membershipDisplayCode
    }
}

