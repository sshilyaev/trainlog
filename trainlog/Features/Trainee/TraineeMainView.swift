//
//  TraineeMainView.swift
//  TrainLog
//

import SwiftUI

struct TraineeMainView: View {
    let profile: Profile
    let measurementService: MeasurementServiceProtocol
    let goalService: GoalServiceProtocol
    let connectionTokenService: ConnectionTokenServiceProtocol
    let profileService: ProfileServiceProtocol
    let membershipService: MembershipServiceProtocol
    let visitService: VisitServiceProtocol
    let linkService: CoachTraineeLinkServiceProtocol
    let onSwitchProfile: () -> Void
    let onDeleteProfile: () async -> Void
    let onProfileUpdated: (Profile) -> Void

    @State private var showAddMeasurement = false
    @State private var goals: [Goal] = []
    @State private var measurements: [Measurement] = []
    @State private var showAddGoal = false
    @State private var showConnectionTokenSheet = false
    @State private var showDeleteProfileConfirmation = false
    @State private var showEditProfile = false
    @State private var pendingProfileEdit: EditProfileData?
    @State private var isDeleting = false
    @State private var selectedTab = 2
    @State private var errorMessage: String?
    /// Пока true — дашборд показывает лоадер до первой загрузки замеров и целей.
    @State private var isDashboardLoading = true

    var body: some View {
        TabView(selection: $selectedTab) {
            dashboardTab
                .tag(0)
            workoutsTab
                .tag(1)
            profileTab
                .tag(2)
        }
        .tabViewStyle(.automatic)
        .fullScreenCover(isPresented: $showAddMeasurement) {
            AddMeasurementView(
                profile: profile,
                lastMeasurement: measurements.sorted { $0.date > $1.date }.first,
                onSave: { m in
                    await saveMeasurement(m)
                    await MainActor.run { showAddMeasurement = false }
                },
                onCancel: { showAddMeasurement = false }
            )
        }
        .fullScreenCover(isPresented: $showAddGoal) {
            AddGoalView(
                profile: profile,
                onSave: { goals in
                    Task {
                        for g in goals { await saveGoal(g) }
                        await MainActor.run { showAddGoal = false }
                    }
                },
                onCancel: { showAddGoal = false }
            )
        }
        .sheet(isPresented: $showConnectionTokenSheet) {
            ConnectionTokenSheet(
                profile: profile,
                tokenService: connectionTokenService,
                onDismiss: { showConnectionTokenSheet = false }
            )
        }
        .task {
            await loadMeasurements()
            await loadGoals()
            await MainActor.run { isDashboardLoading = false }
        }
        .overlay {
            if isDeleting {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .overlay {
                        VStack(spacing: AppDesign.blockSpacing) {
                            ProgressView()
                                .scaleEffect(AppDesign.loadingScale)
                                .tint(.white)
                            Text("Удаляю профиль")
                                .font(AppDesign.loadingMessageFont)
                                .foregroundStyle(.white)
                        }
                    }
            }
        }
        .allowsHitTesting(!isDeleting)
        .alert("Удалить профиль?", isPresented: $showDeleteProfileConfirmation) {
            Button("Отмена", role: .cancel) { showDeleteProfileConfirmation = false }
            Button("Удалить", role: .destructive) {
                showDeleteProfileConfirmation = false
                Task {
                    isDeleting = true
                    await onDeleteProfile()
                    await MainActor.run { isDeleting = false }
                }
            }
        } message: {
            Text("Все замеры и цели этого профиля будут удалены. Это действие нельзя отменить.")
        }
        .alert("Ошибка", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            if let msg = errorMessage { Text(msg) }
        }
    }

    private var workoutsTab: some View {
        TraineeWorkoutsView(
            profile: profile,
            linkService: linkService,
            visitService: visitService,
            membershipService: membershipService,
            profileService: profileService
        )
        .tooltip(
            id: .traineeWorkouts,
            title: "Мои тренировки",
            message: "Здесь отображаются посещения и абонементы, которые вносит тренер. Экран обновляется по мере заполнения."
        )
        .tabItem {
            Image(systemName: "figure.run")
            Text("Мои тренировки")
        }
    }

