//
//  ButtonComponents.swift
//  TrainLog
//

import SwiftUI

// MARK: - 1. Кнопки добавления (иконка + жирный текст)

/// Строка «Добавить что‑то» для списков: иконка + жирный заголовок. Используется в List внутри Button или NavigationLink.
/// Примеры: Добавить цель, Добавить замер, Добавить подопечного, Добавить по коду.
struct AddActionRow: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
    }
}

// MARK: - 2. Цветная кнопка действия (сохранить / создать / обновить)

/// Основная кнопка для действий с сервером: Войти, Сохранить, Создать, Обновить, Понятно, Добавить (на выборе профиля).
struct PrimaryActionButton: View {
    let title: String
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if isLoading {
                ProgressView()
                    .tint(.white)
            } else {
                Text(title)
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(isLoading || isDisabled)
    }
}

// MARK: - 3. Строка-действие в блоке (профиль и списки)

/// Блок-строка: иконка, заголовок, опционально значение справа. Для навигации или действия.
/// Примеры: Переключить аккаунт, Поделиться с тренером, Удалить аккаунт, Графики замеров, Отвязать подопечного.
struct ActionBlockRow: View {
    var icon: String? = nil
    let title: String
    var value: String? = nil
    var action: (() -> Void)? = nil
    var destructive: Bool = false

    private var foreground: Color {
        destructive ? .red : .primary
    }

    var body: some View {
        Group {
            if let action {
                Button(action: action) { rowContent }
            } else {
                rowContent
            }
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var rowContent: some View {
        HStack(spacing: AppDesign.rowSpacing) {
            if let icon {
                Image(systemName: icon)
                    .foregroundStyle(destructive ? .red : .secondary)
                    .frame(width: 28, alignment: .center)
            }
            Text(title)
                .foregroundStyle(foreground)
            Spacer()
            if let value, !value.isEmpty {
                Text(value)
                    .foregroundStyle(destructive ? .red : .secondary)
            }
        }
        .padding(.horizontal, AppDesign.cardPadding)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

/// Обёртка для блока профиля: скруглённый фон + отступы.
struct ActionBlockStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
        .padding(.horizontal, AppDesign.cardPadding)
        .padding(.top, AppDesign.blockSpacing)
    }
}

extension View {
    func actionBlockStyle() -> some View {
        modifier(ActionBlockStyle())
    }

    /// Прямоугольный блок (плитка): скруглённый фон, минимальная высота. Для сетки плиток (например Абонементы и Посещения в карточке подопечного).
    func rectangularBlockStyle() -> some View {
        modifier(RectangularBlockStyle())
    }
}

// MARK: - 5. Прямоугольные блоки (плитки)

/// Содержимое одной плитки: иконка, заголовок, опционально значение. Используется внутри NavigationLink + rectangularBlockStyle().
struct RectangularBlockContent: View {
    let icon: String
    let title: String
    var value: String? = nil
    var iconColor: Color = AppDesign.profileAccent

    var body: some View {
        VStack(spacing: AppDesign.blockSpacing) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(iconColor)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
            if let value, !value.isEmpty {
                Text(value)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppDesign.cardPadding)
        .padding(.horizontal, AppDesign.rowSpacing)
        .contentShape(Rectangle())
    }
}

private struct RectangularBlockStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(minHeight: AppDesign.rectangularBlockMinHeight)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
    }
}

// MARK: - 4. Карточка «Добавить» на выборе профиля

/// Кнопка-карточка: круг с плюсом + подпись «Добавить». Только для экрана выбора профиля.
struct AddProfileCardButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: AppDesign.blockSpacing) {
                ZStack {
                    Circle()
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                        .foregroundStyle(.secondary.opacity(0.6))
                        .frame(width: 64, height: 64)
                    Image(systemName: "plus")
                        .font(.title2.bold())
                        .foregroundStyle(.secondary)
                }
                Text("Добавить")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .frame(width: 88)
        }
        .buttonStyle(PressableButtonStyle())
    }
}
