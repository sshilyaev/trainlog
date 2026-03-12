//
//  RootView.swift
//  TrainLog
//

import SwiftUI
import UIKit
import AudioToolbox

struct RootView: View {
    @Bindable var appState: AppState
    @AppStorage("appTheme") private var appThemeRaw = AppTheme.system.rawValue
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    let authService: AuthServiceProtocol
    let profileService: ProfileServiceProtocol
    let measurementService: MeasurementServiceProtocol
    let goalService: GoalServiceProtocol
    let linkService: CoachTraineeLinkServiceProtocol
    let connectionTokenService: ConnectionTokenServiceProtocol
    let membershipService: MembershipServiceProtocol
    let visitService: VisitServiceProtocol
    let managedTraineeMergeService: ManagedTraineeMergeServiceProtocol

    var body: some View {
        Group {
            switch appState.currentScreen {
            case .splash:
                SplashView()

            case .auth:
                AuthView(
                    onSignIn: { email, password in
                        let uid = try await authService.signIn(email: email, password: password)
                        await MainActor.run {
                            appState.didAuthenticate(userId: uid)
                        }
                        await loadProfiles(userId: uid)
                    },
                    onSignUp: { displayName, email, password in
                        let uid = try await authService.signUp(email: email, password: password, displayName: displayName)
                        await MainActor.run {
                            appState.didAuthenticate(userId: uid)
                        }
                        await loadProfiles(userId: uid)
                    }
                )

            case .profileSelection:
                if appState.isLoadingProfiles {
                    fullScreenLoader()
                } else if hasSeenOnboarding {
                    ProfileSelectionView(
                        profiles: appState.profiles,
                        authService: authService,
                        accountDisplayName: authService.currentUserDisplayName,
                        onSelect: { appState.selectProfile($0) },
                        onCreate: { appState.showCreateProfile() },
                        onSignOut: {
                            try? authService.signOut()
                            appState.showAuth()
                        }
                    )
                } else {
                    OnboardingView(onFinish: { hasSeenOnboarding = true })
                }

            case .createProfile:
                if let uid = appState.userId {
                    CreateProfileView(
                        userId: uid,
                        onCreate: { profile in
                            let created = try await profileService.createProfile(profile)
                            await MainActor.run {
                                appState.createProfileError = nil
                                appState.showMain(afterCreating: created)
                            }
                        },
                        onCancel: {
                            appState.createProfileError = nil
                            appState.currentScreen = .profileSelection
                        },
                        createProfileError: appState.createProfileError,
                        onClearError: { appState.createProfileError = nil },
                        onError: { appState.createProfileError = $0 }
                    )
                } else {
                    SplashView()
                }

            case .main(let profile):
                mainView(for: profile)
            }
        }
        .id(appState.rootViewContentId)
        .preferredColorScheme(AppTheme(rawValue: appThemeRaw)?.preferredColorScheme)
        .onAppear {
            RootView.triggerLaunchHaptic()
        }
        .task {
            await runSplashAndInit()
        }
        .onChange(of: appState.authStatus) { _, newStatus in
            if case .authenticated(let uid) = newStatus {
                Task { await loadProfiles(userId: uid) }
            }
        }
        .alert("Ошибка", isPresented: Binding(
            get: { appState.globalError != nil },
            set: { if !$0 { appState.globalError = nil } }
        )) {
            Button("OK") { appState.globalError = nil }
        } message: {
            if let msg = appState.globalError { Text(msg) }
        }
    }

    @ViewBuilder
    private func mainView(for profile: Profile) -> some View {
        Group {
            if profile.isCoach {
                CoachMainView(
                    profile: profile,
                    onSwitchProfile: { appState.showProfileSelection() },
                    onDeleteProfile: { await deleteCurrentProfile() },
                    onProfileUpdated: { appState.updateProfile($0) },
                    linkService: linkService,
                    profileService: profileService,
                    measurementService: measurementService,
                    goalService: goalService,
                    connectionTokenService: connectionTokenService,
                    membershipService: membershipService,
                    visitService: visitService,
                    managedTraineeMergeService: managedTraineeMergeService,
                    myTraineeProfiles: appState.profiles.filter { $0.type == .trainee }
                )
            } else {
                TraineeMainView(
                    profile: profile,
                    measurementService: measurementService,
                    goalService: goalService,
                    connectionTokenService: connectionTokenService,
                    profileService: profileService,
                    membershipService: membershipService,
                    visitService: visitService,
                    linkService: linkService,
                    onSwitchProfile: { appState.showProfileSelection() },
                    onDeleteProfile: { await deleteCurrentProfile() },
                    onProfileUpdated: { appState.updateProfile($0) }
                )
            }
        }
    }

    private func runSplashAndInit() async {
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        authService.addAuthStateListener { _ in }
        if let uid = authService.currentUserId {
            appState.authStatus = .authenticated(userId: uid)
            await loadProfiles(userId: uid)
            // Экран после загрузки выставляет didLoadProfiles: либо .main(profile) при восстановлении, либо .profileSelection
        } else {
            await MainActor.run {
                appState.authStatus = .unauthenticated
                appState.currentScreen = .auth
            }
        }
    }

    private func loadProfiles(userId: String) async {
        do {
            let list = try await profileService.fetchProfiles(userId: userId)
            await MainActor.run {
                appState.didLoadProfiles(list)
            }
        } catch {
            await MainActor.run {
                appState.didFailLoadingProfiles(AppErrors.userMessage(for: error))
            }
        }
    }

    private func deleteCurrentProfile() async {
        guard let profile = appState.currentProfile else { return }
        do {
            try await profileService.deleteProfile(profile)
            await MainActor.run {
                appState.didDeleteProfile(profile)
            }
        } catch {
            await MainActor.run {
                appState.globalError = AppErrors.userMessage(for: error)
            }
        }
    }

    private func fullScreenLoader() -> some View {
        Color(.systemBackground)
            .overlay { LoadingView(message: "Загружаю профили") }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Вибрация при запуске: мягкая и подлиннее (серия лёгких ударов)

private extension RootView {
    static var hasTriggeredLaunchHaptic = false

    static func triggerLaunchHaptic() {
        guard !hasTriggeredLaunchHaptic else { return }
        hasTriggeredLaunchHaptic = true
        #if os(iOS)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            runLaunchHapticOnMainThread()
        }
        #endif
    }

    static func runLaunchHapticOnMainThread() {
        #if os(iOS)
        let lightGen = UIImpactFeedbackGenerator(style: .light)
        let mediumGen = UIImpactFeedbackGenerator(style: .medium)
        lightGen.prepare()
        mediumGen.prepare()

        let count = 160
        let interval: Double = 0.004

        func fire(at index: Int) {
            guard index < count else { return }
            if index <= 40 {
                mediumGen.impactOccurred(intensity: 0.55)
            } else if index < 40 && index > count - 50 {
                mediumGen.impactOccurred(intensity: 0.99)
            } else {
                lightGen.impactOccurred(intensity: 0.25)
            }
            
            let nextDelay = {
                switch (index, count) {
                case let (i, _) where i < 3:
                    return 0.7
                case let (i, c) where i >= c - 0:
                    return 0.05
                default:
                    return interval
                }
            }()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + nextDelay) {
                fire(at: index + 1)
            }
        }
        fire(at: 0)
        #endif
    }
}
