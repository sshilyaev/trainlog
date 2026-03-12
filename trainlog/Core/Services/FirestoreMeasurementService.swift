//
//  FirestoreMeasurementService.swift
//  TrainLog
//

import Foundation
import FirebaseFirestore

final class FirestoreMeasurementService: MeasurementServiceProtocol {
    private let measurements = Firestore.firestore().collection("measurements")

    func fetchMeasurements(profileId: String) async throws -> [Measurement] {
        let snapshot = try await measurements
            .whereField("profileId", isEqualTo: profileId)
            .order(by: "date", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            parseMeasurement(id: doc.documentID, data: doc.data())
        }
    }

    func saveMeasurement(_ measurement: Measurement) async throws {
        let ref = measurements.document(measurement.id)
        try await ref.setData(measurementToData(measurement))
    }

    func deleteMeasurement(_ measurement: Measurement) async throws {
        try await measurements.document(measurement.id).delete()
    }

    func deleteAllMeasurements(profileId: String) async throws {
        let snapshot = try await measurements
            .whereField("profileId", isEqualTo: profileId)
            .getDocuments()
        for doc in snapshot.documents {
            try await doc.reference.delete()
        }
    }

    private func measurementToData(_ m: Measurement) -> [String: Any] {
        var data: [String: Any] = [
            "profileId": m.profileId,
            "date": Timestamp(date: m.date)
        ]
        if let v = m.weight { data["weight"] = v }
        if let v = m.height { data["height"] = v }
        if let v = m.neck { data["neck"] = v }
        if let v = m.shoulders { data["shoulders"] = v }
        if let v = m.leftBiceps { data["leftBiceps"] = v }
        if let v = m.rightBiceps { data["rightBiceps"] = v }
        if let v = m.waist { data["waist"] = v }
        if let v = m.belly { data["belly"] = v }
        if let v = m.leftThigh { data["leftThigh"] = v }
        if let v = m.rightThigh { data["rightThigh"] = v }
        if let v = m.hips { data["hips"] = v }
        if let v = m.buttocks { data["buttocks"] = v }
        if let v = m.leftCalf { data["leftCalf"] = v }
        if let v = m.rightCalf { data["rightCalf"] = v }
        if let v = m.note { data["note"] = v }
        return data
    }

    private func parseMeasurement(id: String, data: [String: Any]) -> Measurement? {
        guard let profileId = data["profileId"] as? String,
              let dateStamp = data["date"] as? Timestamp else { return nil }
        let date = dateStamp.dateValue()

        func d(_ key: String) -> Double? {
            if let n = data[key] as? NSNumber { return n.doubleValue }
            return nil
        }

        return Measurement(
            id: id,
            profileId: profileId,
            date: date,
            weight: d("weight"),
            height: d("height"),
            neck: d("neck"),
            shoulders: d("shoulders"),
            leftBiceps: d("leftBiceps"),
            rightBiceps: d("rightBiceps"),
            waist: d("waist"),
            belly: d("belly"),
            leftThigh: d("leftThigh"),
            rightThigh: d("rightThigh"),
            hips: d("hips"),
            buttocks: d("buttocks"),
            leftCalf: d("leftCalf"),
            rightCalf: d("rightCalf"),
            note: data["note"] as? String
        )
    }
}
