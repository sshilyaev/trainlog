//
//  DashboardView.swift
//  TrainLog
//

import SwiftUI

/// Экран замеров и графиков. Для подопечного — с кнопкой «Добавить замер», для тренера (просмотр подопечного) — без неё.
struct DashboardView: View {
    let profile: Profile
    let measurements: [Measurement]
    let goals: [Goal]
    let onAddMeasurement: () -> Void
    let onDeleteMeasurement: (Measurement) -> Void
    /// Показывать блок «Добавить замер». Для тренера (просмотр подопечного) — false.
    var showAddMeasurementButton: Bool = true
    /// Оборачивать в NavigationStack. Для push из ClientCardView — false.
    var embedInNavigationStack: Bool = true
    var navigationTitle: String = "Мои замеры"

    @State private var displayMode: ChartDisplayMode = .bar
    @State private var chartColorIndex: Int = 0
    @State private var chartPeriod: ChartPeriod = .month

    /// Метрики, по которым есть хотя бы один замер.
    private var metricsWithData: [MeasurementType] {
        MeasurementType.allCases.filter { type in
            measurements.contains { $0.value(for: type) != nil }
        }
    }

    private var dashboardContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                if showAddMeasurementButton {
                    Button(action: onAddMeasurement) {
                        AddActionRow(title: "Добавить замер", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(PressableButtonStyle())
                    .frame(maxWidth: .infinity)
                    .padding(AppDesign.cardPadding)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
                    .padding(.horizontal, AppDesign.cardPadding)
                    .padding(.top, AppDesign.blockSpacing)
                }

                // Квадратные карточки метрик (только с данными), тап → график
                if !metricsWithData.isEmpty {
                    SettingsCard(title: "Метрики") {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: AppDesign.rowSpacing),
                            GridItem(.flexible(), spacing: AppDesign.rowSpacing)
                        ], spacing: AppDesign.rowSpacing) {
                            ForEach(metricsWithData) { type in
                                NavigationLink {
                                    ChartDetailView(
                                        type: type,
                                        measurements: measurements,
                                        goals: goals.filter { $0.measurementType == type.rawValue },
                                        displayMode: $displayMode,
                                        chartColorIndex: $chartColorIndex,
                                        chartPeriod: $chartPeriod
                                    )
                                } label: {
                                    MetricSummaryCard(type: type, measurements: measurements)
                                }
                                .buttonStyle(PressableButtonStyle())
                            }
                        }
                    }
                }

                    // История замеров
                    SettingsCard(title: "История замеров") {
                        if measurements.isEmpty {
                            ContentUnavailableView(
                                "Пока нет замеров",
                                systemImage: "ruler.fill",
                                description: Text(showAddMeasurementButton ? "Нажмите «Добавить замер» выше, чтобы записать первый замер." : "Данные по замерам появятся здесь.")
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
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    var body: some View {
        if embedInNavigationStack {
            NavigationStack {
                dashboardContent
            }
        } else {
            dashboardContent
        }
    }
}

#Preview {
    DashboardView(
        profile: Profile(id: "1", userId: "u1", type: .trainee, name: "Мой дневник"),
        measurements: [],
        goals: [],
        onAddMeasurement: {},
        onDeleteMeasurement: { _ in }
    )
}
