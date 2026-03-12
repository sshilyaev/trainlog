//
//  GoalsListView.swift
//  TrainLog
//

import SwiftUI

struct GoalsListView: View {
    let profile: Profile
    let goals: [Goal]
    let onAddGoal: () -> Void
    let onDeleteGoal: (Goal) -> Void

    private static var dateGroupFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .long
        f.locale = Locale(identifier: "ru_RU")
        return f
    }

    private var goalsByDate: [(date: Date, goals: [Goal])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: goals) { calendar.startOfDay(for: $0.targetDate) }
        return grouped
            .map { (date: $0.key, goals: $0.value.sorted { $0.targetDate < $1.targetDate }) }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    Button(action: onAddGoal) {
                        AddActionRow(title: "Добавить цель", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(PressableButtonStyle())
                    .frame(maxWidth: .infinity)
                    .padding(AppDesign.cardPadding)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
                    .padding(.horizontal, AppDesign.cardPadding)
                    .padding(.top, AppDesign.blockSpacing)

                    if goals.isEmpty {
                        SettingsCard(title: "Цели") {
                            ContentUnavailableView(
                                "Пока нет целей",
                                systemImage: "target",
                                description: Text("Нажмите «Добавить цель» выше, чтобы задать целевую метрику и дату.")
                            )
                            .padding(.vertical, 24)
                        }
                    } else {
                        ForEach(goalsByDate, id: \.date) { group in
                            SettingsCard(title: Self.dateGroupFormatter.string(from: group.date)) {
                                VStack(spacing: 0) {
                                    ForEach(Array(group.goals.enumerated()), id: \.element.id) { index, goal in
                                        GoalBlockView(goal: goal, onDelete: { onDeleteGoal(goal) })
                                        if index != group.goals.count - 1 { Divider() }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Цели")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct GoalBlockView: View {
    let goal: Goal
    let onDelete: () -> Void

    private var typeName: String {
        goal.type?.displayName ?? "Цель"
    }

    private var valueText: String {
        "\(goal.targetValue.measurementFormatted) \(goal.type?.unit ?? "")"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(typeName)
                .font(.headline)
                .foregroundStyle(.primary)
            HStack {
                Text("Значение")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(valueText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 0.5) {
            onDelete()
        }
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Удалить", systemImage: "trash")
            }
        }
    }
}

#Preview {
    GoalsListView(
        profile: Profile(id: "1", userId: "u1", type: .trainee, name: "Мой дневник"),
        goals: [
            Goal(id: "1", profileId: "p1", measurementType: "weight", targetValue: 75, targetDate: Date().addingTimeInterval(86400 * 30), createdAt: Date())
        ],
        onAddGoal: {},
        onDeleteGoal: { _ in }
    )
}
