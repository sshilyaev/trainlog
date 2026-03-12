//
//  ProfileSelectionView.swift
//  TrainLog
//

import SwiftUI

struct ProfileSelectionView: View {
    let profiles: [Profile]
    let authService: AuthServiceProtocol
    /// Отображаемое имя пользователя (displayName или email из Auth). Если не задано — берётся из authService.
    var accountDisplayName: String? = nil
    let onSelect: (Profile) -> Void
    let onCreate: () -> Void
    let onSignOut: () -> Void

    @State private var tooltipsResetFeedback = false
    @State private var passwordResetMessage: String?
    @State private var passwordResetError: String?
    @State private var showChangePasswordSheet = false
    @State private var showSignOutConfirmation = false
    @AppStorage("appTheme") private var appThemeRaw = AppTheme.system.rawValue

    private var displayName: String {
        accountDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? accountDisplayName!
            : (authService.currentUserDisplayName ?? "Аккаунт")
    }
    
    /// Managed-профили не показываются в списке профилей.
    private var selectableProfiles: [Profile] {
        profiles.filter { !$0.isManaged }
    }

    /// Все подсказки уже просмотрены — тогда показываем блок «Показать подсказки снова». Если есть непросмотренные — блок не показываем.
    private var shouldShowTooltipsResetBlock: Bool {
        TooltipId.allCases.allSatisfy { TooltipStorage.hasSeen($0) } || tooltipsResetFeedback
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    accountBlock
                    themeBlock
                    Group {
                        if selectableProfiles.isEmpty {
                            emptyState
                        } else {
                            profileListContent
                        }
                    }
                    .frame(maxWidth: .infinity)
                    createProfileRow
                    if shouldShowTooltipsResetBlock {
                        tooltipsResetBlock
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Мои профили")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .destructive) {
                        showSignOutConfirmation = true
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.subheadline)
                    }
                }
            }
            .alert("Выйти из аккаунта?", isPresented: $showSignOutConfirmation) {
                Button("Отмена", role: .cancel) { showSignOutConfirmation = false }
                Button("Выйти", role: .destructive) {
                    showSignOutConfirmation = false
                    onSignOut()
                }
            } message: {
                Text("Вы всегда сможете войти снова.")
            }
            .alert("Сменить пароль", isPresented: Binding(
                get: { passwordResetMessage != nil },
                set: { if !$0 { passwordResetMessage = nil } }
            )) {
                Button("OK") { passwordResetMessage = nil }
            } message: {
                if let msg = passwordResetMessage { Text(msg) }
            }
            .alert("Ошибка", isPresented: Binding(
                get: { passwordResetError != nil },
                set: { if !$0 { passwordResetError = nil } }
            )) {
                Button("OK") { passwordResetError = nil }
            } message: {
                if let msg = passwordResetError { Text(msg) }
            }
            .sheet(isPresented: $showChangePasswordSheet) {
                ChangePasswordSheet(
                    authService: authService,
                    onSuccess: {
                        showChangePasswordSheet = false
                        passwordResetMessage = "Пароль изменён."
                    },
                    onError: { passwordResetError = $0 },
                    onCancel: { showChangePasswordSheet = false }
                )
                .presentationDetents([.medium])
            }
        }
    }

    private var accountBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: AppDesign.rowSpacing) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(AppDesign.accent.opacity(0.9))
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayName)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                    if let email = authService.currentUserEmail, !email.isEmpty {
                        Text(email)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(AppDesign.cardPadding)
            Divider()
                .padding(.leading, AppDesign.cardPadding + 44 + AppDesign.rowSpacing)
            Button {
                showChangePasswordSheet = true
            } label: {
                HStack(spacing: AppDesign.rowSpacing) {
                    Image(systemName: "lock.rotation")
                        .foregroundStyle(.secondary)
                        .frame(width: 28, alignment: .center)
                    Text("Сменить пароль")
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, AppDesign.cardPadding)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
        .padding(.horizontal, AppDesign.cardPadding)
        .padding(.top, AppDesign.blockSpacing)
    }

    private var themeBlock: some View {
        SettingsCard(title: "Тема оформления") {
            SegmentedPicker(
                title: "",
                selection: $appThemeRaw,
                options: [
                    (AppTheme.light.rawValue, "Светлая"),
                    (AppTheme.dark.rawValue, "Тёмная"),
                    (AppTheme.system.rawValue, "Системная")
                ]
            )
        }
    }

    private var tooltipsResetBlock: some View {
        HStack(spacing: 6) {
            if tooltipsResetFeedback {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Сброшено")
                    .foregroundStyle(.green)
            } else {
                Button {
                    TooltipStorage.resetAll()
                    AppDesign.triggerSuccessHaptic()
                    tooltipsResetFeedback = true
                    Task {
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        await MainActor.run { tooltipsResetFeedback = false }
                    }
                } label: {
                    Text("Показать подсказки снова")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.top, AppDesign.blockSpacing)
    }

    private var emptyState: some View {
        let title: String = {
            let name = displayName
            if name != "Аккаунт" && !name.isEmpty {
                return "\(name), создайте первый профиль"
            }
            return "Создайте первый профиль"
        }()
        return ContentUnavailableView {
            Label(title, systemImage: "person.badge.plus")
        } description: {
            Text("Профиль нужен для замеров, целей и доступа тренера к вашим данным.")
        }
        .frame(maxWidth: .infinity)
    }

    private var createProfileRow: some View {
        Button(action: onCreate) {
            HStack(spacing: AppDesign.rowSpacing) {
                Image(systemName: "plus.circle.fill")
                    .font(.body)
                    .foregroundStyle(AppDesign.accent)
                    .frame(width: 28, alignment: .center)
                Text("Создать профиль")
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.horizontal, AppDesign.cardPadding)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
        .padding(.horizontal, AppDesign.cardPadding)
        .padding(.top, AppDesign.blockSpacing)
        .padding(.bottom, 24)
    }

    private var profileListContent: some View {
        let coaches = selectableProfiles.filter(\.isCoach)
        let trainees = selectableProfiles.filter(\.isTrainee)

        return VStack(spacing: AppDesign.blockSpacing) {
                if !coaches.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(coaches) { profile in
                            profileSelectionRow(profile: profile)
                            if profile.id != coaches.last?.id {
                                Divider().padding(.leading, 56)
                            }
                        }
                    }
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
                    .padding(.horizontal, AppDesign.cardPadding)
                }

                if !trainees.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(trainees) { profile in
                            profileSelectionRow(profile: profile)
                            if profile.id != trainees.last?.id {
                                Divider().padding(.leading, 56)
                            }
                        }
                    }
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
                    .padding(.horizontal, AppDesign.cardPadding)
                }
            }
            .padding(.top, AppDesign.sectionSpacing)
        }

    private func profileSelectionRow(profile: Profile) -> some View {
        Button {
            onSelect(profile)
        } label: {
            HStack(spacing: AppDesign.rowSpacing) {
                profileIconView(profile: profile)
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(profileSelectionSubtitle(profile))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, AppDesign.cardPadding)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func profileIconView(profile: Profile) -> some View {
        let color = profileIconColor(profile)
        return Group {
            if let emoji = profile.iconEmoji {
                Text(emoji)
                    .font(.title2)
                    .frame(width: 44, height: 44)
                    .background(color.opacity(0.2))
                    .clipShape(Circle())
            } else {
                Image(systemName: profile.isCoach ? "person.badge.key.fill" : "person.fill")
                    .font(.title2)
                    .foregroundStyle(color)
                    .frame(width: 44, height: 44)
                    .background(color.opacity(0.2))
                    .clipShape(Circle())
            }
        }
    }

    private func profileIconColor(_ profile: Profile) -> Color {
        if let gender = profile.gender {
            switch gender { case .female: return .pink; case .male: return .blue }
        }
        return profile.isCoach ? AppDesign.accent : .green
    }

    private func profileSelectionSubtitle(_ profile: Profile) -> String {
        if profile.isCoach, let gym = profile.gymName, !gym.isEmpty {
            return "Тренер · \(gym)"
        }
        return profile.type == .coach ? "Тренер" : "Дневник"
    }
}

// MARK: - Смена пароля в приложении

private struct ChangePasswordSheet: View {
    let authService: AuthServiceProtocol
    let onSuccess: () -> Void
    let onError: (String) -> Void
    let onCancel: () -> Void

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isChanging = false

    private var canSubmit: Bool {
        !currentPassword.isEmpty && newPassword.count >= 6 && newPassword == confirmPassword
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Текущий пароль")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        PasswordField(title: "", text: $currentPassword)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Новый пароль")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        PasswordField(title: "", text: $newPassword, textContentType: .newPassword)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Повторите новый пароль")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        PasswordField(title: "", text: $confirmPassword, textContentType: .newPassword)
                    }
                    if newPassword.isEmpty == false && newPassword != confirmPassword {
                        Text("Пароли не совпадают")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    if newPassword.count > 0 && newPassword.count < 6 {
                        Text("Не менее 6 символов")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding(AppDesign.cardPadding)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Сменить пароль")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { onCancel() }
                        .disabled(isChanging)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isChanging {
                        ProgressView()
                            .scaleEffect(0.9)
                    } else {
                        Button("Изменить") { submit() }
                            .disabled(!canSubmit)
                            .fontWeight(.semibold)
                    }
                }
            }
        }
    }

    private func submit() {
        guard canSubmit else { return }
        isChanging = true
        Task {
            do {
                try await authService.changePassword(currentPassword: currentPassword, newPassword: newPassword)
                await MainActor.run {
                    AppDesign.triggerSuccessHaptic()
                    onSuccess()
                }
            } catch {
                await MainActor.run {
                    onError(AppErrors.userMessage(for: error))
                }
            }
            await MainActor.run { isChanging = false }
        }
    }
}

