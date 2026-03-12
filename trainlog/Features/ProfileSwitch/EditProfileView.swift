//
//  EditProfileView.swift
//  TrainLog
//

import SwiftUI
import UIKit

/// Результат редактирования — только изменяемые поля (value types), чтобы безопасно передавать из sheet в async.
struct EditProfileData {
    let name: String
    let gymName: String?
    let gender: ProfileGender?
    let iconEmoji: String?
}

struct EditProfileView: View {
    /// Копии полей профиля на момент открытия sheet (не храним Profile — из-за этого была ошибка «cannot decode string»).
    let profileId: String
    let userId: String
    let profileType: ProfileType
    let initialName: String
    let initialGymName: String
    let createdAt: Date
    let initialGender: ProfileGender?
    let initialIconEmoji: String?

    let onSave: (EditProfileData) -> Void
    let onCancel: () -> Void
    let onDismiss: () -> Void

    @State private var name: String
    @State private var gymName: String
    @State private var gender: ProfileGender?
    @State private var genderSelection: GenderSelection
    @State private var selectedIconEmoji: String?

    private enum GenderSelection: Hashable {
        case male
        case female

        init(_ gender: ProfileGender?) {
            switch gender {
            case .male: self = .male
            case .female: self = .female
            case nil: self = .male
            }
        }

        var genderValue: ProfileGender {
            switch self {
            case .male: return .male
            case .female: return .female
            }
        }
    }

    init(
        profileId: String,
        userId: String,
        profileType: ProfileType,
        initialName: String,
        initialGymName: String,
        createdAt: Date,
        initialGender: ProfileGender?,
        initialIconEmoji: String?,
        onSave: @escaping (EditProfileData) -> Void,
        onCancel: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.profileId = profileId
        self.userId = userId
        self.profileType = profileType
        self.initialName = initialName
        self.initialGymName = initialGymName
        self.createdAt = createdAt
        self.initialGender = initialGender
        self.initialIconEmoji = initialIconEmoji
        self.onSave = onSave
        self.onCancel = onCancel
        self.onDismiss = onDismiss
        _name = State(initialValue: initialName)
        _gymName = State(initialValue: initialGymName)
        _gender = State(initialValue: initialGender)
        _genderSelection = State(initialValue: GenderSelection(initialGender))
        _selectedIconEmoji = State(initialValue: initialIconEmoji)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    EditableCardRow(
                        icon: "person.fill",
                        title: "Имя",
                        text: $name,
                        textContentType: .name,
                        autocapitalization: .words
                    )

                    if profileType == .coach {
                        EditableCardRow(
                            icon: "building.2",
                            title: "Зал",
                            text: $gymName,
                            textContentType: .organizationName,
                            autocapitalization: .words
                        )
                    }

                    SettingsCard(title: "Пол") {
                        SegmentedPicker(
                            title: "",
                            selection: $genderSelection,
                            options: [
                                (.male, "Мужской"),
                                (.female, "Женский")
                            ]
                        )
                    }

                    SettingsCard(title: "Иконка") {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
                            ForEach(Array(Profile.iconEmojiOptions.enumerated()), id: \.offset) { _, emoji in
                                Button {
                                    selectedIconEmoji = emoji
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(selectedIconEmoji == emoji ? AppDesign.primaryButtonColor.opacity(0.15) : Color(.systemFill))
                                            .frame(width: 44, height: 44)
                                        if let emoji {
                                            Text(emoji)
                                                .font(.title2)
                                        } else {
                                            Image(systemName: "person.crop.circle")
                                                .font(.title2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .buttonStyle(PressableButtonStyle())
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Редактировать профиль")
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnTap()
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        onCancel()
                    } label: {
                        Label("Назад", systemImage: "chevron.left")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Обновить") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        gender = genderSelection.genderValue
        let gym: String? = profileType == .coach ? (gymName.isEmpty ? nil : String(gymName)) : nil
        let data = EditProfileData(
            name: String(trimmed),
            gymName: gym,
            gender: gender,
            iconEmoji: selectedIconEmoji
        )
        onSave(data)
        onDismiss()
    }
}

private struct EditableCardRow: View {
    let icon: String
    let title: String
    @Binding var text: String
    var textContentType: UITextContentType? = nil
    var autocapitalization: TextInputAutocapitalization = .sentences

    var body: some View {
        SettingsCard {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                    .frame(width: 28, alignment: .center)
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
                TextField("", text: $text)
                    .textContentType(textContentType)
                    .textInputAutocapitalization(autocapitalization)
                    .multilineTextAlignment(.trailing)
            }
        }
    }
}

struct EditProfileSnapshot: Identifiable {
    var id: String { profileId }
    let profileId: String
    let userId: String
    let profileType: ProfileType
    let initialName: String
    let initialGymName: String
    let createdAt: Date
    let initialGender: ProfileGender?
    let initialIconEmoji: String?
}

#Preview {
    EditProfileView(
        profileId: "1",
        userId: "u1",
        profileType: .coach,
        initialName: "Зал Арбат",
        initialGymName: "Фитнес Арбат",
        createdAt: Date(),
        initialGender: nil,
        initialIconEmoji: "🏋️",
        onSave: { _ in },
        onCancel: {},
        onDismiss: {}
    )
}
