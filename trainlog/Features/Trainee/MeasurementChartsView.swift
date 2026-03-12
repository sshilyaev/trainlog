//
//  MeasurementChartsView.swift
//  TrainLog
//

import SwiftUI
import Charts

// MARK: - Main charts list (group reused by DashboardView)

enum ChartsMetricGroup: String, CaseIterable {
    case weightHeight = "Вес и рост"
    case upper = "Верх"
    case torso = "Торс"
    case lower = "Низ"

    var types: [MeasurementType] {
        switch self {
        case .weightHeight: return [.weight, .height]
        case .upper: return [.neck, .shoulders, .leftBiceps, .rightBiceps]
        case .torso: return [.waist, .belly]
        case .lower: return [.leftThigh, .rightThigh, .hips, .buttocks, .leftCalf, .rightCalf]
        }
    }
}

struct MeasurementChartsView: View {
    let profile: Profile
    let measurements: [Measurement]
    let goals: [Goal]
    /// Когда false, вид не оборачивается в NavigationStack (для push из ClientCardView у тренера).
    var embedInNavigationStack: Bool = true

    @State private var displayMode: ChartDisplayMode = .bar
    @State private var chartColorIndex: Int = 0
    @State private var chartPeriod: ChartPeriod = .month

    private var chartColor: Color { ChartDetailView.chartColorOptions[chartColorIndex] }

