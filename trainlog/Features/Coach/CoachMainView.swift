//
//  CoachMainView.swift
//  TrainLog
//

import SwiftUI

struct CoachMainView: View {
    let profile: Profile
    let onSwitchProfile: () -> Void
    let onDeleteProfile: () async -> Void
    let onProfileUpdated: (Profile) -> Void
    let linkService: CoachTraineeLinkServiceProtocol
    let profileService: ProfileServiceProtocol
    let measurementService: MeasurementServiceProtocol
    let goalService: GoalServiceProtocol
    let connectionTokenService: ConnectionTokenServiceProtocol
    let membershipService: MembershipServiceProtocol
    let visitService: VisitServiceProtocol
    let managedTraineeMergeService: ManagedTraineeMergeServiceProtocol
    let myTraineeProfiles: [Profile]

    @State private var traineeItems: [TraineeItem] = []
    @State private var searchText = ""
    @State private var selectedTab = 1
    @State private var showDeleteProfileConfirmation = false
    @State private var showEditProfile = false
    @State private var pendingProfileEdit: EditProfileData?
    @State private var isDeleting = false
    @State private var isLoadingTrainees = false
    @State private var showArchiveConfirmation = false
    @State private var archiveTarget: (item: TraineeItem, archived: Bool)?
    @State private var isArchiving = false

    private var filteredTraineeItems: [TraineeItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let base = query.isEmpty ? traineeItems : traineeItems.filter { item in
            let name = item.profile.name.lowercased()
            let displayName = (item.link.displayName ?? "").lowercased()
            let note = (item.link.note ?? "").lowercased()
            return name.contains(query) || displayName.contains(query) || note.contains(query)
        }
        return base.sorted { !$0.link.isArchived && $1.link.isArchived }
    }

    private var activeTraineeItems: [TraineeItem] {
        filteredTraineeItems.filter { !$0.link.isArchived }
    }

    private var archivedTraineeItems: [TraineeItem] {
        filteredTraineeItems.filter(\.link.isArchived)
    }

    // MARK: - Вкладка «Подопечные» (переписана с нуля)

