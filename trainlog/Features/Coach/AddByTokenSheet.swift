//
//  AddByTokenSheet.swift
//  TrainLog
//

import SwiftUI

/// Тренер вводит код, сгенерированный подопечным → привязка к текущему coach-профилю. Используется как sheet.
struct AddByTokenSheet: View {
    let coachProfile: Profile
    let tokenService: ConnectionTokenServiceProtocol
    let linkService: CoachTraineeLinkServiceProtocol
    let profileService: ProfileServiceProtocol
    let onLinkAdded: () -> Void
    let onDismiss: () -> Void

    @State private var codeInput = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var traineeToConfirm: Profile?
    @FocusState private var codeFieldFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    SettingsCard(title: "Ввести код") {
                        TextField("Код из приложения подопечного", text: $codeInput)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .focused($codeFieldFocused)
                            .textFieldStyle(.roundedBorder)

                        PrimaryActionButton(
                            title: "Подтвердить код",
                            isLoading: isLoading,
                            isDisabled: codeInput.trimmingCharacters(in: .whitespacesAndNewlines).count < 4
                        ) {
                            Task { await submitCode(codeInput.trimmingCharacters(in: .whitespacesAndNewlines)) }
                        }

                        if let msg = errorMessage, !msg.isEmpty {
                            Text(msg)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Text("Подопечный создаёт временный код в разделе «Подключить по коду» в своём профиле.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Добавить по коду")
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
            .alert("Привязать подопечного?", isPresented: Binding(
                get: { traineeToConfirm != nil },
                set: { if !$0 { traineeToConfirm = nil } }
            )) {
                Button("Отмена", role: .cancel) { traineeToConfirm = nil }
                Button("Привязать") {
                    if let p = traineeToConfirm { Task { await confirmLink(trainee: p) } }
                    traineeToConfirm = nil
                }
            } message: {
                if let p = traineeToConfirm {
                    Text("Добавить \(p.name) в список подопечных?")
                }
            }
        }
    }

    private func submitCode(_ code: String) async {
        guard !code.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            guard let token = try await tokenService.getToken(token: code.uppercased()) else {
                await MainActor.run { errorMessage = "Код не найден или истёк." }
                return
            }
            guard token.isValid else {
                await MainActor.run { errorMessage = "Код уже использован или истёк." }
                return
            }
            guard let trainee = try await profileService.fetchProfile(id: token.traineeProfileId) else {
                await MainActor.run { errorMessage = "Профиль подопечного не найден." }
                return
            }
            await MainActor.run { traineeToConfirm = trainee; pendingToken = code.uppercased() }
        } catch {
                await MainActor.run { errorMessage = AppErrors.userMessage(for: error) }
        }
    }

    @State private var pendingToken: String?

    private func confirmLink(trainee: Profile) async {
        guard let token = pendingToken else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false; pendingToken = nil }
        do {
            try await linkService.addLink(coachProfileId: coachProfile.id, traineeProfileId: trainee.id, displayName: nil, note: nil)
            try await tokenService.markTokenUsed(token: token)
            await MainActor.run { onLinkAdded() }
        } catch {
                await MainActor.run { errorMessage = AppErrors.userMessage(for: error) }
        }
    }
}

// MARK: - Полноэкранная версия (push из AddTraineeView)

private struct LinkFormItem: Identifiable, Hashable {
    let trainee: Profile
    let token: String
    var id: String { trainee.id + token }
}

struct AddByCodeView: View {
    let coachProfile: Profile
    let tokenService: ConnectionTokenServiceProtocol
    let linkService: CoachTraineeLinkServiceProtocol
    let profileService: ProfileServiceProtocol
    let onLinkAdded: () -> Void
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var codeInput = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var traineeToConfirm: Profile?
    @State private var pendingToken: String?
    @State private var linkFormItem: LinkFormItem?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SettingsCard(title: "Ввести код") {
                    TextField("Код из приложения подопечного", text: $codeInput)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)

                    PrimaryActionButton(
                        title: "Подтвердить код",
                        isLoading: isLoading,
                        isDisabled: codeInput.trimmingCharacters(in: .whitespacesAndNewlines).count < 4
                    ) {
                        Task { await submitCode(codeInput.trimmingCharacters(in: .whitespacesAndNewlines)) }
                    }

                    if let msg = errorMessage, !msg.isEmpty {
                        Text(msg)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Text("Подопечный создаёт временный код в разделе «Подключить по коду» в своём профиле.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Добавить по коду")
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
        .alert("Привязать подопечного?", isPresented: Binding(
            get: { traineeToConfirm != nil },
            set: { if !$0 { traineeToConfirm = nil } }
        )) {
            Button("Отмена", role: .cancel) { traineeToConfirm = nil }
            Button("Привязать") {
                if let p = traineeToConfirm, let t = pendingToken {
                    linkFormItem = LinkFormItem(trainee: p, token: t)
                }
                traineeToConfirm = nil
                pendingToken = nil
            }
        } message: {
            if let p = traineeToConfirm {
                Text("Добавить \(p.name) в список подопечных?")
            }
        }
        .navigationDestination(item: $linkFormItem) { item in
            TraineeLinkFormView(
                trainee: item.trainee,
                coachProfileId: coachProfile.id,
                linkService: linkService,
                tokenService: tokenService,
                pendingToken: item.token,
                onLinkAdded: {
                    linkFormItem = nil
                    onLinkAdded()
                },
                onDismiss: { linkFormItem = nil }
            )
        }
    }

    private func submitCode(_ code: String) async {
        guard !code.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            guard let token = try await tokenService.getToken(token: code.uppercased()) else {
                await MainActor.run { errorMessage = "Код не найден или истёк." }
                return
            }
            guard token.isValid else {
                await MainActor.run { errorMessage = "Код уже использован или истёк." }
                return
            }
            guard let trainee = try await profileService.fetchProfile(id: token.traineeProfileId) else {
                await MainActor.run { errorMessage = "Профиль подопечного не найден." }
                return
            }
            await MainActor.run { traineeToConfirm = trainee; pendingToken = code.uppercased() }
        } catch {
                await MainActor.run { errorMessage = AppErrors.userMessage(for: error) }
        }
    }
}
