//
//  TraineeWorkoutsView.swift
//  TrainLog
//

import SwiftUI

/// Экран «Мои тренировки»: календарь с отмеченными днями посещений и список абонементов по тренерам.
struct TraineeWorkoutsView: View {
    let profile: Profile
    let linkService: CoachTraineeLinkServiceProtocol
    let visitService: VisitServiceProtocol
    let membershipService: MembershipServiceProtocol
    let profileService: ProfileServiceProtocol

    @State private var selectedMonth = Date()
    @State private var visits: [Visit] = []
    @State private var membershipItems: [(coachName: String, membership: Membership)] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let calendar = Calendar.current

    /// Визиты за выбранный месяц (для календаря и списка).
    private var visitsInSelectedMonth: [Visit] {
        guard let interval = calendar.dateInterval(of: .month, for: selectedMonth) else { return [] }
        return visits.filter { $0.date >= interval.start && $0.date < interval.end }
            .sorted { $0.date > $1.date }
    }

    /// Количество тренировок (визитов) за выбранный месяц.
    private var totalWorkoutsInMonth: Int {
        visitsInSelectedMonth.count
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    LoadingView(message: "Загрузка…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemGroupedBackground))
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            infoBanner
                            VisitsCalendarView(selectedMonth: $selectedMonth, visits: visits)
                            statsSection
                            VisitsListBlockView(
                                title: "Посещения за месяц",
                                visits: visitsInSelectedMonth,
                                payableMemberships: [],
                                onPayWithMembership: nil
                            )
                            membershipsSection
                        }
                        .padding(.bottom, AppDesign.sectionSpacing)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Мои тренировки")
            .navigationBarTitleDisplayMode(.inline)
            .task { await load() }
            .refreshable { await load() }
            .alert("Ошибка", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                if let msg = errorMessage { Text(msg) }
            }
        }
    }

    /// Пояснение, что экран информационный и обновляется тренером.
    private var infoBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle.fill")
                .font(.body)
                .foregroundStyle(.secondary)
            Text("Экран носит информационный характер: посещения и абонементы обновляются по мере того, как их вносит тренер.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppDesign.cardPadding)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
        .padding(.horizontal, AppDesign.cardPadding)
        .padding(.top, AppDesign.blockSpacing)
        .padding(.bottom, AppDesign.blockSpacing)
    }

    private var statsSection: some View {
        return HStack(spacing: 6) {
            Text("Всего тренировок в месяце:")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("\(totalWorkoutsInMonth)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppDesign.rowSpacing)
        .padding(.horizontal, AppDesign.cardPadding)
    }

    private var membershipsSection: some View {
        let allMemberships = membershipItems.map(\.membership)
        let active = allMemberships.filter { $0.isActive }
        let finished = allMemberships.filter { !$0.isActive }

        return Group {
            if allMemberships.isEmpty {
                Text("Пока нет абонементов")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, AppDesign.cardPadding)
                    .padding(.top, AppDesign.blockSpacing)
                    .padding(.vertical, AppDesign.sectionSpacing)
            } else {
                if !active.isEmpty {
                    SettingsCard(title: "Активные абонементы") {
                        VStack(spacing: 0) {
                            ForEach(Array(active.enumerated()), id: \.element.id) { index, m in
                                CoachMembershipRow(membership: m, highlight: true)
                                if index < active.count - 1 {
                                    Divider()
                                        .padding(.leading, 40)
                                }
                            }
                        }
                    }
                    .padding(.top, AppDesign.blockSpacing)
                }
                if !finished.isEmpty {
                    SettingsCard(title: "Завершённые") {
                        VStack(spacing: 0) {
                            ForEach(Array(finished.enumerated()), id: \.element.id) { index, m in
                                CoachMembershipRow(membership: m, highlight: false)
                                if index < finished.count - 1 {
                                    Divider()
                                        .padding(.leading, 40)
                                }
                            }
                        }
                    }
                    .padding(.top, AppDesign.blockSpacing)
                }
            }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let links = try await linkService.fetchLinksForTrainee(traineeProfileId: profile.id)
            var allVisits: [Visit] = []
            var items: [(String, Membership)] = []
            for link in links {
                async let coachProfile = profileService.fetchProfile(id: link.coachProfileId)
                async let v = visitService.fetchVisits(coachProfileId: link.coachProfileId, traineeProfileId: profile.id)
                async let m = membershipService.fetchMemberships(coachProfileId: link.coachProfileId, traineeProfileId: profile.id)
                let (coach, visitList, membershipList) = try await (coachProfile, v, m)
                let name = coach?.name ?? "Тренер"
                allVisits.append(contentsOf: visitList)
                for membership in membershipList {
                    items.append((name, membership))
                }
            }
            await MainActor.run {
                visits = allVisits.sorted { $0.date > $1.date }
                membershipItems = items.sorted { $0.1.createdAt > $1.1.createdAt }
            }
        } catch {
            await MainActor.run {
                visits = []
                membershipItems = []
                errorMessage = AppErrors.userMessage(for: error)
            }
        }
    }
}