// MARK: - Строка профиля (для списков в других экранах)

struct ProfileRow: View {
    let profile: Profile
    /// Если задано, отображается вместо profile.name (для списка подопечных у тренера).
    var displayName: String? = nil
    /// Заметка тренера о подопечном — показывается под именем в списке подопечных.
    var note: String? = nil
    /// Показывать ли подпись «Тренер»/«Дневник».
    var showTypeLabel: Bool = true

    private var title: String { displayName ?? profile.name }

    /// Строка под заголовком: зал (у тренера), пол и/или заметка.
    private var profileRowSubtitle: String? {
        var parts = [profile.displaySubtitle, profile.gender?.displayName].compactMap { $0 }
        if let n = note?.trimmingCharacters(in: .whitespacesAndNewlines), !n.isEmpty {
            parts.append(n)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// Цвет иконки по полу: женский — розовый, мужской — голубой, не указан — как тип (тренер/дневник).
    private var profileIconColor: Color {
        if let gender = profile.gender {
            switch gender {
            case .female: return .pink
            case .male: return .blue
            }
        }
        return profile.isCoach ? AppDesign.accent : .green
    }

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let emoji = profile.iconEmoji {
                    Text(emoji)
                        .font(.title2)
                        .frame(width: 44, height: 44)
                        .background(profileIconColor.opacity(0.15))
                        .clipShape(Circle())
                } else {
                    Image(systemName: profile.isCoach ? "person.badge.key.fill" : "person.fill")
                        .font(.title2)
                        .foregroundStyle(profileIconColor)
                        .frame(width: 44, height: 44)
                        .background(profileIconColor.opacity(0.15))
                        .clipShape(Circle())
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                if let subtitle = profileRowSubtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if showTypeLabel {
                    Text(profile.type == .coach ? "Тренер" : "Дневник")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ProfileSelectionView(
        profiles: [
            Profile(id: "1", userId: "u1", type: .coach, name: "Зал на Арбате", gymName: "Фитнес Арбат"),
            Profile(id: "2", userId: "u1", type: .trainee, name: "Мой дневник")
        ],
        authService: MockAuthService(),
        accountDisplayName: "Сергей",
        onSelect: { _ in },
        onCreate: {},
        onSignOut: {}
    )
}
