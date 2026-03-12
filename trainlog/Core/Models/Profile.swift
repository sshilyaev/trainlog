//
//  Profile.swift
//  TrainLog
//

import Foundation

enum ProfileType: String, Codable, CaseIterable {
    case coach
    case trainee
}

enum ProfileGender: String, Codable, CaseIterable {
    case male
    case female

    var displayName: String {
        switch self {
        case .male: return "Мужской"
        case .female: return "Женский"
        }
    }
}

struct Profile: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let userId: String
    let type: ProfileType
    var name: String
    var gymName: String?
    let createdAt: Date
    var gender: ProfileGender?
    var iconEmoji: String?
    /// Если задано — это «managed» подопечный, созданный тренером без приложения.
    /// Владелец данных — тренерский профиль с этим id.
    var ownerCoachProfileId: String?
    /// Если managed-профиль объединён с реальным — сюда пишется id реального профиля.
    var mergedIntoProfileId: String?

    init(
        id: String,
        userId: String,
        type: ProfileType,
        name: String,
        gymName: String? = nil,
        createdAt: Date = Date(),
        gender: ProfileGender? = nil,
        iconEmoji: String? = nil,
        ownerCoachProfileId: String? = nil,
        mergedIntoProfileId: String? = nil
    ) {
        self.id = id
        self.userId = userId
        self.type = type
        self.name = name
        self.gymName = gymName
        self.createdAt = createdAt
        self.gender = gender
        self.iconEmoji = iconEmoji
        self.ownerCoachProfileId = ownerCoachProfileId
        self.mergedIntoProfileId = mergedIntoProfileId
    }

    var isCoach: Bool { type == .coach }
    var isTrainee: Bool { type == .trainee }
    var isManaged: Bool { ownerCoachProfileId != nil }

    var displaySubtitle: String? {
        isCoach ? gymName : nil
    }

    /// Набор emoji для выбора иконки профиля (nil = без иконки, дальше варианты).
    static let iconEmojiOptions: [String?] = [
        nil,
        "👤", "🏋️", "💪", "🎯", "❤️", "🔥", "⭐", "🌟",
        "📊", "🧘", "🏃", "🚴", "👨", "👩", "🦊", "🐱"
    ]
}
