//
//  AddTraineeSheet.swift
//  TrainLog
//

import SwiftUI

struct AddTraineeSheet: View {
    let coachProfile: Profile
    let myTraineeProfiles: [Profile]
    let linkedTraineeIds: Set<String>
    let linkService: CoachTraineeLinkServiceProtocol
    let onLinkAdded: () -> Void
    let onDismiss: () -> Void

    private var availableProfiles: [Profile] {
        myTraineeProfiles.filter { !linkedTraineeIds.contains($0.id) }
    }

    @State private var isAdding = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if availableProfiles.isEmpty {
                    EmptyStateView(
                        icon: "person.crop.circle.badge.plus",
                        title: "Нет профилей для добавления",
                        description: "Все ваши профили подопечного уже добавлены к этому тренеру или у вас нет профиля подопечного."
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(availableProfiles) { p in
                            Button {
                                Task { await addLink(traineeProfileId: p.id) }
                            } label: {
                                ProfileRow(profile: p)
                            }
                            .disabled(isAdding)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Добавить мой профиль")
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
            .alert("Ошибка", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                if let msg = errorMessage {
                    Text(msg)
                }
            }
        }
    }

    private func addLink(traineeProfileId: String) async {
        isAdding = true
        errorMessage = nil
        defer { Task { @MainActor in isAdding = false } }
        do {
            try await linkService.addLink(coachProfileId: coachProfile.id, traineeProfileId: traineeProfileId, displayName: nil, note: nil)
            onLinkAdded()
        } catch {
            errorMessage = AppErrors.userMessage(for: error)
        }
    }
}
