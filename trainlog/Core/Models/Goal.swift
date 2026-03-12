//
//  Goal.swift
//  TrainLog
//

import Foundation

struct Goal: Identifiable, Codable, Equatable {
    let id: String
    let profileId: String
    let measurementType: String
    let targetValue: Double
    let targetDate: Date
    let createdAt: Date

    init(
        id: String,
        profileId: String,
        measurementType: String,
        targetValue: Double,
        targetDate: Date,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.profileId = profileId
        self.measurementType = measurementType
        self.targetValue = targetValue
        self.targetDate = targetDate
        self.createdAt = createdAt
    }

    var type: MeasurementType? {
        MeasurementType(rawValue: measurementType)
    }
}
