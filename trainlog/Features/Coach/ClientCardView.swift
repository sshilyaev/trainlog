//
//  ClientCardView.swift
//  TrainLog
//

import SwiftUI
import UIKit

struct ClientCardView: View {
    let trainee: Profile
    var note: String? = nil
    var isArchived: Bool = false
    let profileService: ProfileServiceProtocol
    let measurementService: MeasurementServiceProtocol
    let goalService: GoalServiceProtocol
    let membershipService: MembershipServiceProtocol
    let visitService: VisitServiceProtocol
    let connectionTokenService: ConnectionTokenServiceProtocol
    let managedTraineeMergeService: ManagedTraineeMergeServiceProtocol
    /// Тренер: для отображения кнопки «Отвязать». Если nil — кнопка не показывается.
    var coachProfileId: String? = nil
    var linkService: CoachTraineeLinkServiceProtocol? = nil
    var onUnlink: (() -> Void)? = nil
    var onArchiveChanged: (() async -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var measurements: [Measurement] = []
    @State private var goals: [Goal] = []
    @State private var isLoading = true
    @State private var activeMembership: Membership?
    @State private var visits: [Visit] = []
    @State private var memberships: [Membership] = []
    @State private var showUnlinkConfirmation = false
    @State private var isUnlinking = false
    @State private var isArchiving = false
    @State private var showArchiveConfirmation = false
    @State private var archiveTarget: Bool = false
    @State private var isSavingVisit = false
    @State private var showMergeSheet = false
    @State private var errorMessage: String?

    private var goalsByType: [MeasurementType: [Goal]] {
        Dictionary(grouping: goals) { MeasurementType(rawValue: $0.measurementType) ?? .weight }
    }

    private var mainContent: some View {
        Group {
            if isLoading {
                loadingView
            } else {
                cardList
            }
        }
    }

    private var loadingView: some View {
        LoadingView(message: "Загрузка данных…")
    }

    private var cardList: some View {
        ScrollView {
            VStack(spacing: 0) {
                // О подопечном (пол и заметка) — блок как в профиле (пол/зал)
                VStack(spacing: 0) {
                    ClientCardRow(
                        icon: "person.fill",
                        title: "Пол",
                        value: trainee.gender?.displayName ?? "Не указан",
                        showsDisclosure: false
                    )
                    Divider()
                        .padding(.leading, 40)
                    ClientCardRow(
                        icon: "note.text",
                        title: "Заметка",
                        value: (note?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? "Нет" : $0 } ?? "Нет",
                        showsDisclosure: false
                    )
                }
                .actionBlockStyle()

                // Замеры и графики (дашборд подопечного)
                Group {
                    if trainee.isManaged && trainee.mergedIntoProfileId == nil {
                        UnavailableRowWithHint(
                            icon: "ruler.fill",
                            title: "Замеры и графики",
                            hint: "Объедините с профилем клиента по коду — тогда замеры станут доступны."
                        )
                    } else {
                        NavigationLink {
                            DashboardView(
                                profile: trainee,
                                measurements: measurements,
                                goals: goals,
                                onAddMeasurement: {},
                                onDeleteMeasurement: { m in
                                    Task {
                                        try? await measurementService.deleteMeasurement(m)
                                        await loadData()
                                    }
                                },
                                showAddMeasurementButton: false,
                                embedInNavigationStack: false,
                                navigationTitle: "Замеры"
                            )
                        } label: {
                            ClientCardRow(
                                icon: "ruler.fill",
                                title: "Замеры и графики",
                                value: measurements.isEmpty ? nil : "\(measurements.count)",
                                showsDisclosure: true
                            )
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
                .actionBlockStyle()

                // Абонементы и Посещения — прямоугольные блоки (плитки)
                if let coachId = coachProfileId {
                    HStack(spacing: AppDesign.rectangularBlockSpacing) {
                        NavigationLink {
                            ClientMembershipsView(
                                trainee: trainee,
                                coachProfileId: coachId,
                                membershipService: membershipService,
                                visitService: visitService,
                                initialMemberships: memberships
                            )
                        } label: {
                            RectangularBlockContent(
                                icon: "ticket",
                                title: "Абонементы",
                                value: activeMembership != nil ? "Есть активный" : "Нет активного",
                                iconColor: activeMembership != nil ? AppDesign.profileAccent : .secondary
                            )
                        }
                        .buttonStyle(PressableButtonStyle())
                        .rectangularBlockStyle()
                        .frame(maxWidth: .infinity)

                        NavigationLink {
                            ClientVisitsManageView(
                                trainee: trainee,
                                coachProfileId: coachId,
                                visitService: visitService,
                                membershipService: membershipService,
                                initialVisits: visits,
                                initialMemberships: memberships
                            )
                        } label: {
                            RectangularBlockContent(
                                icon: "calendar",
                                title: "Посещения",
                                value: visits.isEmpty ? "Пока нет" : "\(visits.count)"
                            )
                        }
                        .buttonStyle(PressableButtonStyle())
                        .rectangularBlockStyle()
                        .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, AppDesign.cardPadding)
                    .padding(.top, AppDesign.blockSpacing)
                }

                // Управление подопечным
                if coachProfileId != nil, linkService != nil {
                    SettingsCard(title: "Управление подопечным") {
                        VStack(alignment: .leading, spacing: 0) {
                            if trainee.isManaged && trainee.mergedIntoProfileId == nil {
                                Button {
                                    showMergeSheet = true
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                            .foregroundStyle(.secondary)
                                            .frame(width: 28, alignment: .center)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Объединить по коду")
                                                .foregroundStyle(.primary)
                                            Text("Клиент создаёт код в приложении. После объединения замеры, цели, посещения и абонементы перенесутся в его профиль.")
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
                                Divider().padding(.leading, 40)
                            }

                            Button {
                                archiveTarget = !isArchived
                                showArchiveConfirmation = true
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: isArchived ? "archivebox.fill" : "archivebox")
                                        .foregroundStyle(.secondary)
                                        .frame(width: 28, alignment: .center)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(isArchived ? "Вернуть из архива" : "В архив")
                                            .foregroundStyle(.primary)
                                        Text(isArchived ? "Вернуть в активные." : "Клиент перестал заниматься — скрыть внизу списка.")
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
                            .disabled(isArchiving)
                            Divider().padding(.leading, 40)

                            Button {
                                showUnlinkConfirmation = true
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "person.fill.badge.minus")
                                        .foregroundStyle(.secondary)
                                        .frame(width: 28, alignment: .center)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Отвязать подопечного")
                                            .foregroundStyle(Color.red)
                                        Text("Исчезнет из списка. Его данные не удаляются.")
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
                            .disabled(isUnlinking)
                        }
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
    }

    var body: some View {
        mainContent
        .navigationTitle(trainee.name)
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
        .alert(isArchived ? "Вернуть из архива?" : "В архив?", isPresented: $showArchiveConfirmation) {
            Button("Отмена", role: .cancel) { showArchiveConfirmation = false }
            Button(isArchived ? "Вернуть" : "В архив", role: isArchived ? nil : .destructive) {
                showArchiveConfirmation = false
                Task { await performSetArchived(archiveTarget) }
            }
        } message: {
            Text(isArchived ? "Вернуть клиента в активные?" : "Клиент перестал заниматься — переместить в архив?")
        }
        .task {
            await loadData()
        }
        .refreshable {
            await loadData()
        }
        .alert("Ошибка", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            if let msg = errorMessage { Text(msg) }
        }
        .alert("Отвязать подопечного?", isPresented: $showUnlinkConfirmation) {
            Button("Отмена", role: .cancel) { showUnlinkConfirmation = false }
            Button("Отвязать", role: .destructive) {
                Task { await performUnlink() }
            }
        } message: {
            Text("Подопечный исчезнет из вашего списка. Его данные не удаляются.")
        }
        .sheet(isPresented: $showMergeSheet) {
            MergeManagedTraineeSheet(
                coachProfileId: coachProfileId ?? "",
                managedTrainee: trainee,
                tokenService: connectionTokenService,
                mergeService: managedTraineeMergeService,
                onMerged: {
                    showMergeSheet = false
                    dismiss()
                    onUnlink?()
                },
                onCancel: { showMergeSheet = false }
            )
            .presentationDetents([.medium, .large])
        }
        .overlay {
            if isArchiving {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .overlay {
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(1.1)
                            Text("Обновляю…")
                                .font(.subheadline)
                                .foregroundStyle(.white)
                        }
                    }
            }
        }
        .allowsHitTesting(!isArchiving)
    }

    private func performUnlink() async {
        guard let coachId = coachProfileId, let svc = linkService else { return }
        isUnlinking = true
        defer { isUnlinking = false }
        do {
            try await svc.removeLink(coachProfileId: coachId, traineeProfileId: trainee.id)
            await MainActor.run {
                dismiss()
                onUnlink?()
            }
        } catch {
            await MainActor.run { errorMessage = AppErrors.userMessage(for: error) }
        }
    }

    private func performSetArchived(_ archived: Bool) async {
        guard let coachId = coachProfileId, let svc = linkService else { return }
        isArchiving = true
        defer { isArchiving = false }
        do {
            try await svc.setArchived(coachProfileId: coachId, traineeProfileId: trainee.id, isArchived: archived)
            if let onArchiveChanged {
                await onArchiveChanged()
            }
            await MainActor.run {
                dismiss()
            }
        } catch {
            await MainActor.run { errorMessage = AppErrors.userMessage(for: error) }
        }
    }

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }
        let coachId = coachProfileId
        do {
                if let coachId {
                async let measTask = measurementService.fetchMeasurements(profileId: trainee.id)
                async let goalsTask = goalService.fetchGoals(profileId: trainee.id)
                async let activeTask = membershipService.fetchActiveMembership(coachProfileId: coachId, traineeProfileId: trainee.id)
                async let visitsTask = visitService.fetchVisits(coachProfileId: coachId, traineeProfileId: trainee.id)
                async let membershipsTask = membershipService.fetchMemberships(coachProfileId: coachId, traineeProfileId: trainee.id)
                let (meas, gols, active, list, allMemberships) = try await (measTask, goalsTask, activeTask, visitsTask, membershipsTask)
                await MainActor.run {
                    measurements = meas
                    goals = gols
                    activeMembership = active
                    visits = list
                    memberships = allMemberships.sorted { $0.createdAt > $1.createdAt }
                }
            } else {
                async let measTask = measurementService.fetchMeasurements(profileId: trainee.id)
                async let goalsTask = goalService.fetchGoals(profileId: trainee.id)
                let (meas, gols) = try await (measTask, goalsTask)
                await MainActor.run {
                    measurements = meas
                    goals = gols
                    activeMembership = nil
                    visits = []
                    memberships = []
                }
            }
        } catch {
                await MainActor.run {
                    measurements = []
                    goals = []
                    activeMembership = nil
                    visits = []
                    memberships = []
                    errorMessage = AppErrors.userMessage(for: error)
                }
        }
    }
}

private struct MergeManagedTraineeSheet: View {
    let coachProfileId: String
    let managedTrainee: Profile
    let tokenService: ConnectionTokenServiceProtocol
    let mergeService: ManagedTraineeMergeServiceProtocol
    let onMerged: () -> Void
    let onCancel: () -> Void

    @State private var codeInput = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var realTraineeProfileIdToConfirm: String?
    @State private var pendingToken: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    SettingsCard(title: "Ввести код") {
                        TextField("Код из приложения клиента", text: $codeInput)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)

                        Button {
                            if let s = UIPasteboard.general.string {
                                codeInput = s.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "doc.on.clipboard")
                                Text("Вставить из буфера")
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)

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
            .navigationTitle("Объединить")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { onCancel() }
                        .disabled(isLoading)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.9)
                    } else {
                        Button("Подтвердить") {
                            Task { await submitCode(codeInput.trimmingCharacters(in: .whitespacesAndNewlines)) }
                        }
                        .fontWeight(.semibold)
                        .disabled(codeInput.trimmingCharacters(in: .whitespacesAndNewlines).count < 4)
                    }
                }
            }
            .alert("Объединить профили?", isPresented: Binding(
                get: { realTraineeProfileIdToConfirm != nil },
                set: { if !$0 { realTraineeProfileIdToConfirm = nil } }
            )) {
                Button("Отмена", role: .cancel) { realTraineeProfileIdToConfirm = nil; pendingToken = nil }
                Button("Объединить") {
                    if let realId = realTraineeProfileIdToConfirm, let token = pendingToken {
                        Task { await confirmMerge(realTraineeProfileId: realId, token: token) }
                    }
                    realTraineeProfileIdToConfirm = nil
                }
            } message: {
                Text("Перенести все данные из «\(managedTrainee.name)» в реальный профиль клиента?")
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
            // С текущими safe-rules тренер не имеет доступа читать чужие profiles/{id}.
            // Для объединения достаточно traineeProfileId из токена.
            await MainActor.run {
                realTraineeProfileIdToConfirm = token.traineeProfileId
                pendingToken = code.uppercased()
            }
        } catch {
            await MainActor.run { errorMessage = AppErrors.userMessage(for: error) }
        }
    }

    private func confirmMerge(realTraineeProfileId: String, token: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false; pendingToken = nil }
        do {
            try await mergeService.mergeManagedTrainee(
                coachProfileId: coachProfileId,
                managedTraineeProfileId: managedTrainee.id,
                realTraineeProfileId: realTraineeProfileId
            )
            try await tokenService.markTokenUsed(token: token)
            await MainActor.run {
                AppDesign.triggerSuccessHaptic()
                onMerged()
            }
        } catch {
            await MainActor.run { errorMessage = AppErrors.userMessage(for: error) }
        }
    }
}

// MARK: - Строка в карточке клиента и вспомогательные элементы

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
        .padding(.horizontal, AppDesign.cardPadding)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

private struct ClientMeasurementRow: View {
    let measurement: Measurement

    private var dateFormatted: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.locale = Locale(identifier: "ru_RU")
        return f.string(from: measurement.date)
    }

    private var valueText: String? {
        if let w = measurement.weight {
            return "\(w.measurementFormatted) кг"
        }
        return nil
    }

    var body: some View {
        ClientCardRow(
            icon: "ruler.fill",
            title: dateFormatted,
            value: valueText,
            showsDisclosure: true
        )
    }
}
