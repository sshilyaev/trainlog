//
//  TrainLogApp.swift
//  TrainLog
//

import SwiftUI
import FirebaseCore

@main
struct TrainLogApp: App {
    private let appState: AppState
    private let authService: AuthServiceProtocol
    private let profileService: ProfileServiceProtocol
    private let measurementService: MeasurementServiceProtocol
    private let goalService: GoalServiceProtocol
    private let linkService: CoachTraineeLinkServiceProtocol
    private let connectionTokenService: ConnectionTokenServiceProtocol
    private let membershipService: MembershipServiceProtocol
    private let visitService: VisitServiceProtocol
    private let managedTraineeMergeService: ManagedTraineeMergeServiceProtocol

    init() {
        FirebaseApp.configure()
        appState = AppState()
        authService = FirebaseAuthService()
        profileService = FirestoreProfileService()
        measurementService = FirestoreMeasurementService()
        goalService = FirestoreGoalService()
        linkService = FirestoreCoachTraineeLinkService()
        connectionTokenService = FirestoreConnectionTokenService()
        membershipService = FirestoreMembershipService()
        visitService = FirestoreVisitService()
        managedTraineeMergeService = FirestoreManagedTraineeMergeService()
    }

    var body: some Scene {
        WindowGroup {
            RootView(
                appState: appState,
                authService: authService,
                profileService: profileService,
                measurementService: measurementService,
                goalService: goalService,
                linkService: linkService,
                connectionTokenService: connectionTokenService,
                membershipService: membershipService,
                visitService: visitService,
                managedTraineeMergeService: managedTraineeMergeService
            )
        }
    }
}
