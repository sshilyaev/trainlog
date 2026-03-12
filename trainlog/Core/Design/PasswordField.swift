//
//  PasswordField.swift
//  TrainLog
//

import SwiftUI
import UIKit

struct PasswordField: View {
    let title: String
    @Binding var text: String
    var textContentType: UITextContentType? = .password

    @State private var isRevealed = false

    var body: some View {
        HStack(spacing: 0) {
            Group {
                if isRevealed {
                    TextField(title, text: $text)
                } else {
                    SecureField(title, text: $text)
                }
            }
            .textContentType(textContentType)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(.leading, 12)
            .padding(.vertical, 10)
            .padding(.trailing, 40)

            Button {
                isRevealed.toggle()
            } label: {
                Image(systemName: isRevealed ? "eye.slash.fill" : "eye.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color(.tertiaryLabel))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isRevealed ? "Скрыть пароль" : "Показать пароль")
        }
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color(.separator).opacity(0.5), lineWidth: 0.5)
        )
    }
}