    private var profileTab: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    profileHeader
                    blockGender
                    blockConnectAndGoal
                    blockDelete
                }
                .padding(.bottom, AppDesign.sectionSpacing)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: onSwitchProfile) {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.subheadline)
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileView(
                profileId: profile.id,
                userId: profile.userId,
                profileType: profile.type,
                initialName: profile.name,
                initialGymName: profile.gymName ?? "",
                createdAt: profile.createdAt,
                initialGender: profile.gender,
                initialIconEmoji: profile.iconEmoji,
                onSave: { data in
                    pendingProfileEdit = data
                    showEditProfile = false
                },
                onCancel: { showEditProfile = false },
                onDismiss: { showEditProfile = false }
            )
        }
        .onChange(of: showEditProfile) { _, closed in
            guard closed == false, let data = pendingProfileEdit else { return }
            let current = profile
            let updated = Profile(
                id: current.id,
                userId: current.userId,
                type: current.type,
                name: data.name,
                gymName: current.type == .coach ? data.gymName : nil,
                createdAt: current.createdAt,
                gender: data.gender,
                iconEmoji: data.iconEmoji
            )
            pendingProfileEdit = nil
            Task {
                do {
                    try await profileService.updateProfile(updated)
                    await MainActor.run { onProfileUpdated(updated) }
                } catch {
                    await MainActor.run { errorMessage = AppErrors.userMessage(for: error) }
                    await MainActor.run { pendingProfileEdit = data }
                }
            }
        }
        .tabItem {
            Image(systemName: "person.crop.circle.fill")
            Text("Профиль")
        }
        .tooltip(
            id: .traineeGoals,
            title: "Цели и подключение",
            message: "«Поделиться с тренером» — создайте код для подключения к тренеру. «Добавить цель» — задайте целевое значение и дату по любой метрике."
        )
    }

    private var profileHeader: some View {
        VStack(spacing: AppDesign.rowSpacing) {
            ZStack {
                Circle()
                    .fill(AppDesign.profileAccent.opacity(AppDesign.profileAccentOpacity))
                    .frame(width: 80, height: 80)
                if let emoji = profile.iconEmoji {
                    Text(emoji)
                        .font(.system(size: 40))
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(AppDesign.profileAccent)
                }
            }
            Button {
                showEditProfile = true
            } label: {
                HStack(spacing: 6) {
                    Text(profile.name)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.primary)
                    Image(systemName: "pencil")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(PressableButtonStyle())
        }
        .padding(.vertical, 20)
    }

    private var blockGender: some View {
        ActionBlockRow(icon: "person.fill", title: "Пол", value: profile.gender?.displayName ?? "Не указан")
            .actionBlockStyle()
    }

    private var blockConnectByCode: some View {
        Button(action: { showConnectionTokenSheet = true }) {
            RectangularBlockContent(
                icon: "key",
                title: "Поделиться с тренером",
                value: nil,
                iconColor: AppDesign.accent
            )
        }
        .buttonStyle(PressableButtonStyle())
        .rectangularBlockStyle()
        .frame(maxWidth: .infinity)
    }

    private var blockAddGoal: some View {
        Button(action: { showAddGoal = true }) {
            RectangularBlockContent(
                icon: "target",
                title: "Добавить цель",
                value: nil,
                iconColor: AppDesign.accent
            )
        }
        .buttonStyle(PressableButtonStyle())
        .rectangularBlockStyle()
        .frame(maxWidth: .infinity)
    }

    private var blockConnectAndGoal: some View {
        HStack(spacing: AppDesign.rectangularBlockSpacing) {
            blockConnectByCode
            blockAddGoal
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, AppDesign.cardPadding)
        .padding(.top, AppDesign.blockSpacing)
    }

    private var blockDelete: some View {
        SettingsCard(title: "Управление профилем") {
            Button {
                showDeleteProfileConfirmation = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "trash")
                        .foregroundStyle(.secondary)
                        .frame(width: 28, alignment: .center)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Удалить профиль")
                            .foregroundStyle(.red)
                        Text("Удаляется только этот профиль. Замеры и цели будут удалены. Вход в аккаунт сохранится.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    private var dashboardTab: some View {
        Group {
            if isDashboardLoading {
                NavigationStack {
                    LoadingView(message: "Загрузка…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemGroupedBackground))
                }
            } else {
                DashboardView(
                    profile: profile,
                    measurements: measurements,
                    goals: goals,
                    onAddMeasurement: { showAddMeasurement = true },
                    onDeleteMeasurement: { m in Task { await deleteMeasurement(m) } }
                )
            }
        }
        .tooltip(
            id: .traineeMeasurements,
            title: "Мои замеры",
            message: "Добавляйте замеры и смотрите историю. Тап по карточке метрики откроет график. Цели отображаются на графиках."
        )
        .tabItem {
            Image(systemName: "chart.bar.doc.horizontal.fill")
            Text("Мои замеры")
        }
    }

    private func loadMeasurements() async {
        do {
            let list = try await measurementService.fetchMeasurements(profileId: profile.id)
            await MainActor.run { measurements = list }
        } catch {
            await MainActor.run { measurements = [] }
        }
    }

    private func loadGoals() async {
        do {
            let list = try await goalService.fetchGoals(profileId: profile.id)
            await MainActor.run { goals = list }
        } catch {
            await MainActor.run { goals = [] }
        }
    }

    private func saveMeasurement(_ m: Measurement) async {
        do {
            try await measurementService.saveMeasurement(m)
            await loadMeasurements()
            await MainActor.run { AppDesign.triggerSuccessHaptic() }
        } catch {
            await MainActor.run { errorMessage = AppErrors.userMessage(for: error) }
        }
    }

    private func saveGoal(_ g: Goal) async {
        do {
            try await goalService.saveGoal(g)
            await loadGoals()
            await MainActor.run { AppDesign.triggerSuccessHaptic() }
        } catch {
            await MainActor.run { errorMessage = AppErrors.userMessage(for: error) }
        }
    }

    private func deleteGoal(_ goal: Goal) async {
        do {
            try await goalService.deleteGoal(goal)
            await loadGoals()
        } catch {
            await MainActor.run { errorMessage = AppErrors.userMessage(for: error) }
        }
    }

    private func deleteMeasurement(_ m: Measurement) async {
        do {
            try await measurementService.deleteMeasurement(m)
            await loadMeasurements()
        } catch {
            await MainActor.run { errorMessage = AppErrors.userMessage(for: error) }
        }
    }
}

#Preview {
    TraineeMainView(
        profile: Profile(id: "1", userId: "u1", type: .trainee, name: "Мой дневник"),
        measurementService: MockMeasurementService(),
        goalService: MockGoalService(),
        connectionTokenService: MockConnectionTokenService(),
        profileService: MockProfileService(),
        membershipService: MockMembershipService(),
        visitService: MockVisitService(),
        linkService: MockCoachTraineeLinkService(),
        onSwitchProfile: {},
        onDeleteProfile: { },
        onProfileUpdated: { _ in }
    )
}
