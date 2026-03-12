//
//  AddTraineeView.swift
//  TrainLog
//

import SwiftUI

/// Полноэкранный экран «Добавить подопечного»: сверху кнопка «Добавить по коду», ниже список своих профилей подопечного.
struct AddTraineeView: View {
    let coachProfile: Profile
    let myTraineeProfiles: [Profile]
    let linkedTraineeIds: Set<String>
    let linkService: CoachTraineeLinkServiceProtocol
    let profileService: ProfileServiceProtocol
    let connectionTokenService: ConnectionTokenServiceProtocol
    let onLinkAdded: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var availableProfiles: [Profile] {
        myTraineeProfiles
            .filter { !$0.isManaged } // managed создаются через отдельный сценарий ниже
            .filter { !linkedTraineeIds.contains($0.id) }
    }

    @State private var errorMessage: String?
    @State private var showCreateManagedTrainee = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SettingsCard(title: "По коду") {
                    NavigationLink {
                        AddByCodeView(
                            coachProfile: coachProfile,
                            tokenService: connectionTokenService,
                            linkService: linkService,
                            profileService: profileService,
                            onLinkAdded: {
                                dismiss()
                                onLinkAdded()
                            },
                            onDismiss: { dismiss() }
                        )
                    } label: {
                        ClientCardRow(icon: "key", title: "Добавить по коду", value: nil, showsDisclosure: true)
                    }
                    .buttonStyle(PressableButtonStyle())

                    Text("Подопечный создаёт временный код в разделе «Подключить по коду» в своём профиле.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                SettingsCard(title: "Без приложения") {
                    Button {
                        showCreateManagedTrainee = true
                    } label: {
                        ClientCardRow(icon: "person.badge.plus", title: "Создать подопечного вручную", value: nil, showsDisclosure: true)
                    }
                    .buttonStyle(PressableButtonStyle())

                    Text("Если клиент не хочет устанавливать приложение, вы можете создать его профиль и вести учёт. Позже этот профиль можно будет объединить с реальным.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                SettingsCard(title: "Мои профили подопечного") {
                    if availableProfiles.isEmpty {
                        ContentUnavailableView(
                            "Нет профилей",
                            systemImage: "person.fill",
                            description: Text("Все ваши профили подопечного уже добавлены или у вас нет такого профиля.")
                        )
                        .padding(.vertical, 8)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(availableProfiles.enumerated()), id: \.element.id) { index, p in
                                NavigationLink {
                                    TraineeLinkFormView(
                                        trainee: p,
                                        coachProfileId: coachProfile.id,
                                        linkService: linkService,
                                        tokenService: nil,
                                        pendingToken: nil,
                                        onLinkAdded: {
                                            dismiss()
                                            onLinkAdded()
                                        },
                                        onDismiss: { dismiss() }
                                    )
                                } label: {
                                    ProfileRow(profile: p, showTypeLabel: false)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 8)
                                }
                                .buttonStyle(PressableButtonStyle())
                                if index != availableProfiles.count - 1 { Divider() }
                            }
                        }
                    }
                }

                if let msg = errorMessage, !msg.isEmpty {
                    Text(msg)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
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
        .sheet(isPresented: $showCreateManagedTrainee) {
            CreateManagedTraineeSheet(
                coachProfile: coachProfile,
                profileService: profileService,
                linkService: linkService,
                onCreated: {
                    showCreateManagedTrainee = false
                    dismiss()
                    onLinkAdded()
                },
                onCancel: { showCreateManagedTrainee = false },
                onError: { errorMessage = $0 }
            )
            .presentationDetents([.medium, .large])
        }
        .tooltip(
            id: .addTraineeHint,
            title: "Добавить подопечного",
            message: "По коду — введите код из приложения клиента. «Мои профили» — свой профиль подопечного. Без приложения — создать вручную."
        )
    }
}

private struct CreateManagedTraineeSheet: View {
    let coachProfile: Profile
    let profileService: ProfileServiceProtocol
    let linkService: CoachTraineeLinkServiceProtocol
    let onCreated: () -> Void
    let onCancel: () -> Void
    let onError: (String) -> Void

    @State private var name = ""
    @State private var selectedGender: ProfileGender = .male
    @State private var note = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    SettingsCard(title: "Новый подопечный") {
                        VStack(alignment: .leading, spacing: 12) {
                            AppTextField(label: "Имя", text: $name, textContentType: .name, autocapitalization: .words)

                            Picker("Пол", selection: $selectedGender) {
                                Text("Мужской").tag(ProfileGender.male)
                                Text("Женский").tag(ProfileGender.female)
                            }
                            .pickerStyle(.segmented)

                            AppTextField(label: "Заметка", text: $note, axis: .vertical, lineLimitRange: 3...6)
                        }
                    }
                }
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Создать")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { onCancel() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSaving ? "Создаю…" : "Создать") { create() }
                        .disabled(isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func create() {
        isSaving = true
        Task {
            do {
                let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
                // В Plan A сохраняем userId = uid тренера, чтобы managed-профиль не ломал текущий fetchProfiles(userId:).
                // Собственно ownership (для будущих строгих правил) задаётся ownerCoachProfileId.
                let managed = Profile(
                    id: "",
                    userId: coachProfile.userId,
                    type: .trainee,
                    name: trimmedName,
                    createdAt: Date(),
                    gender: selectedGender,
                    iconEmoji: nil,
                    ownerCoachProfileId: coachProfile.id,
                    mergedIntoProfileId: nil
                )
                let created = try await profileService.createProfile(managed)
                try await linkService.addLink(
                    coachProfileId: coachProfile.id,
                    traineeProfileId: created.id,
                    displayName: nil,
                    note: trimmedNote.isEmpty ? nil : trimmedNote
                )
                await MainActor.run {
                    isSaving = false
                    AppDesign.triggerSuccessHaptic()
                    onCreated()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    onError(AppErrors.userMessage(for: error))
                }
            }
        }
    }
}

private struct ClientCardRow: View {
    let icon: String
    let title: String
    let value: String?
    let showsDisclosure: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .center)
            Text(title)
                .foregroundStyle(.primary)
            Spacer()
            if let value, !value.isEmpty {
                Text(value)
                    .foregroundStyle(.secondary)
            }
            if showsDisclosure {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}
