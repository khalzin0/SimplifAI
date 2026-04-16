import SwiftUI

struct ContentView: View {
    @AppStorage("hasSeenTutorial") private var hasSeenTutorial = false
    @AppStorage("reduceVisualEffects") private var reduceVisualEffects = false
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @State private var showLaunchAnimation = true
    @State private var showTutorial = false
    @State private var iconScale: CGFloat = 0.76
    @State private var haloOpacity = 0.0
    @State private var splashOpacity = 1.0
    @State private var splashTitleOpacity = 1.0
    @State private var contentOpacity = 0.0

    private let primaryAccent = Color(red: 0.08, green: 0.36, blue: 0.67)
    private let secondaryAccent = Color(red: 0.17, green: 0.63, blue: 0.77)

    private var isDarkModeActive: Bool {
        colorScheme == .dark
    }

    private var foregroundColor: Color {
        isDarkModeActive ? Color(red: 0.92, green: 0.95, blue: 0.98) : Color(red: 0.14, green: 0.18, blue: 0.24)
    }

    private var secondaryForegroundColor: Color {
        isDarkModeActive ? Color(red: 0.68, green: 0.74, blue: 0.82) : Color(red: 0.39, green: 0.45, blue: 0.54)
    }

    private var launchBackground: some View {
        LinearGradient(
            colors: [
                isDarkModeActive ? Color(red: 0.06, green: 0.10, blue: 0.16) : Color(red: 0.89, green: 0.94, blue: 1.0),
                isDarkModeActive ? Color(red: 0.08, green: 0.14, blue: 0.21) : Color(red: 0.95, green: 0.98, blue: 1.0),
                isDarkModeActive ? Color(red: 0.10, green: 0.16, blue: 0.24) : Color(red: 0.98, green: 0.99, blue: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(secondaryAccent.opacity(isDarkModeActive ? 0.18 : 0.22))
                .frame(width: 320, height: 320)
                .blur(radius: 36)
                .offset(x: 90, y: -120)
        }
        .overlay(alignment: .bottomLeading) {
            Circle()
                .fill(primaryAccent.opacity(isDarkModeActive ? 0.14 : 0.18))
                .frame(width: 280, height: 280)
                .blur(radius: 44)
                .offset(x: -110, y: 110)
        }
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                MainContentView()
                    .opacity(contentOpacity)
                    .environmentObject(subscriptionManager)

                if showLaunchAnimation {
                    launchSplash(in: proxy)
                }
            }
        }
            .fullScreenCover(isPresented: $showTutorial) {
                FirstRunTutorialView(
                    isDarkModeActive: isDarkModeActive,
                    primaryAccent: primaryAccent,
                    secondaryAccent: secondaryAccent
                ) {
                    hasSeenTutorial = true
                    showTutorial = false
                }
            }
            .task {
                withAnimation(.easeOut(duration: 0.42)) {
                    iconScale = 1
                    haloOpacity = 1
                }

                try? await Task.sleep(for: .milliseconds(240))

                withAnimation(.easeOut(duration: 0.44)) {
                    contentOpacity = 1
                }

                try? await Task.sleep(for: .milliseconds(380))

                withAnimation(.easeInOut(duration: 0.62)) {
                    iconScale = 0
                    haloOpacity = 0
                    splashTitleOpacity = 0
                }

                try? await Task.sleep(for: .milliseconds(500))

                withAnimation(.easeInOut(duration: 0.28)) {
                    splashOpacity = 0
                }

                try? await Task.sleep(for: .milliseconds(260))
                showLaunchAnimation = false

                if !hasSeenTutorial {
                    try? await Task.sleep(for: .milliseconds(120))
                    showTutorial = true
                }
            }
    }

