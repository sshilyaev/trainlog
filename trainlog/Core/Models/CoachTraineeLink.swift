//
//  CoachTraineeLink.swift
//  TrainLog
//

import Foundation

struct CoachTraineeLink: Identifiable, Equatable {
    let id: String
    let coachProfileId: String
    let traineeProfileId: String
    let createdAt: Date
    /// Имя для отображения в списке у тренера (если задано — подставляется вместо имени из профиля).
    var displayName: String?
    /// Заметка тренера о подопечном.
    var note: String?
    /// В архиве — отображаются внизу списка подопечных.
    var isArchived: Bool

    init(
        id: String,
        coachProfileId: String,
        traineeProfileId: String,
        createdAt: Date = Date(),
        displayName: String? = nil,
        note: String? = nil,
        isArchived: Bool = false
    ) {
        self.id = id
        self.coachProfileId = coachProfileId
        self.traineeProfileId = traineeProfileId
        self.createdAt = createdAt
        self.displayName = displayName
        self.note = note
        self.isArchived = isArchived
    }
}
