//
//  OnboardingView.swift
//  TrainLog
//

import SwiftUI

/// Многошаговый онбординг после первого входа. Без слова «подопечный».
struct OnboardingView: View {
    var onFinish: () -> Void

    @State private var currentStep = 0
    private let totalSteps = 4

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentStep) {
                stepWelcome.tag(0)
                stepWhyProfiles.tag(1)
                stepTypes.tag(2)
                stepReady.tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.25), value: currentStep)

            pageIndicator
                .padding(.top, 20)
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Шаг 1: Приветствие
    private var stepWelcome: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 60)

                Image(systemName: "figure.run")
                    .font(.system(size: 64))
                    .foregroundStyle(AppDesign.accent)
                    .symbolRenderingMode(.hierarchical)

                VStack(spacing: 8) {
                    Text("TrainLog")
                        .font(.title.bold())
                        .foregroundStyle(.primary)
                    Text("Дневник тренировок, замеров и целей")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                Spacer(minLength: 40)
            }
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Шаг 2: Зачем профили
    private var stepWhyProfiles: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 50)

                Image(systemName: "person.2.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(AppDesign.accent)
                    .symbolRenderingMode(.hierarchical)

                VStack(spacing: 12) {
                    Text("Один аккаунт — разные роли")
                        .font(.title2.bold())
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                    Text("Ведите личный дневник замеров или работайте как тренер со списком клиентов. Между профилями можно переключаться в один тап.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }

                Spacer(minLength: 40)
            }
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Шаг 3: Два типа профилей
    private var stepTypes: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer(minLength: 24)

                Text("Два типа профилей")
                    .font(.title2.bold())
                    .foregroundStyle(.primary)

                VStack(spacing: 12) {
                    OnboardingRoleCard(
                        icon: "figure.run",
                        title: "Дневник",
                        subtitle: "Замеры, цели, прогресс. Для себя или с тренером — один профиль на ваш дневник."
                    )
                    OnboardingRoleCard(
                        icon: "person.badge.key.fill",
                        title: "Тренер",
                        subtitle: "Список клиентов, абонементы, посещения. Всё в одном месте."
                    )
                }
                .padding(.horizontal, 20)

                Spacer(minLength: 40)
            }
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Шаг 4: Готовы начать
    private var stepReady: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer(minLength: 60)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(AppDesign.accent)

                VStack(spacing: 10) {
                    Text("Всё готово")
                        .font(.title2.bold())
                        .foregroundStyle(.primary)
                    Text("Создайте первый профиль и начните вести замеры или список клиентов.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }

                Spacer(minLength: 24)

                PrimaryActionButton(title: "Понятно", action: onFinish)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
            }
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Circle()
                    .fill(index == currentStep ? AppDesign.accent : Color(.tertiaryLabel))
                    .frame(width: 8, height: 8)
            }
        }
    }
}

// MARK: - Карточка типа профиля
private struct OnboardingRoleCard: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(AppDesign.accent)
                .frame(width: 48, height: 48)
                .background(AppDesign.accent.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.cornerRadius))
    }
}

#Preview {
    OnboardingView(onFinish: {})
}
