//
//  SettingsComponents.swift
//  TrainLog
//

import SwiftUI
import UIKit

/// Единое поле ввода: подпись сверху, без плейсхолдера по умолчанию. Одинаковый вид во всём приложении.
struct AppTextField: View {
    var label: String? = nil
    @Binding var text: String
    var placeholder: String = ""
    var textContentType: UITextContentType? = nil
    var autocapitalization: TextInputAutocapitalization = .sentences
    var axis: Axis = .horizontal
    var lineLimit: Int? = nil
    var lineLimitRange: ClosedRange<Int>? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let label, !label.isEmpty {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Group {
                if let range = lineLimitRange {
                    TextField(placeholder, text: $text, axis: axis)
                        .lineLimit(range)
                } else if let limit = lineLimit {
                    TextField(placeholder, text: $text, axis: axis)
                        .lineLimit(limit)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .textFieldStyle(.roundedBorder)
            .textContentType(textContentType)
            .textInputAutocapitalization(autocapitalization)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Карточка настроек: светлая подложка, скругления, внутренние отступы.
struct SettingsCard<Content: View>: View {
    var title: String? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppDesign.rowSpacing) {
            if let title, !title.isEmpty {
                Text(title)
                    .font(.headline)
            }
            content()
        }
        .padding(AppDesign.cardPadding)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
        .padding(.horizontal, AppDesign.cardPadding)
        .padding(.top, AppDesign.blockSpacing)
    }
}

/// Сегментный выбор с «не задано» через отдельное состояние (удобно для Optional).
struct SegmentedPicker<T: Hashable, Label: StringProtocol>: View {
    let title: String
    @Binding var selection: T
    let options: [(T, Label)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Picker(title, selection: $selection) {
                ForEach(0..<options.count, id: \.self) { i in
                    Text(String(options[i].1)).tag(options[i].0)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}

/// Блок «Управление аккаунтом»: пояснение + destructive-кнопка.
struct AccountManagementCard: View {
    let title: String
    let description: String
    let destructiveTitle: String
    let onDestructive: () -> Void

    var body: some View {
        SettingsCard(title: title) {
            Text(description)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button(role: .destructive, action: onDestructive) {
                Text(destructiveTitle)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())
            .background(Color.red.opacity(AppDesign.destructiveBackgroundOpacity), in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
            .foregroundStyle(.red)
        }
    }
}

