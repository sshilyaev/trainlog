//
//  VisitService.swift
//  TrainLog
//

import Foundation

protocol VisitServiceProtocol {
    func fetchVisits(coachProfileId: String, traineeProfileId: String) async throws -> [Visit]
    func createVisit(coachProfileId: String, traineeProfileId: String, date: Date) async throws -> Visit
    func updateVisit(_ visit: Visit) async throws

    /// Отметить визит как проведённый. Если есть доступные занятия абонемента — списать одно.
    func markVisitDone(_ visit: Visit) async throws

    /// Отметить визит как проведённый и списать занятие с указанного абонемента.
    func markVisitDoneWithMembership(_ visit: Visit, membershipId: String) async throws

    /// Отметить оплату вручную (для долга/разового визита).
    func markVisitPaid(_ visit: Visit) async throws

    /// Списать долговой визит с указанного абонемента (вычесть занятие и привязать визит к абонементу).
    func markVisitPaidWithMembership(_ visit: Visit, membershipId: String) async throws

    /// Отменить визит: пометить cancelled, убрать оплату и привязку к абонементу (если была).
    /// Если визит был списан с абонемента — вернуть занятие обратно.
    func cancelVisit(_ visit: Visit) async throws
}