    private var content: some View {
        ScrollView {
            VStack(spacing: 0) {
                Text("Выберите метрику для просмотра графика и динамики.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)

                ForEach(ChartsMetricGroup.allCases, id: \.rawValue) { group in
                    SettingsCard(title: group.rawValue) {
                        VStack(spacing: 0) {
                            ForEach(Array(group.types.enumerated()), id: \.element.id) { index, type in
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
                                    ChartMetricRow(type: type, measurements: measurements)
                                }
                                .buttonStyle(PressableButtonStyle())
                                if index != group.types.count - 1 {
                                    Divider()
                                }
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Графики")
        .navigationBarTitleDisplayMode(.inline)
    }

    var body: some View {
        if embedInNavigationStack {
            NavigationStack {
                content
            }
        } else {
            content
        }
    }
}

// MARK: - Строка метрики в списке графиков

struct ChartMetricRow: View {
    let type: MeasurementType
    let measurements: [Measurement]

    private var lastPoint: (value: Double, date: Date)? {
        measurements
            .compactMap { m -> (Double, Date)? in
                guard let v = m.value(for: type) else { return nil }
                return (v, m.date)
            }
            .max(by: { $0.1 < $1.1 })
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(type.displayName)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer()
            if let last = lastPoint {
                Text("\(last.value.measurementFormatted) \(type.unit)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            } else {
                Text("Нет данных")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

// MARK: - Блок «последнее значение + дата» (миникарточка, оставлена для возможного использования)

struct MetricSummaryCard: View {
    let type: MeasurementType
    let measurements: [Measurement]

    private var lastPoint: (value: Double, date: Date)? {
        measurements
            .compactMap { m -> (Double, Date)? in
                guard let v = m.value(for: type) else { return nil }
                return (v, m.date)
            }
            .max(by: { $0.1 < $1.1 })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(type.displayName)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            if let last = lastPoint {
                Text("\(last.value.measurementFormatted) \(type.unit)")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(last.date.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year(.twoDigits)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("—")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.tertiary)
                Text("Нет данных")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Меню «Вид и цвет» (только на экране детали графика)

/// Период отображения графика (относительно последней даты в данных или свои даты).
enum ChartPeriod: String, CaseIterable, Hashable {
    case week = "Неделя"
    case month = "Месяц"
    case year = "Год"
    case all = "Всё время"
    case custom = "Свои даты"

    var days: Int? {
        switch self {
        case .week: return 7
        case .month: return 30
        case .year: return 365
        case .all, .custom: return nil
        }
    }
}

enum ChartDisplayMode: String, CaseIterable, Hashable {
    case bar = "Столбики"
    case line = "Линия"
    case area = "Площадь"
}

struct ChartDetailView: View {
    let type: MeasurementType
    let measurements: [Measurement]
    let goals: [Goal]

    @Binding var displayMode: ChartDisplayMode
    @Binding var chartColorIndex: Int
    @Binding var chartPeriod: ChartPeriod
    @Environment(\.dismiss) private var dismiss

    @State private var customDateFrom: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var customDateTo: Date = Date()

    private var chartColor: Color { Self.chartColorOptions[chartColorIndex] }

    private static let chartColorLabels: [String] = ["Акцент", "Синий", "Оранжевый", "Зелёный", "Фиолетовый", "Розовый"]

    static let chartColorOptions: [Color] = [
        AppDesign.accent,
        Color.blue,
        Color.orange,
        AppDesign.profileAccent,
        Color.purple,
        Color.pink
    ]

    /// Все точки по метрике, отсортированные по дате.
    private var allPoints: [ChartPoint] {
        measurements
            .compactMap { m -> ChartPoint? in
                guard let v = m.value(for: type) else { return nil }
                return ChartPoint(id: m.id, date: m.date, value: v)
            }
            .sorted { $0.date < $1.date }
    }

    /// Точки с учётом выбранного периода (от последней даты назад) или своих дат.
    private var points: [ChartPoint] {
        guard !allPoints.isEmpty else { return [] }
        if chartPeriod == .custom {
            return allPoints.filter { $0.date >= customDateFrom && $0.date <= customDateTo }
        }
        guard let lastDate = allPoints.last?.date else { return [] }
        guard let days = chartPeriod.days else { return allPoints }
        let start = Calendar.current.date(byAdding: .day, value: -days, to: lastDate)!
        return allPoints.filter { $0.date >= start }
    }

    private var goalValue: Double? {
        goals.sorted { $0.targetDate > $1.targetDate }.first?.targetValue
    }

    /// Серия подряд идущих замеров в одну сторону (вниз или вверх). Возвращает (направление, количество).
    private var consecutiveTrendStreak: (count: Int, text: String)? {
        guard points.count >= 2 else { return nil }
        var count = 1
        for i in (1..<points.count).reversed() {
            let cur = points[i].value
            let prev = points[i - 1].value
            if cur < prev { count += 1 } else { break }
        }
        if count >= 2 {
            return (count, "Вниз \(count) замеров подряд")
        }
        count = 1
        for i in (1..<points.count).reversed() {
            let cur = points[i].value
            let prev = points[i - 1].value
            if cur > prev { count += 1 } else { break }
        }
        if count >= 2 {
            return (count, "Вверх \(count) замеров подряд")
        }
        return nil
    }

    /// Диапазон по Y: отступ сверху и снизу; для столбиков — запас сверху под подписи значений.
    private var chartYDomain: ClosedRange<Double> {
        guard !points.isEmpty else { return 0...1 }
        let minV = points.map(\.value).min()!
        let maxV = points.map(\.value).max()!
        let span = max(maxV - minV, 1.0)
        let paddingBottom = span * 0.05
        let paddingTop = span * (displayMode == .bar ? 0.25 : 0.1)
        return (minV - paddingBottom)...(maxV + paddingTop)
    }

    private func colorLabel(_ index: Int) -> String {
        guard index >= 0, index < Self.chartColorLabels.count else { return "Цвет" }
        return Self.chartColorLabels[index]
    }

    /// Диапазон по X: без зазоров — каждый столбик/точка по целому индексу, края вплотную.
    private var chartXDomain: ClosedRange<Double> {
        guard !points.isEmpty else { return -0.5...0.5 }
        return -0.5...(Double(points.count) - 0.5)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if points.isEmpty && allPoints.isEmpty {
                    EmptyStateView(
                        icon: "chart.xyaxis.line",
                        title: "Нет данных",
                        description: "Добавьте замеры для метрики «\(type.displayName)»"
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    // Период и свои даты
                    SettingsCard(title: "Период") {
                        Picker("Период", selection: $chartPeriod) {
                            Text("Неделя").tag(ChartPeriod.week)
                            Text("Месяц").tag(ChartPeriod.month)
                            Text("Год").tag(ChartPeriod.year)
                            Text("Всё").tag(ChartPeriod.all)
                            Text("Свои").tag(ChartPeriod.custom)
                        }
                        .pickerStyle(.segmented)

                        if chartPeriod == .custom {
                            DatePicker("От", selection: $customDateFrom, displayedComponents: .date)
                            DatePicker("До", selection: $customDateTo, displayedComponents: .date)
                        }
                    }

                    if !points.isEmpty {
                        // Вид и цвет графика
                        SettingsCard(title: "Вид графика") {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Тип")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Picker("Тип", selection: $displayMode) {
                                    ForEach(ChartDisplayMode.allCases, id: \.self) { mode in
                                        Text(mode.rawValue).tag(mode)
                                    }
                                }
                                .pickerStyle(.segmented)

                                Text("Цвет")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                HStack(spacing: 10) {
                                    ForEach(Array(ChartDetailView.chartColorOptions.enumerated()), id: \.offset) { index, color in
                                        Button {
                                            chartColorIndex = index
                                        } label: {
                                            Circle()
                                                .fill(color)
                                                .frame(width: 26, height: 26)
                                                .overlay(
                                                    Circle()
                                                        .strokeBorder(chartColorIndex == index ? Color.accentColor : Color.primary.opacity(0.2), lineWidth: chartColorIndex == index ? 2 : 1)
                                                )
                                        }
                                        .buttonStyle(PressableButtonStyle())
                                    }
                                }
                            }
                        }

                        // График: заголовок + пикер «Цвет», затем сам график
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(type.displayName)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Menu {
                                    ForEach(Array(ChartDetailView.chartColorOptions.enumerated()), id: \.offset) { index, color in
                                        Button {
                                            chartColorIndex = index
                                        } label: {
                                            HStack {
                                                Circle()
                                                    .fill(color)
                                                    .frame(width: 14, height: 14)
                                                Text(colorLabel(index))
                                                if chartColorIndex == index {
                                                    Image(systemName: "checkmark")
                                                }
                                            }
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(chartColor)
                                            .frame(width: 12, height: 12)
                                        Text("Цвет")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                        Image(systemName: "chevron.down")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(.tertiary)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
                                }
                            }
                            .padding(.horizontal, 4)

                            Chart {
                                chartContent
                            }
                            .chartXScale(domain: chartXDomain)
                            .chartXAxis {
                                AxisMarks(values: .stride(by: Double(max(1, points.count / 7)))) { value in
                                    if let d = value.as(Double.self), d >= 0, Int(d) < points.count {
                                        let i = Int(d)
                                        AxisValueLabel {
                                            Text(points[i].date.formatted(.dateTime.day(.twoDigits).month(.twoDigits)))
                                        }
                                        .foregroundStyle(.secondary)
                                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                            .foregroundStyle(Color.primary.opacity(0.06))
                                    }
                                }
                            }
                            .chartYAxis {
                                AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                        .foregroundStyle(Color.primary.opacity(0.08))
                                    AxisValueLabel()
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .chartYScale(domain: chartYDomain)
                            .chartPlotStyle { plotArea in
                                plotArea.padding(.horizontal, 8)
                                    .padding(.top, displayMode == .bar ? 20 : 8)
                            }
                            .frame(height: 280)
                            .clipped()
                        }
                        .padding(AppDesign.cardPadding)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
                        .padding(.horizontal, AppDesign.cardPadding)
                        .padding(.top, AppDesign.blockSpacing)
                    } else if chartPeriod == .custom || chartPeriod.days != nil {
                        Text("Нет данных за выбранный период")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                            .padding(.horizontal, AppDesign.cardPadding)
                    }

                    // Цели по этой метрике
                    SettingsCard(title: "Цели") {
                        if goals.isEmpty {
                            Text("Нет целей по этой метрике")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 8)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(goals.sorted { $0.targetDate < $1.targetDate }.enumerated()), id: \.element.id) { index, goal in
                                    HStack(spacing: 12) {
                                        Image(systemName: "target")
                                            .font(.body)
                                            .foregroundStyle(.secondary)
                                            .frame(width: 28, alignment: .center)
                                        Text("\(goal.targetValue.measurementFormatted) \(type.unit)")
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        Text(goal.targetDate.formatted(.dateTime.day().month().year()))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.vertical, 12)
                                    .contentShape(Rectangle())
                                    if index != goals.count - 1 { Divider().padding(.leading, 40) }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(type.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Label("Назад", systemImage: "chevron.left")
                }
            }
        }
        .environment(\.locale, Locale(identifier: "ru_RU"))
    }

    @ChartContentBuilder
    private var chartContent: some ChartContent {
        let target = goalValue
        let indexed = Array(points.enumerated())

        switch displayMode {
        case .bar:
            ForEach(indexed, id: \.element.id) { index, p in
                BarMark(
                    x: .value("", index),
                    y: .value(type.displayName, p.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [chartColor.opacity(0.85), chartColor],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .annotation(position: .overlay, alignment: .top, spacing: 4) {
                    Text(p.value.measurementFormatted)
                        .font(.caption)
                        .foregroundStyle(.primary)
                }
            }
            if let t = target {
                RuleMark(y: .value("Цель", t))
                    .foregroundStyle(AppDesign.profileAccent.opacity(0.9))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [8, 4]))
            }

        case .line:
            ForEach(indexed, id: \.element.id) { index, p in
                LineMark(
                    x: .value("", index),
                    y: .value(type.displayName, p.value)
                )
                .foregroundStyle(chartColor)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 3))
            }
            ForEach(indexed, id: \.element.id) { index, p in
                PointMark(
                    x: .value("", index),
                    y: .value(type.displayName, p.value)
                )
                .foregroundStyle(chartColor)
                .symbolSize(60)
            }
            if let t = target {
                RuleMark(y: .value("Цель", t))
                    .foregroundStyle(AppDesign.profileAccent.opacity(0.9))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [8, 4]))
            }

        case .area:
            ForEach(indexed, id: \.element.id) { index, p in
                AreaMark(
                    x: .value("", index),
                    y: .value(type.displayName, p.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [chartColor.opacity(0.5), chartColor.opacity(0.06)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }
            ForEach(indexed, id: \.element.id) { index, p in
                LineMark(
                    x: .value("", index),
                    y: .value(type.displayName, p.value)
                )
                .foregroundStyle(chartColor)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
            }
            ForEach(indexed, id: \.element.id) { index, p in
                PointMark(
                    x: .value("", index),
                    y: .value(type.displayName, p.value)
                )
                .foregroundStyle(chartColor)
                .symbolSize(40)
            }
            if let t = target {
                RuleMark(y: .value("Цель", t))
                    .foregroundStyle(AppDesign.profileAccent.opacity(0.9))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [8, 4]))
            }
        }
    }
}

private struct ChartPoint: Identifiable {
    let id: String
    let date: Date
    let value: Double
}

#Preview {
    MeasurementChartsView(
        profile: Profile(id: "1", userId: "u1", type: .trainee, name: "Мой дневник"),
        measurements: [],
        goals: []
    )
}