    private var traineesTabContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                addTraineeButton
                if !filteredTraineeItems.isEmpty {
                    if !activeTraineeItems.isEmpty {
                        activeTraineesBlock
                    }
                    if !archivedTraineeItems.isEmpty {
                        archivedTraineesBlock
                    }
                } else if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ContentUnavailableView(
                        "Нет результатов",
                        systemImage: "magnifyingglass",
                        description: Text("По запросу «\(searchText)» никого не найдено.")
                    )
                    .padding(.vertical, 32)
                } else if traineeItems.isEmpty {
                    ContentUnavailableView(
                        "Пока нет подопечных",
                        systemImage: "person.3.fill",
                        description: Text("Добавьте подопечного по коду или свой профиль.")
                    )
                    .padding(.vertical, 32)
                }
            }
            .padding(.horizontal, AppDesign.cardPadding)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var addTraineeButton: some View {
        NavigationLink(destination: AddTraineeView(
            coachProfile: profile,
            myTraineeProfiles: myTraineeProfiles,
            linkedTraineeIds: Set(traineeItems.map(\.profile.id)),
            linkService: linkService,
            profileService: profileService,
            connectionTokenService: connectionTokenService,
            onLinkAdded: {
                Task {
                    await MainActor.run { selectedTab = 0 }
                    await MainActor.run { isLoadingTrainees = true }
                    await loadTrainees()
                    await MainActor.run { isLoadingTrainees = false }
                }
            }
        )) {
            AddActionRow(title: "Добавить подопечного", systemImage: "person.badge.plus")
        }
        .buttonStyle(PressableButtonStyle())
        .frame(maxWidth: .infinity)
        .padding(AppDesign.cardPadding)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
        .padding(.top, AppDesign.blockSpacing)
    }

    private var activeTraineesBlock: some View {
        VStack(spacing: AppDesign.blockSpacing) {
            ForEach(activeTraineeItems) { item in
                traineeRow(item: item, isArchived: false)
            }
        }
        .padding(.top, AppDesign.blockSpacing)
    }

    private var archivedTraineesBlock: some View {
        VStack(alignment: .leading, spacing: AppDesign.blockSpacing) {
            Text("В архиве")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            ForEach(archivedTraineeItems) { item in
                traineeRow(item: item, isArchived: true)
            }
        }
        .padding(.top, AppDesign.sectionSpacing)
    }

    private func traineeRow(item: TraineeItem, isArchived: Bool) -> some View {
        NavigationLink {
            ClientCardView(
                trainee: item.profile,
                note: item.link.note,
                isArchived: item.link.isArchived,
                profileService: profileService,
                measurementService: measurementService,
                goalService: goalService,
                membershipService: membershipService,
                visitService: visitService,
                connectionTokenService: connectionTokenService,
                managedTraineeMergeService: managedTraineeMergeService,
                coachProfileId: profile.id,
                linkService: linkService,
                onUnlink: { Task { await loadTrainees() } },
                onArchiveChanged: { await loadTrainees() }
            )
        } label: {
            TraineeCardRow(profile: item.profile, displayName: item.link.displayName, note: item.link.note, isArchived: isArchived)
        }
        .buttonStyle(PressableButtonStyle())
        .contextMenu {
            if isArchived {
                Button {
                    archiveTarget = (item: item, archived: false)
                    showArchiveConfirmation = true
                } label: {
                    Label("Вернуть из архива", systemImage: "archivebox.fill")
                }
            } else {
                Button {
                    archiveTarget = (item: item, archived: true)
                    showArchiveConfirmation = true
                } label: {
                    Label("В архив", systemImage: "archivebox")
                }
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                traineesTabContent
                    .navigationTitle("Подопечные")
                    .searchable(text: $searchText, prompt: "По имени или заметке")
                    .refreshable { await loadTrainees() }
            }
            .tooltip(
                id: .coachTraineesList,
                title: "Подопечные",
                message: "Добавьте по коду или свой профиль. Поиск по имени или заметке."
            )
            .tabItem {
                Image(systemName: "person.3.fill")
                Text("Подопечные")
            }
            .tag(0)

            profileTab
                .tag(1)
        }
        .tabViewStyle(.automatic)
        .task {
            await MainActor.run { isLoadingTrainees = true }
            await loadTrainees()
            await MainActor.run { isLoadingTrainees = false }
        }
        .alert(isPresented: $showArchiveConfirmation) {
            let isToArchive = archiveTarget?.archived == true
            return Alert(
                title: Text(isToArchive ? "В архив?" : "Вернуть из архива?"),
                message: Text(isToArchive ? "Клиент перестал заниматься — переместить в архив?" : "Вернуть клиента в активные?"),
                primaryButton: .destructive(Text(isToArchive ? "В архив" : "Вернуть"), action: {
                    guard let target = archiveTarget else { return }
                    archiveTarget = nil
                    Task {
                        await MainActor.run { isArchiving = true }
                        await setArchived(target.item, target.archived)
                        await MainActor.run { isArchiving = false }
                    }
                }),
                secondaryButton: .cancel({
                    archiveTarget = nil
                })
            )
        }
        .overlay {
            if isDeleting {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .overlay {
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.2)
                                .tint(.white)
                            Text("Удаляю профиль")
                                .font(.subheadline)
                                .foregroundStyle(.white)
                        }
                    }
            } else if isLoadingTrainees {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .overlay {
                        VStack(spacing: AppDesign.blockSpacing) {
                            ProgressView()
                                .scaleEffect(AppDesign.loadingScale)
                                .tint(.white)
                            Text("Загружаю подопечных")
                                .font(AppDesign.loadingMessageFont)
                                .foregroundStyle(.white)
                        }
                    }
            } else if isArchiving {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .overlay {
                        VStack(spacing: AppDesign.blockSpacing) {
                            ProgressView()
                                .scaleEffect(AppDesign.loadingScale)
                                .tint(.white)
                            Text("Обновляю…")
                                .font(AppDesign.loadingMessageFont)
                                .foregroundStyle(.white)
                        }
                    }
            }
        }
        .allowsHitTesting(!isDeleting && !isLoadingTrainees && !isArchiving)
    }

    private var profileTab: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    profileHeader
                    blockGenderGym
                    blockDelete
                }
                .padding(.bottom, 24)
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
                    await MainActor.run { pendingProfileEdit = data }
                }
            }
        }
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
            Text("Профиль тренера и связь с подопечными будут удалены. Это действие нельзя отменить.")
        }
        .tabItem {
            Image(systemName: "person.crop.circle.fill")
            Text("Профиль")
        }
    }

    private var profileHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(profileIconColor.opacity(0.2))
                    .frame(width: 80, height: 80)
                if let emoji = profile.iconEmoji {
                    Text(emoji)
                        .font(.system(size: 40))
                } else {
                    Image(systemName: "person.badge.key.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(profileIconColor)
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

    private var profileIconColor: Color {
        profile.isCoach ? AppDesign.accent : .green
    }

    private var blockGenderGym: some View {
        VStack(spacing: 0) {
            ActionBlockRow(icon: "person.fill", title: "Пол", value: profile.gender?.displayName ?? "Не указан")
            if profile.isCoach, let gym = profile.gymName, !gym.isEmpty {
                Divider()
                    .padding(.leading, 52)
                ActionBlockRow(icon: "building.2", title: "Зал", value: gym)
            }
        }
        .actionBlockStyle()
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
                        Text("Удаляется только этот профиль тренера и связь с подопечными. Вход в аккаунт сохранится.")
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

    private func loadTrainees() async {
        do {
            let links = try await linkService.fetchLinks(coachProfileId: profile.id)
            var items: [TraineeItem] = []
            for link in links {
                if let p = try await profileService.fetchProfile(id: link.traineeProfileId) {
                    items.append(TraineeItem(link: link, profile: p))
                }
            }
            await MainActor.run { traineeItems = items }
        } catch {
            await MainActor.run { traineeItems = [] }
        }
    }

    private func setArchived(_ item: TraineeItem, _ archived: Bool) async {
        do {
            try await linkService.setArchived(coachProfileId: profile.id, traineeProfileId: item.profile.id, isArchived: archived)
            await loadTrainees()
        } catch { }
    }
}

private struct TraineeItem: Identifiable {
    let link: CoachTraineeLink
    let profile: Profile
    var id: String { link.id }
}

private struct TraineeCardRow: View {
    let profile: Profile
    let displayName: String?
    let note: String?
    var isArchived: Bool = false

    private var title: String { displayName ?? profile.name }
    /// Заметка тренера — показывается в одну строку с именем.
    private var noteTrimmed: String? {
        let t = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return t.isEmpty ? nil : t
    }
    private var genderIcon: String? {
        switch profile.gender {
        case .female: return "figure.dress"
        case .male: return "figure.stand"
        case nil: return nil
        }
    }
    private var profileIconColor: Color {
        if let g = profile.gender {
            switch g { case .female: return .pink; case .male: return .blue }
        }
        return .green
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                if let emoji = profile.iconEmoji {
                    Text(emoji)
                        .font(.title2)
                        .frame(width: 44, height: 44)
                        .background(profileIconColor.opacity(0.15))
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.fill")
                        .font(.title2)
                        .foregroundStyle(profileIconColor)
                        .frame(width: 44, height: 44)
                        .background(profileIconColor.opacity(0.15))
                        .clipShape(Circle())
                }
                if profile.isManaged {
                    Image(systemName: "person.crop.circle.badge.clock")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .offset(x: 2, y: 2)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if let icon = genderIcon {
                        Image(systemName: icon)
                            .font(.caption)
                            .foregroundStyle(isArchived ? .secondary : profileIconColor)
                    }
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(isArchived ? .secondary : .primary)
                    if let n = noteTrimmed {
                        Text(" · " + n)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    if isArchived {
                        Image(systemName: "archivebox.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 12)
        )
    }
}

#Preview {
    CoachMainView(
        profile: Profile(id: "1", userId: "u1", type: .coach, name: "Зал Арбат", gymName: "Фитнес Арбат"),
        onSwitchProfile: {},
        onDeleteProfile: { },
        onProfileUpdated: { _ in },
        linkService: MockCoachTraineeLinkService(),
        profileService: MockProfileService(),
        measurementService: MockMeasurementService(),
        goalService: MockGoalService(),
        connectionTokenService: MockConnectionTokenService(),
        membershipService: MockMembershipService(),
        visitService: MockVisitService(),
        managedTraineeMergeService: MockManagedTraineeMergeService(),
        myTraineeProfiles: []
    )
}