    private func launchSplash(in proxy: GeometryProxy) -> some View {
        let finalIconCenter = CGPoint(x: 52, y: 58)
        let finalTitleCenter = CGPoint(x: 182, y: 56)
        let landingProgress = 1 - iconScale
        let currentIconY = interpolatedValue(from: proxy.size.height / 2, to: finalIconCenter.y, progress: landingProgress)
        let currentIconX = interpolatedValue(from: proxy.size.width / 2, to: finalIconCenter.x, progress: landingProgress)
        let currentTitleX = interpolatedValue(from: proxy.size.width / 2, to: finalTitleCenter.x, progress: landingProgress)
        let currentTitleY = interpolatedValue(from: proxy.size.height / 2 + 94, to: finalTitleCenter.y, progress: landingProgress)
        let backgroundSize = interpolatedValue(from: 118, to: 58, progress: landingProgress)
        let iconSize = interpolatedValue(from: 82, to: 36, progress: landingProgress)
        let cornerRadius = interpolatedValue(from: 34, to: 18, progress: landingProgress)
        let shadowRadius = interpolatedValue(from: 26, to: 6, progress: landingProgress)
        let shadowYOffset = interpolatedValue(from: 14, to: 3, progress: landingProgress)
        let strokeOpacity = interpolatedValue(from: 0.34, to: 0.22, progress: landingProgress)
        let overlayFadeProgress = easedProgress(splashOpacity)

        return ZStack {
            launchBackground

            Circle()
                .fill(secondaryAccent.opacity(isDarkModeActive ? 0.16 : 0.12))
                .frame(width: 180, height: 180)
                .blur(radius: 30)
                .opacity(haloOpacity)
                .position(x: currentIconX, y: currentIconY)

            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [secondaryAccent, primaryAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: backgroundSize, height: backgroundSize)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(strokeOpacity), lineWidth: 1.2)
                    )
                    .shadow(color: primaryAccent.opacity(0.28), radius: shadowRadius, x: 0, y: shadowYOffset)

                Image("iconUI")
                    .resizable()
                    .scaledToFit()
                    .frame(width: iconSize, height: iconSize)
                    .offset(x: 1, y: -1)
            }
            .position(x: currentIconX, y: currentIconY)

            Text("SimplifAI")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(foregroundColor)
                .opacity(0.96 * splashTitleOpacity)
                .position(x: currentTitleX, y: currentTitleY)
        }
        .opacity(overlayFadeProgress)
    }

    private func interpolatedValue(from start: CGFloat, to end: CGFloat, progress: CGFloat) -> CGFloat {
        let clampedProgress = max(0, min(1, progress))
        return start + ((end - start) * clampedProgress)
    }

    private func easedProgress(_ value: CGFloat) -> CGFloat {
        let clampedValue = max(0, min(1, value))
        return clampedValue * clampedValue * (3 - (2 * clampedValue))
    }
}

private struct FirstRunTutorialView: View {
    let isDarkModeActive: Bool
    let primaryAccent: Color
    let secondaryAccent: Color
    let onFinish: () -> Void

    @State private var selectedPage = 0
    @State private var cardVisible = true

    private let tutorialSteps: [TutorialStep] = [
        TutorialStep(
            title: "Import Or Paste Notes",
            text: "Everything starts in the Summarise tab. Bring in your material in the format you already use.",
            details: [
                "Use Import for text files, PDFs, or images.",
                "Scan a page with the camera or pull it from Photos.",
                "If you already have text, paste or type it directly into Notes."
            ],
            systemImage: "square.and.arrow.down"
        ),
        TutorialStep(
            title: "Generate A Summary",
            text: "Tap Summarise to turn raw material into something faster to review and easier to study from.",
            details: [
                "Use the settings icon to change summary detail and bullet count.",
                "Read through the summary before relying on it for class or revision.",
                "Use Copy Summary if you want to move it into another app."
            ],
            systemImage: "sparkles"
        ),
        TutorialStep(
            title: "Create Study Material",
            text: "Once you have a summary, Study mode can generate revision content when you decide you need it.",
            details: [
                "Generate flashcards and quiz questions from the summary.",
                "Use Study Settings to keep smart counts or set them manually.",
                "Treat the study pack like revision help, not guaranteed fact."
            ],
            systemImage: "book.closed"
        ),
        TutorialStep(
            title: "Use History And Templates",
            text: "You do not need to start over every time. The app keeps previous work ready to reopen.",
            details: [
                "History reloads the notes, summary, and saved study material.",
                "Templates help you switch between general and student-focused outputs.",
                "You can come back later and regenerate a fresh study set when needed."
            ],
            systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90"
        )
    ]

