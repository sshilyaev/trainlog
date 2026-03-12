//
//  Measurement.swift
//  TrainLog
//

import Foundation

struct Measurement: Identifiable, Codable, Equatable {
    let id: String
    let profileId: String
    let date: Date
    var weight: Double?
    var height: Double?
    var neck: Double?
    var shoulders: Double?
    var leftBiceps: Double?
    var rightBiceps: Double?
    var waist: Double?
    var belly: Double?
    var leftThigh: Double?
    var rightThigh: Double?
    var hips: Double?
    var buttocks: Double?
    var leftCalf: Double?
    var rightCalf: Double?
    var note: String?

    init(
        id: String,
        profileId: String,
        date: Date,
        weight: Double? = nil,
        height: Double? = nil,
        neck: Double? = nil,
        shoulders: Double? = nil,
        leftBiceps: Double? = nil,
        rightBiceps: Double? = nil,
        waist: Double? = nil,
        belly: Double? = nil,
        leftThigh: Double? = nil,
        rightThigh: Double? = nil,
        hips: Double? = nil,
        buttocks: Double? = nil,
        leftCalf: Double? = nil,
        rightCalf: Double? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.profileId = profileId
        self.date = date
        self.weight = weight
        self.height = height
        self.neck = neck
        self.shoulders = shoulders
        self.leftBiceps = leftBiceps
        self.rightBiceps = rightBiceps
        self.waist = waist
        self.belly = belly
        self.leftThigh = leftThigh
        self.rightThigh = rightThigh
        self.hips = hips
        self.buttocks = buttocks
        self.leftCalf = leftCalf
        self.rightCalf = rightCalf
        self.note = note
    }
}

// MARK: - Measurement Types for Charts & Goals

enum MeasurementType: String, CaseIterable, Identifiable {
    case weight
    case height
    case neck
    case shoulders
    case leftBiceps
    case rightBiceps
    case waist
    case belly
    case leftThigh
    case rightThigh
    case hips
    case buttocks
    case leftCalf
    case rightCalf

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .weight: return "Вес"
        case .height: return "Рост"
        case .neck: return "Шея"
        case .shoulders: return "Плечи"
        case .leftBiceps: return "Бицепс (л)"
        case .rightBiceps: return "Бицепс (п)"
        case .waist: return "Талия"
        case .belly: return "Живот"
        case .leftThigh: return "Бедро (л)"
        case .rightThigh: return "Бедро (п)"
        case .hips: return "Бёдра"
        case .buttocks: return "Ягодицы"
        case .leftCalf: return "Икра (л)"
        case .rightCalf: return "Икра (п)"
        }
    }

    var unit: String {
        self == .weight ? "кг" : "см"
    }

    func value(from measurement: Measurement) -> Double? {
        switch self {
        case .weight: return measurement.weight
        case .height: return measurement.height
        case .neck: return measurement.neck
        case .shoulders: return measurement.shoulders
        case .leftBiceps: return measurement.leftBiceps
        case .rightBiceps: return measurement.rightBiceps
        case .waist: return measurement.waist
        case .belly: return measurement.belly
        case .leftThigh: return measurement.leftThigh
        case .rightThigh: return measurement.rightThigh
        case .hips: return measurement.hips
        case .buttocks: return measurement.buttocks
        case .leftCalf: return measurement.leftCalf
        case .rightCalf: return measurement.rightCalf
        }
    }
}

extension Measurement {
    func value(for type: MeasurementType) -> Double? {
        type.value(from: self)
    }
}
