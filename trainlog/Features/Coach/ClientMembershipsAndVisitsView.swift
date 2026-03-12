//
//  ClientMembershipsAndVisitsView.swift
//  TrainLog
//

import SwiftUI

// MARK: - Экран всех абонементов клиента для тренера (с добавлением посещений)

struct ClientMembershipsView: View {
    let trainee: Profile
    let coachProfileId: String
    let membershipService: MembershipServiceProtocol
    let visitService: VisitServiceProtocol
    var initialMemberships: [Membership]? = nil

    @State private var memberships: [Membership] = []
    @State private var isLoading = true
    @State private var showAddMembership = false
    @State private var showAddOneOffVisit = false
    @State private var showAddVisitForMembership: IdentifiableMembership? = nil
    @State private var navigateToVisitsAfterOneOff = false
    @State private var errorMessage: String?
    @State private var isCreatingMembership = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Разовое посещение (не в абонементе)
                Button {
                    showAddOneOffVisit = true
                } label: {
                    AddActionRow(title: "Отметить разовое посещение", systemImage: "calendar.badge.plus")
                }
                .buttonStyle(PressableButtonStyle())
                .frame(maxWidth: .infinity)
                .padding(AppDesign.cardPadding)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
                .padding(.horizontal, AppDesign.cardPadding)
                .padding(.top, AppDesign.blockSpacing)

                // Новый абонемент
                Button {
                    showAddMembership = true
                } label: {
                    AddActionRow(title: "Новый абонемент", systemImage: "plus.circle.fill")
                }
                .buttonStyle(PressableButtonStyle())
                .frame(maxWidth: .infinity)
                .padding(AppDesign.cardPadding)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
                .padding(.horizontal, AppDesign.cardPadding)
                .padding(.top, AppDesign.blockSpacing)

                if isLoading {
                    LoadingBlockView(message: "Загружаю…")
                } else if memberships.isEmpty {
                    ContentUnavailableView(
                        "Пока нет абонементов",
                        systemImage: "ticket.slash",
                        description: Text("Нажмите «Новый абонемент» выше, чтобы добавить первый.")
                    )
                    .padding(.vertical, 32)
                } else {
                    MembershipsBlockView(
                        memberships: memberships,
                        onAddVisit: { m in showAddVisitForMembership = IdentifiableMembership(membership: m) }
                    )
                }
            }
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Абонементы")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddMembership) {
            AddMembershipSheet(
                isCreating: $isCreatingMembership,
                onCreate: { total, price in
                    Task {
                        await MainActor.run { isCreatingMembership = true }
                        do {
                            _ = try await membershipService.createMembership(
                                coachProfileId: coachProfileId,
                                traineeProfileId: trainee.id,
                                totalSessions: total,
                                priceRub: price
                            )
                            await load()
                            await MainActor.run { showAddMembership = false }
                            await MainActor.run { AppDesign.triggerSuccessHaptic() }
                        } catch {
                            await MainActor.run { errorMessage = AppErrors.userMessage(for: error) }
                        }
                        await MainActor.run { isCreatingMembership = false }
                    }
                },
                onCancel: { showAddMembership = false }
            )
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showAddOneOffVisit) {
            AddVisitSheet(
                mode: .oneOff(paidByDefault: true),
                visitSubtitle: "Разовое посещение",
                coachProfileId: coachProfileId,
                traineeProfileId: trainee.id,
                visitService: visitService,
                initialDate: nil,
                onAdded: {
                    Task {
                        await load()
                        await MainActor.run { showAddOneOffVisit = false }
                        await MainActor.run { navigateToVisitsAfterOneOff = true }
                    }
                },
                onError: { msg in Task { await MainActor.run { errorMessage = msg } } },
                onCancel: { showAddOneOffVisit = false }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $showAddVisitForMembership) { wrapper in
            let ordinal = (memberships.firstIndex(where: { $0.id == wrapper.membership.id }) ?? 0) + 1
            AddVisitSheet(
                mode: .fromMembership(wrapper.membership),
                visitSubtitle: "Посещение по абонементу № \(ordinal)",
                coachProfileId: coachProfileId,
                traineeProfileId: trainee.id,
                visitService: visitService,
                initialDate: nil,
                onAdded: { Task { await load(); await MainActor.run { showAddVisitForMembership = nil } } },
                onError: { msg in Task { await MainActor.run { errorMessage = msg } } },
                onCancel: { showAddVisitForMembership = nil }
            )
            .presentationDetents([.medium])
        }
        .alert("Ошибка", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            if let msg = errorMessage { Text(msg) }
        }
        .navigationDestination(isPresented: $navigateToVisitsAfterOneOff) {
            ClientVisitsManageView(
                trainee: trainee,
                coachProfileId: coachProfileId,
                visitService: visitService,
                membershipService: membershipService
            )
        }
        .task {
            if let initial = initialMemberships, !initial.isEmpty {
                await MainActor.run {
                    memberships = initial.sorted { $0.createdAt > $1.createdAt }
                    isLoading = false
                }
            }
            await load()
        }
        .refreshable { await load() }
    }

    private func load() async {
        let hadData = !memberships.isEmpty
        if !hadData { await MainActor.run { isLoading = true } }
        do {
            let list = try await membershipService.fetchMemberships(
                coachProfileId: coachProfileId,
                traineeProfileId: trainee.id
            )
            await MainActor.run {
                memberships = list.sorted { $0.createdAt > $1.createdAt }
            }
        } catch {
            await MainActor.run {
                memberships = []
                errorMessage = AppErrors.userMessage(for: error)
            }
        }
        await MainActor.run { isLoading = false }
    }
}

