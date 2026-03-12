//
//  MeasurementsListView.swift
//  TrainLog
//

import SwiftUI

struct MeasurementsListView: View {
    let profile: Profile
    let measurements: [Measurement]
    let onAddMeasurement: () -> Void
    let onDeleteMeasurement: (Measurement) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Добавить замер
                    Button(action: onAddMeasurement) {
                        AddActionRow(title: "Добавить замер", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(PressableButtonStyle())
                    .frame(maxWidth: .infinity)
                    .padding(AppDesign.cardPadding)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
                    .padding(.horizontal, AppDesign.cardPadding)
                    .padding(.top, AppDesign.blockSpacing)

                    // История замеров
                    SettingsCard(title: "История замеров") {
                        if measurements.isEmpty {
                            ContentUnavailableView(
                                "Пока нет замеров",
                                systemImage: "ruler.fill",
                                description: Text("Нажмите «Добавить замер» выше, чтобы записать первый замер.")
                            )
                            .padding(.vertical, 24)
                        } else {
                            let sorted = measurements.sorted { $0.date > $1.date }
                            VStack(spacing: 0) {
                                ForEach(Array(sorted.enumerated()), id: \.element.id) { index, m in
                                    NavigationLink {
                                        MeasurementDetailView(
                                            measurement: m,
                                            onDelete: { onDeleteMeasurement(m) }
                                        )
                                    } label: {
                                        MeasurementRow(measurement: m)
                                    }
                                    .buttonStyle(PressableButtonStyle())
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            onDeleteMeasurement(m)
                                        } label: {
                                            Label("Удалить", systemImage: "trash")
                                        }
                                    }
                                    if index != sorted.count - 1 { Divider() }
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Замеры")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct MeasurementRow: View {
    let measurement: Measurement

    private var dateFormatted: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.locale = Locale(identifier: "ru_RU")
        return f.string(from: measurement.date)
    }

    private var subtitle: String? {
        if let w = measurement.weight {
            return "Вес: \(w.measurementFormatted) кг"
        }
        return nil
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(dateFormatted)
                    .font(.headline)
                    .foregroundStyle(.primary)
                if let sub = subtitle {
                    Text(sub)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

struct MeasurementDetailView: View {
    let measurement: Measurement
    var onDelete: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    private var dateFormatted: String {
        let f = DateFormatter()
        f.dateStyle = .long
        f.locale = Locale(identifier: "ru_RU")
        return f.string(from: measurement.date)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SettingsCard(title: "Дата") {
                    Text(dateFormatted)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                SettingsCard(title: "Измерения") {
                    let rows = MeasurementType.allCases.compactMap { type -> (String, String)? in
                        guard let value = measurement.value(for: type) else { return nil }
                        return (type.displayName, "\(value.measurementFormatted) \(type.unit)")
                    }
                    if rows.isEmpty {
                        ContentUnavailableView(
                            "Нет данных",
                            systemImage: "ruler",
                            description: Text("В этом замере нет заполненных значений.")
                        )
                        .padding(.vertical, 24)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                                MeasurementValueRow(title: row.0, value: row.1)
                                if index != rows.count - 1 { Divider() }
                            }
                        }
                    }
                }

                if let note = measurement.note, !note.isEmpty {
                    SettingsCard(title: "Заметка") {
                        Text(note)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Замер")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Label("Назад", systemImage: "chevron.left")
                }
            }
            if onDelete != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        onDelete?()
                        dismiss()
                    } label: {
                        Label("Удалить", systemImage: "trash")
                    }
                }
            }
        }
    }
}

private struct MeasurementValueRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .foregroundStyle(.primary)
            Spacer(minLength: 12)
            Text(value)
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

#Preview {
    MeasurementsListView(
        profile: Profile(id: "1", userId: "u1", type: .trainee, name: "Мой дневник"),
        measurements: [],
        onAddMeasurement: {},
        onDeleteMeasurement: { _ in }
    )
}
