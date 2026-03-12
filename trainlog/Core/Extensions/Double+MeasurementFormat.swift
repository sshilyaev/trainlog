//
//  Double+MeasurementFormat.swift
//  TrainLog
//

import Foundation

extension Double {
    /// Форматирование значений замеров: 66, 66.5, 66.11 — без лишних нулей.
    var measurementFormatted: String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.decimalSeparator = ","
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}
