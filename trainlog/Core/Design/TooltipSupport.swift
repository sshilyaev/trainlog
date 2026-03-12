//
//  TooltipSupport.swift
//  TrainLog
//

import SwiftUI

/// Идентификаторы подсказок. Добавлять сюда новые при добавлении тултипов на экраны.
enum TooltipId: String, CaseIterable {
    case visitsCalendarTap = "visits_calendar_tap"
    case coachTraineesList = "coach_trainees_list"
    case traineeMeasurements = "trainee_measurements"
    case traineeGoals = "trainee_goals"
    case traineeCharts = "trainee_charts"
    case traineeWorkouts = "trainee_workouts"
    case addTraineeHint = "add_trainee_hint"
}

/// Хранение «подсказка просмотрена» в UserDefaults. Сброс — через «Показать подсказки снова» в профиле.
enum TooltipStorage {
    private static let prefix = "tooltip_seen_"

    static func hasSeen(_ id: TooltipId) -> Bool {
        UserDefaults.standard.bool(forKey: prefix + id.rawValue)
    }

    static func markSeen(_ id: TooltipId) {
        UserDefaults.standard.set(true, forKey: prefix + id.rawValue)
    }

    /// Сбросить прохождение всех подсказок — они снова покажутся при заходе на экран.
    static func resetAll() {
        for id in TooltipId.allCases {
            UserDefaults.standard.removeObject(forKey: prefix + id.rawValue)
        }
    }
}

/// Модификатор: поверх контента показывается подсказка (один раз), по «Понятно» помечается просмотренной и скрывается.
struct TooltipModifier: ViewModifier {
    let id: TooltipId
    let title: String
    let message: String

    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                if !TooltipStorage.hasSeen(id) {
                    isVisible = true
                }
            }
            .overlay {
                if isVisible {
                    TooltipOverlay(
                        title: title,
                        message: message,
                        onDismiss: {
                            TooltipStorage.markSeen(id)
                            withAnimation(.easeOut(duration: 0.2)) { isVisible = false }
                        }
                    )
                }
            }
    }
}

private struct TooltipOverlay: View {
    let title: String
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: AppDesign.rowSpacing) {
                Text(title)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Понятно", action: onDismiss)
                    .buttonStyle(.borderedProminent)
                    .tint(AppDesign.primaryButtonColor)
                    .padding(.top, 4)
            }
            .padding(AppDesign.cardPadding * 1.5)
            .frame(maxWidth: 280)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
            .shadow(color: .black.opacity(0.2), radius: 16, x: 0, y: 8)
        }
    }
}

extension View {
    /// Показать подсказку один раз (по id). После «Понятно» не показывается, пока не сбросят в настройках профиля.
    func tooltip(id: TooltipId, title: String, message: String) -> some View {
        modifier(TooltipModifier(id: id, title: title, message: message))
    }
}

// MARK: - Строка «Недоступно» с подсказкой по нажатию (переиспользуемый компонент)

/// Строка с надписью «Недоступно» и иконкой; по нажатию показывается alert с подсказкой.
struct UnavailableRowWithHint: View {
    let icon: String
    let title: String
    let hint: String

    @State private var showHint = false

    var body: some View {
        Button {
            showHint = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                    .frame(width: 28, alignment: .center)
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
                Text("Недоступно")
                    .foregroundStyle(.secondary)
                Image(systemName: "info.circle")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, AppDesign.cardPadding)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .alert("Подсказка", isPresented: $showHint) {
            Button("Понятно") { showHint = false }
        } message: {
            Text(hint)
        }
    }
}