// MARK: - Общий блок списка абонементов (Активные / Завершённые). У тренера — с кнопкой «Добавить посещение», у подопечного — без.

struct MembershipsBlockView: View {
    let memberships: [Membership]
    var onAddVisit: ((Membership) -> Void)? = nil

    private var activeMemberships: [Membership] {
        memberships.filter { $0.isActive }
    }
    private var finishedMemberships: [Membership] {
        memberships.filter { !$0.isActive }
    }

    var body: some View {
        Group {
                if !activeMemberships.isEmpty {
                SettingsCard(title: "Активные") {
                    VStack(spacing: 0) {
                        ForEach(Array(activeMemberships.enumerated()), id: \.element.id) { index, m in
                            VStack(spacing: 0) {
                                CoachMembershipRow(membership: m, highlight: true)
                                if let onAdd = onAddVisit {
                                    Divider()
                                        .padding(.leading, 40)
                                    Button {
                                        onAdd(m)
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: "calendar.badge.plus")
                                                .font(.subheadline)
                                            Text("Добавить посещение")
                                                .font(.subheadline.weight(.medium))
                                        }
                                        .foregroundStyle(.primary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 10)
                                    }
                                    .buttonStyle(PressableButtonStyle())
                                }
                                if index < activeMemberships.count - 1 {
                                    Divider()
                                        .padding(.leading, 40)
                                }
                            }
                        }
                    }
                }
                .padding(.top, 8)
            }

