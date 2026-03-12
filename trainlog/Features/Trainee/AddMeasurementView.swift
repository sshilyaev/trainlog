//
//  AddMeasurementView.swift
//  TrainLog
//

import SwiftUI
import UIKit

struct AddMeasurementView: View {
    let profile: Profile
    var lastMeasurement: Measurement?
    let onSave: (Measurement) async -> Void
    let onCancel: () -> Void

    @State private var date = Date()
    @State private var weight: String = ""
    @State private var height: String = ""
    @State private var neck: String = ""
    @State private var shoulders: String = ""
    @State private var leftBiceps: String = ""
    @State private var rightBiceps: String = ""
    @State private var waist: String = ""
    @State private var belly: String = ""
    @State private var leftThigh: String = ""
    @State private var rightThigh: String = ""
    @State private var hips: String = ""
    @State private var buttocks: String = ""
    @State private var leftCalf: String = ""
    @State private var rightCalf: String = ""
    @State private var note: String = ""
    @State private var isLoading = false

    private func parse(_ s: String) -> Double? {
        let n = s.replacingOccurrences(of: ",", with: ".")
        return Double(n)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    SettingsCard(title: "Дата") {
                        DatePicker("Дата замера", selection: $date, displayedComponents: .date)
                    }

                    SettingsCard(title: "Вес и рост") {
                        VStack(spacing: 12) {
                            MeasurementField(title: "Вес", value: $weight, unit: "кг", lastValue: lastMeasurement?.weight)
                            MeasurementField(title: "Рост", value: $height, unit: "см", lastValue: lastMeasurement?.height)
                        }
                    }

                    SettingsCard(title: "Верх") {
                        VStack(spacing: 12) {
                            MeasurementField(title: "Шея", value: $neck, unit: "см", lastValue: lastMeasurement?.neck)
                            MeasurementField(title: "Плечи", value: $shoulders, unit: "см", lastValue: lastMeasurement?.shoulders)
                            MeasurementField(title: "Бицепс (л)", value: $leftBiceps, unit: "см", lastValue: lastMeasurement?.leftBiceps)
                            MeasurementField(title: "Бицепс (п)", value: $rightBiceps, unit: "см", lastValue: lastMeasurement?.rightBiceps)
                        }
                    }

                    SettingsCard(title: "Торс") {
                        VStack(spacing: 12) {
                            MeasurementField(title: "Талия", value: $waist, unit: "см", lastValue: lastMeasurement?.waist)
                            MeasurementField(title: "Живот", value: $belly, unit: "см", lastValue: lastMeasurement?.belly)
                        }
                    }

                    SettingsCard(title: "Низ") {
                        VStack(spacing: 12) {
                            MeasurementField(title: "Бедро (л)", value: $leftThigh, unit: "см", lastValue: lastMeasurement?.leftThigh)
                            MeasurementField(title: "Бедро (п)", value: $rightThigh, unit: "см", lastValue: lastMeasurement?.rightThigh)
                            MeasurementField(title: "Бёдра", value: $hips, unit: "см", lastValue: lastMeasurement?.hips)
                            MeasurementField(title: "Ягодицы", value: $buttocks, unit: "см", lastValue: lastMeasurement?.buttocks)
                            MeasurementField(title: "Икра (л)", value: $leftCalf, unit: "см", lastValue: lastMeasurement?.leftCalf)
                            MeasurementField(title: "Икра (п)", value: $rightCalf, unit: "см", lastValue: lastMeasurement?.rightCalf)
                        }
                    }

                    SettingsCard(title: "Заметка") {
                        TextField("Заметка", text: $note, axis: .vertical)
                            .lineLimit(3...6)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .scrollDismissesKeyboard(.immediately)
            .dismissKeyboardOnTap()
            .navigationTitle("Новый замер")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        onCancel()
                    } label: {
                        Label("Назад", systemImage: "chevron.left")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.9)
                        } else {
                            Text("Сохранить")
                        }
                    }
                    .disabled(!hasAnyValue || isLoading)
                    .fontWeight(.semibold)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Готово") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
        }
    }

    private var hasAnyValue: Bool {
        [weight, height, neck, shoulders, leftBiceps, rightBiceps, waist, belly,
         leftThigh, rightThigh, hips, buttocks, leftCalf, rightCalf]
            .contains { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    private func save() async {
        isLoading = true
        defer { isLoading = false }

        let m = Measurement(
            id: UUID().uuidString,
            profileId: profile.id,
            date: date,
            weight: parse(weight),
            height: parse(height),
            neck: parse(neck),
            shoulders: parse(shoulders),
            leftBiceps: parse(leftBiceps),
            rightBiceps: parse(rightBiceps),
            waist: parse(waist),
            belly: parse(belly),
            leftThigh: parse(leftThigh),
            rightThigh: parse(rightThigh),
            hips: parse(hips),
            buttocks: parse(buttocks),
            leftCalf: parse(leftCalf),
            rightCalf: parse(rightCalf),
            note: note.isEmpty ? nil : note
        )
        await onSave(m)
    }
}

struct MeasurementField: View {
    let title: String
    @Binding var value: String
    let unit: String
    var lastValue: Double?

    private var placeholder: String {
        if let last = lastValue {
            return last.measurementFormatted
        }
        return unit
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer(minLength: 8)
            TextField(placeholder, text: $value)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.subheadline)
                .textFieldStyle(.roundedBorder)
                .frame(width: 100)
        }
        .environment(\.locale, Locale(identifier: "ru_RU"))
    }
}

#Preview {
    AddMeasurementView(
        profile: Profile(id: "1", userId: "u1", type: .trainee, name: "Мой дневник"),
        lastMeasurement: nil,
        onSave: { _ in },
        onCancel: {}
    )
}
