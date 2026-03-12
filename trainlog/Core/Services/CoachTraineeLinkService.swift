//
//  CoachTraineeLinkService.swift
//  TrainLog
//

import Foundation

protocol CoachTraineeLinkServiceProtocol {
    /// Связи тренера с подопечными (включая displayName и note).
    func fetchLinks(coachProfileId: String) async throws -> [CoachTraineeLink]
    /// Связи подопечного с тренерами (для экрана «Посещения» у клиента).
    func fetchLinksForTrainee(traineeProfileId: String) async throws -> [CoachTraineeLink]
    /// Список id профилей подопечных (для обратной совместимости).
    func fetchTraineeProfileIds(coachProfileId: String) async throws -> [String]
    /// Привязать подопечного к тренеру с опциональными именем и заметкой.
    func addLink(coachProfileId: String, traineeProfileId: String, displayName: String?, note: String?) async throws
    /// Отвязать подопечного от тренера.
    func removeLink(coachProfileId: String, traineeProfileId: String) async throws
    /// Архивировать или вернуть из архива. Архивированные отображаются внизу списка.
    func setArchived(coachProfileId: String, traineeProfileId: String, isArchived: Bool) async throws
}
