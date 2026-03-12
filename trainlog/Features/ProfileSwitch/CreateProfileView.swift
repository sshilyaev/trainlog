//
//  CreateProfileView.swift
//  TrainLog
//

import SwiftUI
import UIKit

struct CreateProfileView: View {
    let userId: String
    @State private var name = ""
    @State private var profileType: ProfileType = .trainee
    @State private var gymName = ""
    @State private var gender: ProfileGender?
    @State private var genderSelection: GenderSelection = .male
    @State private var selectedIconEmoji: String? = nil
    @State private var isLoading = false

    var onCreate: (Profile) async throws -> Void
    var onCancel: () -> Void
    var createProfileError: String?
    var onClearError: () -> Void
    var onError: (String) -> Void

    private var profileTypeDescription: String {
        switch profileType {
        case .trainee:
            return "Замеры, цели, прогресс. Для себя или с тренером — один профиль на ваш дневник."
        case .coach:
            return "Список клиентов, абонементы, посещения. Всё в одном месте."
        }
    }

    private enum GenderSelection: Hashable {
        case male
        case female

        var genderValue: ProfileGender {
            switch self {
            case .male: return .male
            case .female: return .female
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    SettingsCard(title: "Тип профиля") {
                        Picker("Тип", selection: $profileType) {
                            Text("Дневник").tag(ProfileType.trainee)
                            Text("Тренер").tag(ProfileType.coach)
                        }
                        .pickerStyle(.segmented)

                        Text(profileTypeDescription)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(minHeight: 40)
                            .padding(.top, 10)
                            .animation(.easeInOut(duration: 0.2), value: profileType)
                    }

                    SettingsCard(title: "Имя") {
                        AppTextField(label: nil, text: $name, textContentType: .name, autocapitalization: .words)
                    }

                    if profileType == .coach {
                        SettingsCard(title: "Зал") {
                            AppTextField(label: nil, text: $gymName, textContentType: .organizationName, autocapitalization: .words)
                        }
                    }

                    SettingsCard {
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
            .navigationTitle("Новый профиль")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnTap()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        onCancel()
                    } label: {
                        Label("Назад", systemImage: "chevron.left")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.9)
                    } else {
                        Button("Создать") {
                            createProfile()
                        }
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .alert("Ошибка", isPresented: Binding(
                get: { createProfileError != nil },
                set: { if !$0 { onClearError() } }
            )) {
                Button("OK", action: onClearError)
            } message: {
                if let error = createProfileError { Text(error) }
            }
        }
    }

    private func createProfile() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isLoading = true
        Task {
            await MainActor.run { onClearError() }
            gender = genderSelection.genderValue
            let profile = Profile(
                id: UUID().uuidString,
                userId: userId,
                type: profileType,
                name: trimmed,
                gymName: profileType == .coach ? (gymName.isEmpty ? nil : gymName) : nil,
                gender: gender,
                iconEmoji: selectedIconEmoji
            )
            do {
                try await onCreate(profile)
            } catch {
                await MainActor.run { onError(AppErrors.userMessage(for: error)) }
            }
            await MainActor.run { isLoading = false }
        }
    }
}

#Preview {
    CreateProfileView(
        userId: "preview-user",
        onCreate: { _ in },
        onCancel: {},
        createProfileError: nil,
        onClearError: {},
        onError: { _ in }
    )
}
