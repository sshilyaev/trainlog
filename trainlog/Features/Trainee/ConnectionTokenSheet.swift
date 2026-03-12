//
//  ConnectionTokenSheet.swift
//  TrainLog
//

import SwiftUI
import UIKit

/// Экран подопечного: генерация временного кода для привязки к тренеру (только код, без QR).
struct ConnectionTokenSheet: View {
    let profile: Profile
    let tokenService: ConnectionTokenServiceProtocol
    let onDismiss: () -> Void

    @State private var token: ConnectionToken?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var copied = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    LoadingView(message: "Создаём код…")
                        .background(Color(.systemGroupedBackground))
                } else if let t = token, t.isValid {
                    tokenContent(token: t)
                } else if let msg = errorMessage, !msg.isEmpty {
                    ScrollView {
                        SettingsCard(title: "Ошибка") {
                            Text(msg)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.top, 24)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
                } else {
                    ContentUnavailableView(
                        "Код не найден",
                        systemImage: "key.slash",
                        description: Text("Не удалось создать код. Попробуйте позже.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle("Поделиться с тренером")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        onDismiss()
                    } label: {
                        Label("Назад", systemImage: "chevron.left")
                    }
                }
            }
            .task { await createToken() }
        }
    }

    private func tokenContent(token t: ConnectionToken) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                SettingsCard(title: "Что сделать тренеру") {
                    Text("1. Откройте приложение и войдите в профиль тренера.\n2. Перейдите в раздел «Подопечные» → «Добавить подопечного».\n3. Выберите «Добавить по коду» и введите код ниже.")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                SettingsCard(title: "Код для ввода") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(t.id)
                            .font(.system(.title2, design: .monospaced))
                            .fontWeight(.semibold)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: 12) {
                            Button {
                                copyCode(t.id)
                            } label: {
                                Label(copied ? "Скопировано" : "Скопировать", systemImage: copied ? "checkmark.circle.fill" : "doc.on.doc.fill")
                            }
                            .buttonStyle(.bordered)
                            .disabled(copied)

                            ShareLink(
                                item: t.id,
                                subject: Text("Код для подключения"),
                                message: Text(t.id)
                            ) {
                                Label("Поделиться", systemImage: "square.and.arrow.up.fill")
                            }
                            .buttonStyle(.bordered)
                        }

                        Text("Код действителен до \(formattedExpiry(t.expiresAt))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func copyCode(_ code: String) {
        UIPasteboard.general.string = code
        copied = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            copied = false
        }
    }

    private func formattedExpiry(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        f.locale = Locale(identifier: "ru_RU")
        return f.string(from: date)
    }

    private func createToken() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let t = try await tokenService.createToken(traineeProfileId: profile.id)
            await MainActor.run { token = t }
        } catch {
            await MainActor.run { errorMessage = AppErrors.userMessage(for: error) }
        }
    }
}
