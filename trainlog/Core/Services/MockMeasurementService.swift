//
//  MockMeasurementService.swift
//  TrainLog
//

import Foundation

final class MockMeasurementService: MeasurementServiceProtocol {
    private var storage: [Measurement] = []

    func fetchMeasurements(profileId: String) async throws -> [Measurement] {
        try await Task.sleep(nanoseconds: 200_000_000)
        return storage.filter { $0.profileId == profileId }
    }

    func saveMeasurement(_ measurement: Measurement) async throws {
        storage.removeAll { $0.id == measurement.id }
        storage.append(measurement)
    }

    func deleteMeasurement(_ measurement: Measurement) async throws {
        storage.removeAll { $0.id == measurement.id }
    }

    func deleteAllMeasurements(profileId: String) async throws {
        storage.removeAll { $0.profileId == profileId }
    }
}
