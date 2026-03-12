//
//  MeasurementService.swift
//  TrainLog
//

import Foundation

protocol MeasurementServiceProtocol {
    func fetchMeasurements(profileId: String) async throws -> [Measurement]
    func saveMeasurement(_ measurement: Measurement) async throws
    func deleteMeasurement(_ measurement: Measurement) async throws
    func deleteAllMeasurements(profileId: String) async throws
}
