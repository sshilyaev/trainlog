//
//  TraineeLinkFormView.swift
//  TrainLog
//

import SwiftUI

/// Форма ввода имени для списка и заметки при добавлении подопечного тренером.
struct TraineeLinkFormView: View {
    let trainee: Profile
    let coachProfileId: String
    let linkService: CoachTraineeLinkServiceProtocol
    let tokenService: ConnectionTokenServiceProtocol?
    let pendingToken: String?
    let onLinkAdded: () -> Void
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var displayName: String = ""
    @State private var note: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SettingsCard(title: "Отображение у тренера") {
                    VStack(spacing: 12) {
                        TextField("Имя для списка", text: $displayName)
                            .textContentType(.name)
                            .textFieldStyle(.roundedBorder)

                        TextField("Заметка", text: $note, axis: .vertical)
                            .lineLimit(2...4)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                SettingsCard(title: nil) {
                    PrimaryActionButton(title: "Добавить", isLoading: isLoading) {
                        Task { await save() }
                    }

                    if let msg = errorMessage, !msg.isEmpty {
                        Text(msg)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Добавить подопечного")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Label("Назад", systemImage: "chevron.left")
                }
            }
        }
        .onAppear {
            if displayName.isEmpty {
                displayName = trainee.name
            }
        }
    }

    private func save() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let name = displayName.trimmingCharacters(in: .whitespaces).isEmpty ? nil : displayName.trimmingCharacters(in: .whitespaces)
            let noteText = note.trimmingCharacters(in: .whitespaces).isEmpty ? nil : note.trimmingCharacters(in: .whitespaces)
            try await linkService.addLink(coachProfileId: coachProfileId, traineeProfileId: trainee.id, displayName: name, note: noteText)
            if let token = pendingToken, let svc = tokenService {
                try? await svc.markTokenUsed(token: token)
            }
            await MainActor.run { AppDesign.triggerSuccessHaptic() }
            await MainActor.run { dismiss() }
            onLinkAdded()
        } catch {
            errorMessage = AppErrors.userMessage(for: error)
        }
    }
}