    var body: some View {
        ZStack {
            tutorialBackgroundBase

            VStack(alignment: .leading, spacing: 30) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Welcome To SimplifAI")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(foregroundColor)

                    Text("A short walkthrough so your first summary, study session, and history flow feel clear from the start.")
                        .font(.subheadline)
                        .foregroundStyle(secondaryForegroundColor)
                        .lineSpacing(3)
                }

                ZStack {
                    tutorialCard(tutorialSteps[selectedPage])
                        .opacity(cardVisible ? 1 : 0)
                        .scaleEffect(cardVisible ? 1 : 0.98)
                }
                .frame(height: 470)

                pageIndicator

                HStack(spacing: 12) {
                    Button {
                        onFinish()
                    } label: {
                        Text("Skip")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(secondaryForegroundColor)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(primaryAccent.opacity(isDarkModeActive ? 0.12 : 0.10))
                            )
                    }
                    .buttonStyle(.plain)
                    .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    Button {
                        advanceTutorial()
                    } label: {
                        Text(selectedPage == tutorialSteps.count - 1 ? "Done" : "Next")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [primaryAccent, secondaryAccent],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        }
    }

    private var tutorialBackgroundBase: some View {
        LinearGradient(
            colors: [
                isDarkModeActive ? Color(red: 0.06, green: 0.10, blue: 0.16) : Color(red: 0.89, green: 0.94, blue: 1.0),
                isDarkModeActive ? Color(red: 0.08, green: 0.14, blue: 0.21) : Color(red: 0.95, green: 0.98, blue: 1.0),
                isDarkModeActive ? Color(red: 0.10, green: 0.16, blue: 0.24) : Color(red: 0.98, green: 0.99, blue: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(secondaryAccent.opacity(isDarkModeActive ? 0.18 : 0.22))
                .frame(width: 320, height: 320)
                .blur(radius: 36)
                .offset(x: 90, y: -120)
        }
        .overlay(alignment: .bottomLeading) {
            Circle()
                .fill(primaryAccent.opacity(isDarkModeActive ? 0.14 : 0.18))
                .frame(width: 280, height: 280)
                .blur(radius: 44)
                .offset(x: -110, y: 110)
        }
    }

    private func tutorialCard(_ step: TutorialStep) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [secondaryAccent, primaryAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 88, height: 88)

                Image(systemName: step.systemImage)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Text(step.title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(foregroundColor)

            Text(step.text)
                .font(.title3.weight(.medium))
                .foregroundStyle(secondaryForegroundColor)
                .lineSpacing(4)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(step.details, id: \.self) { detail in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(primaryAccent.opacity(0.9))
                            .frame(width: 7, height: 7)
                            .padding(.top, 7)

                        Text(detail)
                            .font(.body)
                            .foregroundStyle(foregroundColor)
                            .lineSpacing(3)
                    }
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(isDarkModeActive ? Color.white.opacity(0.08) : Color.white.opacity(0.74))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(primaryAccent.opacity(isDarkModeActive ? 0.22 : 0.10), lineWidth: 1)
                )
        )
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(Array(tutorialSteps.indices), id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(index == selectedPage ? AnyShapeStyle(primaryAccent) : AnyShapeStyle(primaryAccent.opacity(0.22)))
                    .frame(width: index == selectedPage ? 24 : 8, height: 8)
                    .animation(.easeInOut(duration: 0.18), value: selectedPage)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func advanceTutorial() {
        if selectedPage == tutorialSteps.count - 1 {
            onFinish()
            return
        }

        withAnimation(.easeOut(duration: 0.18)) {
            cardVisible = false
        }

        Task {
            try? await Task.sleep(for: .milliseconds(180))
            selectedPage += 1
            withAnimation(.easeIn(duration: 0.24)) {
                cardVisible = true
            }
        }
    }

    private var foregroundColor: Color {
        isDarkModeActive ? Color(red: 0.92, green: 0.95, blue: 0.98) : Color(red: 0.14, green: 0.18, blue: 0.24)
    }

    private var secondaryForegroundColor: Color {
        isDarkModeActive ? Color(red: 0.68, green: 0.74, blue: 0.82) : Color(red: 0.39, green: 0.45, blue: 0.54)
    }
}

private struct TutorialStep {
    let title: String
    let text: String
    let details: [String]
    let systemImage: String
}
