import SwiftUI

struct FlashcardsScreen: View {
    let studyFlashcards: [StudyFlashcard]
    @Binding var activeFlashcardIndex: Int
    @Binding var revealedFlashcardIndices: Set<Int>

    private let primaryAccent = Color(red: 0.08, green: 0.36, blue: 0.67)
    private let secondaryAccent = Color(red: 0.17, green: 0.63, blue: 0.77)
    private let contentWidth: CGFloat = 640
    private let horizontalScreenPadding: CGFloat = 20
    private let verticalScreenPadding: CGFloat = 28

    @Environment(\.colorScheme) private var colorScheme

    private var isDarkModeActive: Bool {
        colorScheme == .dark
    }

    private var cardTextColor: Color {
        isDarkModeActive ? Color(red: 0.92, green: 0.95, blue: 0.98) : Color(red: 0.14, green: 0.18, blue: 0.24)
    }

    private var cardSecondaryTextColor: Color {
        isDarkModeActive ? Color(red: 0.68, green: 0.74, blue: 0.82) : Color(red: 0.39, green: 0.45, blue: 0.54)
    }

    var body: some View {
        ZStack {
            backgroundView

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    pageIntro(
                        title: "Flashcards",
                        subtitle: "Flip through your study cards one at a time."
                    )

                    contentPanel {
                        flashcardsContent
                    }
                }
                .frame(maxWidth: contentWidth)
                .padding(.horizontal, horizontalScreenPadding)
                .padding(.vertical, verticalScreenPadding)
            }
        }
        .navigationTitle("Flashcards")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var flashcardsContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            if studyFlashcards.isEmpty {
                guideCard(title: "No Flashcards", text: "Generate a study set to start flipping through cards.")
            } else {
                let safeIndex = min(activeFlashcardIndex, max(studyFlashcards.count - 1, 0))
                let card = studyFlashcards[safeIndex]
                let isFlipped = revealedFlashcardIndices.contains(safeIndex)

                flashcardsOverviewCard(currentIndex: safeIndex, card: card, isFlipped: isFlipped)

                Button {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
                        if isFlipped {
                            revealedFlashcardIndices.remove(safeIndex)
                        } else {
                            revealedFlashcardIndices.insert(safeIndex)
                        }
                    }
                } label: {
                    ZStack {
                        flashcardFace(
                            title: "Card \(safeIndex + 1)",
                            badge: card.kind.title,
                            headline: card.prompt,
                            supportingText: "Tap to flip",
                            symbol: "arrow.triangle.2.circlepath",
                            rotation: isFlipped ? -180 : 0,
                            contentRotation: 0,
                            opacity: isFlipped ? 0 : 1
                        )

                        flashcardFace(
                            title: "Answer",
                            badge: card.kind.title,
                            headline: card.answer,
                            supportingText: "Tap to flip back",
                            symbol: "checkmark.seal.fill",
                            rotation: isFlipped ? 0 : 180,
                            contentRotation: 0,
                            opacity: isFlipped ? 1 : 0
                        )
                    }
                    .frame(height: 250)
                    .compositingGroup()
                }
                .buttonStyle(.plain)

                flashcardProgressStrip(currentIndex: safeIndex)

                HStack(spacing: 12) {
                    secondaryActionButton(title: "Previous", systemImage: "chevron.left") {
                        guard activeFlashcardIndex > 0 else {
                            return
                        }

                        withAnimation(.easeInOut(duration: 0.25)) {
                            activeFlashcardIndex -= 1
                        }
                    }
                    .opacity(activeFlashcardIndex == 0 ? 0.5 : 1)
                    .disabled(activeFlashcardIndex == 0)

                    Spacer()

                    Text("\(safeIndex + 1) / \(studyFlashcards.count)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(cardSecondaryTextColor)

                    Spacer()

                    secondaryActionButton(title: "Next", systemImage: "chevron.right") {
                        guard activeFlashcardIndex < studyFlashcards.count - 1 else {
                            return
                        }

                        withAnimation(.easeInOut(duration: 0.25)) {
                            activeFlashcardIndex += 1
                        }
                    }
                    .opacity(activeFlashcardIndex == studyFlashcards.count - 1 ? 0.5 : 1)
                    .disabled(activeFlashcardIndex == studyFlashcards.count - 1)
                }
            }
        }
        .padding(16)
        .background(editorBackground)
    }

    private func flashcardsOverviewCard(currentIndex: Int, card: StudyFlashcard, isFlipped: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Deck Progress")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(cardSecondaryTextColor)

                    Text("Card \(currentIndex + 1) of \(studyFlashcards.count)")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(cardTextColor)
                }

                Spacer()

                templateBadge(card.kind.title)
            }

            Text(isFlipped ? "Answer side is showing. Tap the card again to return to the prompt." : "Prompt side is showing. Tap the card to flip and reveal the answer.")
                .font(.subheadline)
                .foregroundStyle(cardSecondaryTextColor)

            if #available(iOS 26.0, *) {
                GlassEffectContainer(spacing: 14) {
                    HStack(spacing: 12) {
                        glassStatBadge(title: "Seen", value: "\(revealedFlashcardIndices.count)")
                        glassStatBadge(title: "Remaining", value: "\(max(studyFlashcards.count - currentIndex - 1, 0))")
                        glassStatBadge(title: "Mode", value: isFlipped ? "Answer" : "Prompt")
                    }
                }
            } else {
                HStack(spacing: 12) {
                    glassStatBadge(title: "Seen", value: "\(revealedFlashcardIndices.count)")
                    glassStatBadge(title: "Remaining", value: "\(max(studyFlashcards.count - currentIndex - 1, 0))")
                    glassStatBadge(title: "Mode", value: isFlipped ? "Answer" : "Prompt")
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            primaryAccent.opacity(isDarkModeActive ? 0.18 : 0.10),
                            secondaryAccent.opacity(isDarkModeActive ? 0.12 : 0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(primaryAccent.opacity(isDarkModeActive ? 0.24 : 0.14), lineWidth: 1)
                )
        )
    }

    private func flashcardProgressStrip(currentIndex: Int) -> some View {
        HStack(spacing: 8) {
            ForEach(Array(studyFlashcards.enumerated()), id: \.offset) { index, _ in
                Capsule(style: .continuous)
                    .fill(progressColor(for: index, currentIndex: currentIndex))
                    .frame(maxWidth: .infinity)
                    .frame(height: 8)
            }
        }
        .padding(.horizontal, 6)
    }

    private func progressColor(for index: Int, currentIndex: Int) -> Color {
        if index == currentIndex {
            return primaryAccent
        }

        if revealedFlashcardIndices.contains(index) {
            return secondaryAccent.opacity(isDarkModeActive ? 0.85 : 0.65)
        }

        return Color.white.opacity(isDarkModeActive ? 0.10 : 0.45)
    }

    private func glassStatBadge(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(cardSecondaryTextColor)

            Text(value)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(cardTextColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    isDarkModeActive
                    ? Color(red: 0.20, green: 0.26, blue: 0.36).opacity(0.88)
                    : Color.white.opacity(0.58)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            isDarkModeActive
                            ? primaryAccent.opacity(0.28)
                            : Color.white.opacity(0.65),
                            lineWidth: 1
                        )
                )
        )
        .modifier(HeaderGlassModifier())
        .overlay {
            if #available(iOS 26.0, *) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.clear)
                    .glassEffect(.regular.tint(primaryAccent.opacity(0.18)).interactive(), in: .rect(cornerRadius: 12))
            }
        }
    }

    private func flashcardFace(
        title: String,
        badge: String,
        headline: String,
        supportingText: String,
        symbol: String,
        rotation: Double,
        contentRotation: Double,
        opacity: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(cardSecondaryTextColor)

                templateBadge(badge)

                Spacer()

                Image(systemName: symbol)
                    .foregroundStyle(primaryAccent)
            }

            Spacer(minLength: 0)

            Text(headline)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.82)
                .lineLimit(6)
                .foregroundStyle(cardTextColor)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            Text(supportingText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(primaryAccent)
        }
        .rotation3DEffect(.degrees(contentRotation), axis: (x: 0, y: 1, z: 0))
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            primaryAccent.opacity(isDarkModeActive ? 0.22 : 0.12),
                            secondaryAccent.opacity(isDarkModeActive ? 0.14 : 0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(primaryAccent.opacity(isDarkModeActive ? 0.26 : 0.14), lineWidth: 1)
                )
        )
        .rotation3DEffect(.degrees(rotation), axis: (x: 0, y: 1, z: 0))
        .opacity(opacity)
        .shadow(color: primaryAccent.opacity(isDarkModeActive ? 0.28 : 0.16), radius: 20, x: 0, y: 12)
    }

    private func pageIntro(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(cardTextColor)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(cardSecondaryTextColor)
        }
    }

    private func contentPanel<Content: View>(
        spacing: CGFloat = 18,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: spacing) {
            content()
        }
        .padding(22)
        .background(mainPanelBackground)
    }

    private var mainPanelBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        isDarkModeActive ? Color(red: 0.10, green: 0.14, blue: 0.20).opacity(0.94) : Color.white.opacity(0.88),
                        isDarkModeActive ? Color(red: 0.12, green: 0.18, blue: 0.26).opacity(0.96) : Color(red: 0.96, green: 0.98, blue: 1.0).opacity(0.92)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke((isDarkModeActive ? primaryAccent : Color.white).opacity(isDarkModeActive ? 0.20 : 0.7), lineWidth: 1)
            )
            .shadow(color: primaryAccent.opacity(0.10), radius: 24, x: 0, y: 12)
    }

    private var editorBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(isDarkModeActive ? Color.white.opacity(0.08) : Color.white.opacity(0.82))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(primaryAccent.opacity(isDarkModeActive ? 0.22 : 0.12), lineWidth: 1)
            )
    }

    private var backgroundView: some View {
        ZStack {
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

            Circle()
                .fill(secondaryAccent.opacity(isDarkModeActive ? 0.18 : 0.22))
                .frame(width: 320, height: 320)
                .blur(radius: 36)
                .offset(x: 120, y: -220)

            Circle()
                .fill(primaryAccent.opacity(isDarkModeActive ? 0.14 : 0.18))
                .frame(width: 280, height: 280)
                .blur(radius: 44)
                .offset(x: -150, y: 260)
        }
    }

    private func guideCard(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(cardTextColor)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(cardSecondaryTextColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(editorBackground)
    }

    private func secondaryActionButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(cardSecondaryTextColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(primaryAccent.opacity(isDarkModeActive ? 0.12 : 0.08))
                )
        }
    }

    private func templateBadge(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(primaryAccent)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(primaryAccent.opacity(isDarkModeActive ? 0.18 : 0.10))
            )
    }
}
