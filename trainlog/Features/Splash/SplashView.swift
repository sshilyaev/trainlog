//
//  SplashView.swift
//  TrainLog
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Сплеш при запуске. Картинка **SplashLogo** из Assets. Пока набора нет — показывается иконка-заглушка.
struct SplashView: View {
    @State private var logoOpacity: Double = 0
    @State private var logoScale: CGFloat = 0.75
    @State private var titleOpacity: Double = 0
    @State private var titleOffset: CGFloat = 16
    @State private var taglineOpacity: Double = 0
    @State private var breathScale: CGFloat = 1
    @State private var usePlaceholder = false
    @State private var splashImageName = "SplashLogo"

    private var accentDark: Color { Color(red: 0.04, green: 0.14, blue: 0.16) }

    var body: some View {
        ZStack {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.06, green: 0.22, blue: 0.24), accentDark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .overlay {
                        Circle()
                            .fill(.white.opacity(0.06))
                            .frame(width: 320, height: 320)
                            .blur(radius: 80)
                            .offset(x: -100, y: -220)
                        Circle()
                            .fill(.black.opacity(0.1))
                            .frame(width: 280, height: 280)
                            .blur(radius: 70)
                            .offset(x: 120, y: 260)
                    }
                    .ignoresSafeArea()
                )

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                Group {
                    if usePlaceholder {
                        Image(systemName: "figure.run")
                            .font(.system(size: 72, weight: .medium))
                            .foregroundStyle(.white.opacity(0.95))
                    } else {
                        Image(splashImageName)
                            .resizable()
                            .scaledToFit()
                    }
                }
                .frame(maxWidth: 240, maxHeight: 200)
                .scaleEffect(logoScale * breathScale)
                .opacity(logoOpacity)
                .shadow(color: .black.opacity(0.25), radius: 16, x: 0, y: 6)

                Text("TrainLog")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .opacity(titleOpacity)
                    .offset(y: titleOffset)
                    .padding(.top, 28)

                Text("Дневник тренировок")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.88))
                    .opacity(taglineOpacity)
                    .padding(.top, 6)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 48)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            #if canImport(UIKit)
            let names = ["SplashLogo", "Logo", "splash_logo"]
            usePlaceholder = names.allSatisfy { UIImage(named: $0) == nil }
            if let found = names.first(where: { UIImage(named: $0) != nil }) {
                splashImageName = found
            }
            #endif
            withAnimation(.easeOut(duration: 0.6)) {
                logoOpacity = 1
                logoScale = 1
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.25)) {
                titleOpacity = 1
                titleOffset = 0
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.5)) {
                taglineOpacity = 1
            }
            withAnimation(.easeInOut(duration: 1.8).delay(0.7).repeatCount(2, autoreverses: true)) {
                breathScale = 1.14
            }
        }
    }
}

#Preview {
    SplashView()
}
