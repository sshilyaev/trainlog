//
//  AddGoalView.swift
//  TrainLog
//

import SwiftUI
import UIKit

struct AddGoalView: View {
    let profile: Profile
    let onSave: ([Goal]) -> Void
    let onCancel: () -> Void

    @State private var targetDate = Date()
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
    @State private var isLoading = false

    private func parse(_ s: String) -> Double? {
        let n = s.replacingOccurrences(of: ",", with: ".")
        return Double(n)
    }

    private var hasAnyValue: Bool {
        [weight, height, neck, shoulders, leftBiceps, rightBiceps, waist, belly,
         leftThigh, rightThigh, hips, buttocks, leftCalf, rightCalf]
            .contains { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    SettingsCard(title: "Целевая дата") {
                        DatePicker("Дата", selection: $targetDate, displayedComponents: .date)
                    }

                    Text("Не обязательно заполнять все поля — укажите целевые значения только по нужным метрикам.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 4)

                    SettingsCard(title: "Вес и рост") {
                        VStack(spacing: 12) {
                            MeasurementField(title: "Вес", value: $weight, unit: "кг", lastValue: nil)
                            MeasurementField(title: "Рост", value: $height, unit: "см", lastValue: nil)
                        }
                    }

                    SettingsCard(title: "Верх") {
                        VStack(spacing: 12) {
                            MeasurementField(title: "Шея", value: $neck, unit: "см", lastValue: nil)
                            MeasurementField(title: "Плечи", value: $shoulders, unit: "см", lastValue: nil)
                            MeasurementField(title: "Бицепс (л)", value: $leftBiceps, unit: "см", lastValue: nil)
                            MeasurementField(title: "Бицепс (п)", value: $rightBiceps, unit: "см", lastValue: nil)
                        }
                    }

                    SettingsCard(title: "Торс") {
                        VStack(spacing: 12) {
                            MeasurementField(title: "Талия", value: $waist, unit: "см", lastValue: nil)
                            MeasurementField(title: "Живот", value: $belly, unit: "см", lastValue: nil)
                        }
                    }

                    SettingsCard(title: "Низ") {
                        VStack(spacing: 12) {
                            MeasurementField(title: "Бедро (л)", value: $leftThigh, unit: "см", lastValue: nil)
                            MeasurementField(title: "Бедро (п)", value: $rightThigh, unit: "см", lastValue: nil)
                            MeasurementField(title: "Бёдра", value: $hips, unit: "см", lastValue: nil)
                            MeasurementField(title: "Ягодицы", value: $buttocks, unit: "см", lastValue: nil)
                            MeasurementField(title: "Икра (л)", value: $leftCalf, unit: "см", lastValue: nil)
                            MeasurementField(title: "Икра (п)", value: $rightCalf, unit: "см", lastValue: nil)
                        }
                    }
                }
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .scrollDismissesKeyboard(.immediately)
            .dismissKeyboardOnTap()
            .navigationTitle("Новая цель")
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
                        save()
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
        .environment(\.locale, Locale(identifier: "ru_RU"))
    }

    private func save() {
        guard hasAnyValue else { return }
        isLoading = true
        defer { isLoading = false }

        let pairs: [(MeasurementType, String)] = [
            (.weight, weight), (.height, height), (.neck, neck), (.shoulders, shoulders),
            (.leftBiceps, leftBiceps), (.rightBiceps, rightBiceps), (.waist, waist), (.belly, belly),
            (.leftThigh, leftThigh), (.rightThigh, rightThigh), (.hips, hips), (.buttocks, buttocks),
            (.leftCalf, leftCalf), (.rightCalf, rightCalf)
        ]
        var goals: [Goal] = []
        for (type, str) in pairs {
            guard let value = parse(str), !str.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
            goals.append(Goal(
                id: UUID().uuidString,
                profileId: profile.id,
                measurementType: type.rawValue,
                targetValue: value,
                targetDate: targetDate,
                createdAt: Date()
            ))
        }
        if !goals.isEmpty {
            onSave(goals)
        }
    }
}

#Preview {
    AddGoalView(
        profile: Profile(id: "1", userId: "u1", type: .trainee, name: "Мой дневник"),
        onSave: { _ in },
        onCancel: {}
    )
}