            if !finishedMemberships.isEmpty {
                SettingsCard(title: "Завершённые") {
                    VStack(spacing: 0) {
                        ForEach(Array(finishedMemberships.enumerated()), id: \.element.id) { index, m in
                            CoachMembershipRow(membership: m, highlight: false)
                            if index < finishedMemberships.count - 1 {
                                Divider()
                                    .padding(.leading, 40)
                            }
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
    }
}

// MARK: - Общий календарь посещаемости (тренер и подопечный). Логика взаимодействия — снаружи (Binding месяца и массив визитов).

struct VisitsCalendarView: View {
    @Binding var selectedMonth: Date
    let visits: [Visit]
    /// Если задан — по тапу на день вызывается с датой этого дня (start of day). Только для тренера.
    var onDayTapped: ((Date) -> Void)? = nil
    /// Для тренера: всплывающее меню «Добавить посещение» (как у долга). Передать абонементы и колбэки.
    var addVisitMemberships: [Membership]? = nil
    var onAddOneOffVisit: ((Date) -> Void)? = nil
    var onAddVisitWithMembership: ((Date, Membership) -> Void)? = nil

    private var showAddVisitMenu: Bool {
        onAddOneOffVisit != nil
    }

    private let calendar = Calendar.current
    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: selectedMonth).capitalized
    }

    private var daysInMonth: [(day: Int?, hasVisit: Bool, absent: Bool, debt: Bool, count: Int)] {
        guard let _ = calendar.dateInterval(of: .month, for: selectedMonth),
              let first = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth)) else {
            return []
        }
        let range = calendar.range(of: .day, in: .month, for: selectedMonth)!
        let numberOfDays = range.count
        let firstWeekday = calendar.component(.weekday, from: first)
        let leadingBlanks = (firstWeekday - 2 + 7) % 7
        var result: [(Int?, Bool, Bool, Bool, Int)] = []
        for _ in 0..<leadingBlanks {
            result.append((nil, false, false, false, 0))
        }
        for day in 1...numberOfDays {
            guard let date = calendar.date(bySetting: .day, value: day, of: first) else { continue }
            let startOfDay = calendar.startOfDay(for: date)
            let onDay = visits.filter { calendar.isDate($0.date, inSameDayAs: startOfDay) }
            let activeVisits = onDay.filter { $0.status != .cancelled }
            let count = activeVisits.count
            let hasVisit = !activeVisits.isEmpty
            let absent = activeVisits.contains { $0.status == .noShow }
            let debt = activeVisits.contains { $0.paymentStatus == .debt }
            result.append((day, hasVisit, absent, debt, count))
        }
        let totalCells = 42
        while result.count < totalCells {
            result.append((nil, false, false, false, 0))
        }
        return Array(result.prefix(totalCells))
    }

    var body: some View {
        SettingsCard(title: "Посещаемость") {
            VStack(spacing: AppDesign.rowSpacing) {
                HStack {
                    Button {
                        if let prev = calendar.date(byAdding: .month, value: -1, to: selectedMonth) {
                            selectedMonth = prev
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(monthTitle)
                        .font(.headline)
                    Spacer()
                    Button {
                        if let next = calendar.date(byAdding: .month, value: 1, to: selectedMonth) {
                            selectedMonth = next
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                let weekdays = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
                let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                    ForEach(weekdays, id: \.self) { w in
                        Text(w)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(Array(daysInMonth.enumerated()), id: \.offset) { _, item in
                        let dayDate: Date? = item.day.flatMap { d in
                            guard let first = firstOfMonth,
                                  let date = calendar.date(bySetting: .day, value: d, of: first) else { return nil }
                            return calendar.startOfDay(for: date)
                        }
                        VisitsCalendarDayCell(
                            day: item.day,
                            hasVisit: item.hasVisit,
                            absent: item.absent,
                            debt: item.debt,
                            visitsCount: item.count,
                            dateForTap: dayDate,
                            onDayTapped: onDayTapped,
                            addVisitMemberships: showAddVisitMenu ? addVisitMemberships : nil,
                            onAddOneOffVisit: showAddVisitMenu ? onAddOneOffVisit : nil,
                            onAddVisitWithMembership: showAddVisitMenu ? onAddVisitWithMembership : nil
                        )
                    }
                }
            }
        }
        .padding(.top, AppDesign.blockSpacing)
    }
}

private struct VisitsCalendarDayCell: View {
    let day: Int?
    let hasVisit: Bool
    let absent: Bool
    let debt: Bool
    let visitsCount: Int
    var dateForTap: Date? = nil
    var onDayTapped: ((Date) -> Void)? = nil
    var addVisitMemberships: [Membership]? = nil
    var onAddOneOffVisit: ((Date) -> Void)? = nil
    var onAddVisitWithMembership: ((Date, Membership) -> Void)? = nil

    var body: some View {
        ZStack {
            if let d = day {
                if absent {
                    Circle()
                        .fill(Color.red.opacity(0.3))
                        .frame(width: 28, height: 28)
                } else if debt {
                    Circle()
                        .fill(Color.orange.opacity(0.4))
                        .frame(width: 28, height: 28)
                } else if hasVisit {
                    Circle()
                        .fill(AppDesign.profileAccent.opacity(0.35))
                        .frame(width: 28, height: 28)
                }
                dayContent(d: d)

                if visitsCount > 1 {
                    Text("\(min(visitsCount, 9))")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .offset(x: 6, y: 6)
                        .accessibilityLabel("Посещений: \(visitsCount)")
                }
            }
        }
        .frame(height: 32)
    }

    @ViewBuilder
    private func dayContent(d: Int) -> some View {
        // Если на день уже есть посещение — показываем меню действий (не добавление).
        if visitsCount > 0, let date = dateForTap, let onTap = onDayTapped {
            Menu {
                Button(role: .destructive) {
                    onTap(date)
                } label: {
                    Label("Отменить посещение", systemImage: "xmark.circle")
                }
            } label: {
                Text("\(d)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color(UIColor.label))
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .contentShape(Rectangle())
            }
        } else if let date = dateForTap, let onAddOneOff = onAddOneOffVisit {
            Menu {
                Button {
                    onAddOneOff(date)
                } label: {
                    Label("Разовое посещение", systemImage: "calendar.badge.plus")
                }
                if let memberships = addVisitMemberships, !memberships.isEmpty {
                    ForEach(memberships) { m in
                        Button {
                            onAddVisitWithMembership?(date, m)
                        } label: {
                            Label(
                                m.displayCode.map { "Абонемент №\($0)" } ?? "Абонемент",
                                systemImage: "ticket"
                            )
                        }
                    }
                } else {
                    Text("Нет активных абонементов")
                        .foregroundStyle(.secondary)
                }
            } label: {
                Text("\(d)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color(UIColor.label))
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .contentShape(Rectangle())
            }
        } else if let date = dateForTap, let onTap = onDayTapped {
            Button {
                onTap(date)
            } label: {
                Text("\(d)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color(UIColor.label))
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())
        } else {
            Text("\(d)")
                .font(.caption.weight(.medium))
                .foregroundStyle(Color(UIColor.label))
        }
    }
}

// MARK: - Общий блок списка посещений (тренер и подопечный). У тренера — с действием «Списать с абонемента», у подопечного — только просмотр.

struct VisitsListBlockView: View {
    let title: String
    let visits: [Visit]
    /// Абонементы, с которых можно списать долг (оставшиеся занятия > 0). Для тренера — все подходящие; для подопечного — пустой массив.
    var payableMemberships: [Membership] = []
    var onPayWithMembership: ((Visit, Membership) -> Void)? = nil
    /// Пометить визит как оплачено (без списания с абонемента). Для тренера — вызов сервиса; для подопечного — nil.
    var onMarkAsPaid: ((Visit) -> Void)? = nil
    /// Отменить посещение (только тренер).
    var onCancelVisit: ((Visit) -> Void)? = nil

    var body: some View {
        Group {
            if visits.isEmpty {
                Text("В выбранном месяце нет посещений")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, AppDesign.cardPadding)
                    .padding(.vertical, AppDesign.sectionSpacing)
            } else {
                SettingsCard(title: title) {
                    VStack(spacing: 0) {
                        ForEach(Array(visits.enumerated()), id: \.element.id) { index, v in
                            if index != 0 {
                                Divider()
                                    .padding(.leading, 40)
                            }
                            CoachVisitRow(
                                visit: v,
                                payableMemberships: payableMemberships,
                                onPayWithMembership: onPayWithMembership.map { pay in { m in pay(v, m) } },
                                onMarkAsPaid: onMarkAsPaid.map { f in { f(v) } },
                                onCancel: onCancelVisit.map { f in { f(v) } }
                            )
                        }
                    }
                }
            }
        }
        .padding(.top, AppDesign.blockSpacing)
    }
}

struct CoachMembershipRow: View {
    let membership: Membership
    let highlight: Bool

    private var dateText: String {
        membership.createdAt.formatted(.dateTime.day().month().year())
    }

    private var statusText: String {
        switch membership.status {
        case .active: return "Активен"
        case .finished: return "Завершён"
        case .cancelled: return "Отменён"
        }
    }

    private var statusColor: Color {
        switch membership.status {
        case .active: return .green
        case .finished: return .secondary
        case .cancelled: return .orange
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "ticket")
                .foregroundStyle(highlight ? .green : .secondary)
                .frame(width: 28, alignment: .center)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if let code = membership.displayCode, !code.isEmpty {
                        Text("№\(code)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                    Text("Посещено \(membership.usedSessions) из \(membership.totalSessions)")
                        .font(.subheadline.weight(highlight ? .semibold : .regular))
                        .foregroundStyle(.primary)
                }
                Text("Создан: \(dateText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(statusText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(statusColor)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

// MARK: - Экран посещений для тренера (календарь + список за выбранный месяц)

struct ClientVisitsManageView: View {
    let trainee: Profile
    let coachProfileId: String
    let visitService: VisitServiceProtocol
    let membershipService: MembershipServiceProtocol
    var initialVisits: [Visit]? = nil
    var initialMemberships: [Membership]? = nil

    @State private var visits: [Visit] = []
    @State private var memberships: [Membership] = []
    @State private var selectedMonth = Date()
    @State private var isLoading = true
    @State private var showAddOneOffVisit = false
    @State private var pendingOneOffDate: Date?
    @State private var addVisitWithMembership: (date: Date, membership: Membership)?
    @State private var visitToCancel: Visit?
    @State private var showCancelConfirmation = false
    @State private var isCancelling = false
    @State private var errorMessage: String?

    private let calendar = Calendar.current

    private var activeMemberships: [Membership] {
        memberships.filter { $0.remainingSessions > 0 }
    }

    private var visitsInSelectedMonth: [Visit] {
        guard let interval = calendar.dateInterval(of: .month, for: selectedMonth) else { return [] }
        return visits.filter { $0.date >= interval.start && $0.date < interval.end }
            .sorted { $0.date > $1.date }
    }

    private var onCancelDayTap: ((Date) -> Void) {
        { date in
            // Если на день уже есть активное посещение — предложить отменить.
            let sameDay = visits
                .filter { calendar.isDate($0.date, inSameDayAs: date) }
                .filter { $0.status != .cancelled }
                .sorted { $0.date > $1.date }
            if let v = sameDay.first {
                visitToCancel = v
                showCancelConfirmation = true
            }
        }
    }

    private var addOneOffButton: some View {
        Button {
            showAddOneOffVisit = true
        } label: {
            AddActionRow(title: "Отметить разовое посещение", systemImage: "calendar.badge.plus")
        }
        .buttonStyle(PressableButtonStyle())
        .frame(maxWidth: .infinity)
        .padding(AppDesign.cardPadding)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
        .padding(.horizontal, AppDesign.cardPadding)
        .padding(.top, AppDesign.blockSpacing)
    }

    @ViewBuilder
    private var mainContent: some View {
        if isLoading {
            LoadingBlockView(message: "Загружаю посещения…")
        } else {
            VisitsCalendarView(
                selectedMonth: $selectedMonth,
                visits: visits,
                onDayTapped: onCancelDayTap,
                addVisitMemberships: activeMemberships,
                onAddOneOffVisit: { date in pendingOneOffDate = date },
                onAddVisitWithMembership: { date, m in addVisitWithMembership = (date, m) }
            )
            VisitsListBlockView(
                title: "Посещения за месяц",
                visits: visitsInSelectedMonth,
                payableMemberships: memberships.filter { $0.remainingSessions > 0 },
                onPayWithMembership: { visit, membership in
                    Task {
                        do {
                            try await visitService.markVisitPaidWithMembership(visit, membershipId: membership.id)
                            await load()
                        } catch {
                            await MainActor.run { errorMessage = AppErrors.userMessage(for: error) }
                        }
                    }
                },
                onMarkAsPaid: { visit in
                    Task {
                        do {
                            try await visitService.markVisitPaid(visit)
                            await load()
                        } catch {
                            await MainActor.run { errorMessage = AppErrors.userMessage(for: error) }
                        }
                    }
                },
                onCancelVisit: { v in
                    visitToCancel = v
                    showCancelConfirmation = true
                }
            )
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                addOneOffButton
                mainContent
            }
            .padding(.top, AppDesign.blockSpacing)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Посещения")
        .navigationBarTitleDisplayMode(.inline)
        .tooltip(
            id: .visitsCalendarTap,
            title: "Добавление посещения",
            message: "Нажмите на день в календаре, чтобы добавить посещение — разовое или с выбором абонемента."
        )
        .sheet(isPresented: $showAddOneOffVisit) {
            AddVisitSheet(
                mode: .oneOff(paidByDefault: true),
                visitSubtitle: "Разовое посещение",
                coachProfileId: coachProfileId,
                traineeProfileId: trainee.id,
                visitService: visitService,
                onAdded: { Task { await load(); await MainActor.run { showAddOneOffVisit = false } } },
                onError: { msg in Task { await MainActor.run { errorMessage = msg } } },
                onCancel: { showAddOneOffVisit = false }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: Binding(
            get: { pendingOneOffDate != nil },
            set: { if !$0 { pendingOneOffDate = nil } }
        )) {
            if let date = pendingOneOffDate {
                AddVisitSheet(
                    mode: .oneOff(paidByDefault: true),
                    visitSubtitle: "Разовое посещение",
                    coachProfileId: coachProfileId,
                    traineeProfileId: trainee.id,
                    visitService: visitService,
                    initialDate: date,
                    onAdded: { Task { await load(); await MainActor.run { pendingOneOffDate = nil } } },
                    onError: { msg in Task { await MainActor.run { errorMessage = msg } } },
                    onCancel: { pendingOneOffDate = nil }
                )
                .presentationDetents([.medium, .large])
            }
        }
        .sheet(item: Binding(
            get: { addVisitWithMembership.map { AddVisitWithMembershipWrapper(date: $0.date, membership: $0.membership) } },
            set: { addVisitWithMembership = $0.map { ($0.date, $0.membership) } }
        )) { wrapper in
            AddVisitSheet(
                mode: .fromMembership(wrapper.membership),
                visitSubtitle: "Абонемент №\(wrapper.membership.displayCode ?? "")",
                coachProfileId: coachProfileId,
                traineeProfileId: trainee.id,
                visitService: visitService,
                initialDate: wrapper.date,
                onAdded: { Task { await load(); await MainActor.run { addVisitWithMembership = nil } } },
                onError: { msg in Task { await MainActor.run { errorMessage = msg } } },
                onCancel: { addVisitWithMembership = nil }
            )
            .presentationDetents([.medium, .large])
        }
        .alert("Ошибка", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            if let msg = errorMessage { Text(msg) }
        }
        .alert("Отменить посещение?", isPresented: $showCancelConfirmation) {
            Button("Нет", role: .cancel) { showCancelConfirmation = false; visitToCancel = nil }
            Button("Отменить", role: .destructive) {
                showCancelConfirmation = false
                guard let v = visitToCancel else { return }
                visitToCancel = nil
                Task {
                    await MainActor.run { isCancelling = true }
                    do {
                        try await visitService.cancelVisit(v)
                        await load()
                    } catch {
                        await MainActor.run { errorMessage = AppErrors.userMessage(for: error) }
                    }
                    await MainActor.run { isCancelling = false }
                }
            }
        } message: {
            Text("Посещение будет помечено как отменённое. Оплата и списание с абонемента будут сняты.")
        }
        .overlay {
            if isCancelling {
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
        .allowsHitTesting(!isCancelling)
        .task {
            if let v = initialVisits {
                await MainActor.run { visits = v.sorted { $0.date > $1.date } }
            }
            if let m = initialMemberships {
                await MainActor.run { memberships = m }
            }
            if !visits.isEmpty || !memberships.isEmpty {
                await MainActor.run { isLoading = false }
            }
            await load()
        }
        .refreshable { await load() }
    }

    private func load() async {
        let hadData = !visits.isEmpty || !memberships.isEmpty
        if !hadData { await MainActor.run { isLoading = true } }
        do {
            async let listTask = visitService.fetchVisits(
                coachProfileId: coachProfileId,
                traineeProfileId: trainee.id
            )
            async let membershipsTask = membershipService.fetchMemberships(
                coachProfileId: coachProfileId,
                traineeProfileId: trainee.id
            )
            let (list, allMemberships) = try await (listTask, membershipsTask)
            await MainActor.run {
                visits = list.sorted { $0.date > $1.date }
                memberships = allMemberships
            }
        } catch {
            await MainActor.run {
                visits = []
                memberships = []
                errorMessage = AppErrors.userMessage(for: error)
            }
        }
        await MainActor.run { isLoading = false }
    }
}

// MARK: - Вспомогательные элементы для экранов

private struct IdentifiableMembership: Identifiable {
    let membership: Membership
    var id: String { membership.id }
}

private struct AddVisitWithMembershipWrapper: Identifiable {
    let date: Date
    let membership: Membership
    var id: String { "\(membership.id)_\(date.timeIntervalSince1970)" }
}

private struct CoachVisitRow: View {
    let visit: Visit
    var payableMemberships: [Membership] = []
    var onPayWithMembership: ((Membership) -> Void)?
    var onMarkAsPaid: (() -> Void)?
    var onCancel: (() -> Void)?

    private var dateText: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateStyle = .medium
        return f.string(from: visit.date)
    }

    private var statusText: String {
        switch visit.status {
        case .planned: return "Запланировано"
        case .done: return ""
        case .cancelled: return ""
        case .noShow: return "Не пришёл"
        }
    }

    private var paymentText: String? {
        if visit.status == .cancelled { return "Отменено" }
        switch visit.paymentStatus {
        case .unpaid: return "Не оплачено"
        case .paid:
            if let code = visit.membershipDisplayCode, !code.isEmpty {
                return "Абонемент №\(code)"
            }
            return "Оплачено"
        case .debt: return "Долг"
        }
    }

    private var paymentColor: Color {
        if visit.status == .cancelled {
            return .red
        }
        switch visit.paymentStatus {
        case .paid: return .green
        case .debt: return .orange
        case .unpaid: return .secondary
        }
    }

    private var isDebt: Bool { visit.paymentStatus == .debt }
    private var canShowDebtActions: Bool {
        isDebt && (onMarkAsPaid != nil || (onPayWithMembership != nil && !payableMemberships.isEmpty))
    }
    private var canCancel: Bool { onCancel != nil && visit.status != .cancelled }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar")
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .center)
            VStack(alignment: .leading, spacing: 2) {
                Text(dateText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                if !statusText.isEmpty {
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 6) {
                if let paymentText, !paymentText.isEmpty {
                    Text(paymentText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(paymentColor)
                }
                if canShowDebtActions || canCancel {
                    Menu {
                        if canCancel, let onCancel {
                            Button(role: .destructive) {
                                onCancel()
                            } label: {
                                Label("Отменить посещение", systemImage: "xmark.circle")
                            }
                        }
                        if isDebt, let onMarkAsPaid {
                            Button {
                                onMarkAsPaid()
                            } label: {
                                Label("Пометить как оплачено", systemImage: "checkmark.circle")
                            }
                        }
                        if isDebt, let onPay = onPayWithMembership, !payableMemberships.isEmpty {
                            ForEach(payableMemberships) { m in
                                Button {
                                    onPay(m)
                                } label: {
                                    Label(
                                        m.displayCode.map { "Списать с абонемента №\($0)" } ?? "Списать с абонемента (\(m.remainingSessions) занятий)",
                                        systemImage: "ticket"
                                    )
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.body)
                            .foregroundStyle(paymentColor)
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .contextMenu {
            if canCancel, let onCancel {
                Button(role: .destructive) {
                    onCancel()
                } label: {
                    Label("Отменить посещение", systemImage: "xmark.circle")
                }
            }
            if isDebt, let onMarkAsPaid {
                Button {
                    onMarkAsPaid()
                } label: {
                    Label("Пометить как оплачено", systemImage: "checkmark.circle")
                }
            }
            if isDebt, let onPay = onPayWithMembership, !payableMemberships.isEmpty {
                ForEach(payableMemberships) { m in
                    Button {
                        onPay(m)
                    } label: {
                        Label(
                            m.displayCode.map { "Списать с абонемента №\($0)" } ?? "Списать с абонемента (\(m.remainingSessions) занятий)",
                            systemImage: "ticket"
                        )
                    }
                }
            }
        }
    }
}

private struct AddVisitSheet: View {
    enum Mode {
        case oneOff(paidByDefault: Bool)
        case fromMembership(Membership?)  // nil = списать с первого активного
    }

    let mode: Mode
    let visitSubtitle: String
    let coachProfileId: String
    let traineeProfileId: String
    let visitService: VisitServiceProtocol
    let initialDate: Date?
    let onAdded: () -> Void
    let onError: (String) -> Void
    let onCancel: () -> Void

    @State private var selectedDate: Date
    @State private var isPaid: Bool
    @State private var isSaving = false
    @State private var showDatePicker = false

    init(
        mode: Mode,
        visitSubtitle: String,
        coachProfileId: String,
        traineeProfileId: String,
        visitService: VisitServiceProtocol,
        initialDate: Date? = nil,
        onAdded: @escaping () -> Void,
        onError: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.mode = mode
        self.visitSubtitle = visitSubtitle
        self.coachProfileId = coachProfileId
        self.traineeProfileId = traineeProfileId
        self.visitService = visitService
        self.initialDate = initialDate
        self.onAdded = onAdded
        self.onError = onError
        self.onCancel = onCancel
        _selectedDate = State(initialValue: initialDate ?? Date())
        switch mode {
        case .oneOff(let paidByDefault):
            _isPaid = State(initialValue: paidByDefault)
        case .fromMembership:
            _isPaid = State(initialValue: true)
        }
    }

    private var isOneOff: Bool {
        if case .oneOff = mode { return true }
        return false
    }

    private var dateFormatted: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateStyle = .medium
        return f.string(from: selectedDate)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppDesign.blockSpacing) {
                    Text(visitSubtitle)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)

                    if isOneOff {
                        SettingsCard {
                            Toggle("Оплачено", isOn: $isPaid)
                            if !isPaid {
                                Text("Занятие будет помечено как долг. Его можно будет списать с абонемента позже.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 4)
                            }
                        }
                    }

                    SettingsCard {
                        Button {
                            showDatePicker = true
                        } label: {
                            HStack {
                                Text("Дата")
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text(dateFormatted)
                                    .foregroundStyle(.secondary)
                                Image(systemName: "calendar")
                                    .font(.body)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
                .padding(.horizontal, AppDesign.cardPadding)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Добавить")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { onCancel() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSaving ? "Добавляю…" : "Добавить") { addVisit() }
                        .disabled(isSaving)
                }
            }
            .sheet(isPresented: $showDatePicker) {
                datePickerSheet
            }
        }
    }

    private var datePickerSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DatePicker(
                    "Дата",
                    selection: $selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Дата посещения")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { showDatePicker = false }
                }
            }
            .presentationDetents([.height(320)])
            .presentationDragIndicator(.visible)
        }
        .environment(\.locale, Locale(identifier: "ru_RU"))
    }

    private func addVisit() {
        isSaving = true
        Task {
            do {
                let visit = try await visitService.createVisit(
                    coachProfileId: coachProfileId,
                    traineeProfileId: traineeProfileId,
                    date: selectedDate
                )
                switch mode {
                case .oneOff:
                    var updated = visit
                    updated.status = .done
                    updated.paymentStatus = isPaid ? .paid : .debt
                    try await visitService.updateVisit(updated)
                case .fromMembership(let m):
                    if let m {
                        try await visitService.markVisitDoneWithMembership(visit, membershipId: m.id)
                    } else {
                        try await visitService.markVisitDone(visit)
                    }
                }
                await MainActor.run {
                    isSaving = false
                    AppDesign.triggerSuccessHaptic()
                    onAdded()
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

private struct AddMembershipSheet: View {
    @Binding var isCreating: Bool
    let onCreate: (Int, Int?) -> Void
    let onCancel: () -> Void

    @State private var totalSessionsCount: Int = 10
    @State private var priceText: String = ""

    private var priceRub: Int? {
        let t = priceText.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : Int(t)
    }

    private let minSessions = 1
    private let maxSessions = 999

    var body: some View {
        NavigationStack {
            Group {
                if isCreating {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Создаю абонемент…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.bottom, 24)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            SettingsCard(title: "Новый абонемент") {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack(spacing: 12) {
                                        Text("Количество занятий")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        HStack(spacing: 16) {
                                            Button {
                                                if totalSessionsCount > minSessions {
                                                    totalSessionsCount -= 1
                                                }
                                            } label: {
                                                Image(systemName: "minus.circle.fill")
                                                    .font(.title2)
                                                    .foregroundStyle(totalSessionsCount <= minSessions ? Color.secondary : AppDesign.primaryButtonColor)
                                            }
                                            .disabled(totalSessionsCount <= minSessions)
                                            Text("\(totalSessionsCount)")
                                                .font(.title2.monospacedDigit())
                                                .frame(minWidth: 44, alignment: .center)
                                            Button {
                                                if totalSessionsCount < maxSessions {
                                                    totalSessionsCount += 1
                                                }
                                            } label: {
                                                Image(systemName: "plus.circle.fill")
                                                    .font(.title2)
                                                    .foregroundStyle(totalSessionsCount >= maxSessions ? Color.secondary : AppDesign.primaryButtonColor)
                                            }
                                            .disabled(totalSessionsCount >= maxSessions)
                                        }
                                    }
                                    .padding(.vertical, 4)

                                    Text("Стоимость (₽, необязательно)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    TextField("Например 5000", text: $priceText)
                                        .keyboardType(.numberPad)
                                        .textFieldStyle(.roundedBorder)
                                }
                            }
                        }
                        .padding(.bottom, 24)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Абонемент")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { onCancel() }
                        .disabled(isCreating)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Создать") { onCreate(totalSessionsCount, priceRub) }
                        .disabled(isCreating)
                }
            }
        }
    }
}

private struct CoachActionRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .center)
            Text(title)
                .foregroundStyle(.primary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}


