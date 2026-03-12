//
//  Design.swift
//  TrainLog
//

import SwiftUI
import UIKit

/// Лёгкий дизайн-слой: один акцент, мягкие списки, без перегруза.
enum AppDesign {
    /// Мягкий акцент (приглушённый бирюзовый) — не режет глаз.
    static let accent = Color(red: 0.22, green: 0.55, blue: 0.55)
    
    /// Отступ между секциями контента
    static let sectionSpacing: CGFloat = 24

    /// Внутренний отступ карточек и блоков (SettingsCard, кнопки добавления)
    static let cardPadding: CGFloat = 16
    /// Отступ между элементами в строке (HStack/VStack в рядах)
    static let rowSpacing: CGFloat = 12
    /// Малый отступ (например в overlay)
    static let blockSpacing: CGFloat = 8
    /// Скругление карточек и кнопок
    static let cornerRadius: CGFloat = 12

    /// Высота основной кнопки (Войти, Сохранить, Создать, Обновить)
    static let primaryButtonHeight: CGFloat = 50

    /// Цвет основных кнопок (Войти, Сохранить, Создать, Обновить) — синий, не бирюзовый.
    static let primaryButtonColor = Color.blue

    /// Цвет акцента в профиле (аватар, иконка профиля)
    static let profileAccent = Color.green
    /// Прозрачность фона аватара в профиле
    static let profileAccentOpacity: Double = 0.2

    /// Прозрачность фона деструктивных кнопок (удалить, отвязать)
    static let destructiveBackgroundOpacity: Double = 0.12

    // MARK: - Типы блоков (дизайн-система)
    /// Длинный узкий блок — одна строка на всю ширину (профиль, список действий). Использование: `.actionBlockStyle()`.
    /// Длинный высокий блок — на всю ширину, высота больше одной строки (зарезервировано для будущего).
    /// Прямоугольный блок (плитка) — компактная карточка, несколько в ряд. Использование: `RectangularBlockContent` + `.rectangularBlockStyle()`.
    static let rectangularBlockMinHeight: CGFloat = 88
    static let rectangularBlockSpacing: CGFloat = 8
}

// MARK: - Состояние загрузки (унифицированный вид)

extension AppDesign {
    static let loadingSpacing: CGFloat = 12
    static let loadingMessageFont: Font = .subheadline
    static let loadingScale: CGFloat = 1.2
}

/// Единый вид загрузки для экранов со списками и данными с сервера.
struct LoadingView: View {
    var message: String = "Загрузка…"

    var body: some View {
        VStack(spacing: AppDesign.loadingSpacing) {
            ProgressView()
                .scaleEffect(AppDesign.loadingScale)
            Text(message)
                .font(AppDesign.loadingMessageFont)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Для вставки в контент (например под кнопкой): ограниченная высота, не на весь экран.
struct LoadingBlockView: View {
    var message: String = "Загрузка…"

    var body: some View {
        VStack(spacing: AppDesign.loadingSpacing) {
            ProgressView()
                .scaleEffect(AppDesign.loadingScale)
            Text(message)
                .font(AppDesign.loadingMessageFont)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 200)
    }
}

// MARK: - Тема приложения (светлая / тёмная / системная)

enum AppTheme: String, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"

    var displayName: String {
        switch self {
        case .light: return "Светлая"
        case .dark: return "Тёмная"
        case .system: return "Как в системе"
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}

// MARK: - Заглушка «нет данных» (единый формат: иконка, заголовок, описание)

struct EmptyStateView<Actions: View>: View {
    let icon: String
    let title: String
    let description: String
    @ViewBuilder let actions: () -> Actions

    init(
        icon: String,
        title: String,
        description: String,
        @ViewBuilder actions: @escaping () -> Actions = { EmptyView() }
    ) {
        self.icon = icon
        self.title = title
        self.description = description
        self.actions = actions
    }

    var body: some View {
        VStack(spacing: AppDesign.emptyStateSpacing) {
            Image(systemName: icon)
                .font(.system(size: AppDesign.emptyStateIconSize))
                .foregroundStyle(.secondary)

            Text(title)
                .font(AppDesign.emptyStateTitleFont)

            Text(description)
                .font(AppDesign.emptyStateDescriptionFont)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            actions()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppDesign.emptyStateVerticalPadding)
    }
}

extension AppDesign {
    /// Лёгкая вибрация при успешном действии (сохранить замер, добавить цель, привязать подопечного).
    static func triggerSuccessHaptic() {
        #if os(iOS)
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.prepare()
        gen.impactOccurred(intensity: 0.7)
        #endif
    }

    /// Лёгкая вибрация при нажатии на кнопку/строку (feedback «нажалось»).
    static func triggerSelectionHaptic() {
        #if os(iOS)
        let gen = UISelectionFeedbackGenerator()
        gen.prepare()
        gen.selectionChanged()
        #endif
    }

    /// Размер иконки в заглушке «нет данных»
    static let emptyStateIconSize: CGFloat = 48
    /// Отступ между элементами в заглушке
    static let emptyStateSpacing: CGFloat = 12
    /// Вертикальный отступ заглушки
    static let emptyStateVerticalPadding: CGFloat = 24
    /// Шрифт заголовка заглушки
    static let emptyStateTitleFont: Font = .title2
    /// Шрифт описания заглушки
    static let emptyStateDescriptionFont: Font = .subheadline
}

// MARK: - Единый стиль основной кнопки

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .frame(height: AppDesign.primaryButtonHeight)
            .background(AppDesign.primaryButtonColor)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
            .opacity(configuration.isPressed ? 0.9 : 1)
    }
}

// MARK: - Эффект нажатия (визуальный + тактильный) для кнопок и строк

/// Стиль кнопки: при нажатии — подсветка фона, сжатие и затемнение, как у системных кнопок (Отмена, Добавить). Надевать на все нажимаемые строки и карточки.
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                if configuration.isPressed {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.tertiarySystemFill))
                }
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.easeOut(duration: 0), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    AppDesign.triggerSelectionHaptic()
                }
            }
    }
}

// MARK: - Скрытие клавиатуры по тапу

extension View {
    func dismissKeyboardOnTap() -> some View {
        self.onTapGesture {
            #if canImport(UIKit)
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            #endif
        }
    }
}
