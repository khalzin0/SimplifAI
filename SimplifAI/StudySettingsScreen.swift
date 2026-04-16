import SwiftUI

struct StudySettingsScreen: View {
    @Binding var studyUsesSmartCounts: Bool
    @Binding var studyFlashcardCount: Int
    @Binding var studyQuizQuestionCount: Int
    let notesText: String
    let summaryBullets: [String]

    private let primaryAccent = Color(red: 0.08, green: 0.36, blue: 0.67)
    private let secondaryAccent = Color(red: 0.17, green: 0.63, blue: 0.77)
    private let contentWidth: CGFloat = 640
    private let horizontalScreenPadding: CGFloat = 20
    private let verticalScreenPadding: CGFloat = 28
    private let studyCountRange = 2...12

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

    private var counts: StudyCounts {
        let cleanedBullets = summaryBullets
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard studyUsesSmartCounts else {
            return StudyCounts(
                flashcards: studyFlashcardCount,
                questions: studyQuizQuestionCount
            )
        }

        let noteWordCount = notesText.split { $0.isWhitespace || $0.isNewline }.count
        let bulletWordAverage = cleanedBullets.isEmpty
            ? 0
            : cleanedBullets
                .map { wordCount(for: $0) }
                .reduce(0, +) / cleanedBullets.count
        let bulletCount = max(cleanedBullets.count, 1)

        let densityBoost: Int
        switch noteWordCount {
        case 0..<160:
            densityBoost = 0
        case 160..<360:
            densityBoost = 1
        case 360..<650:
            densityBoost = 2
        default:
            densityBoost = 3
        }

        let detailBoost = bulletWordAverage >= 12 ? 1 : 0
        let recommendedFlashcards = min(max(bulletCount + densityBoost + detailBoost, 2), 12)
        let recommendedQuestions = min(
            max(Int(ceil(Double(bulletCount) * 0.75)) + max(densityBoost - 1, 0) + detailBoost, 2),
            12
        )

        return StudyCounts(
            flashcards: recommendedFlashcards,
            questions: recommendedQuestions
        )
    }

    private func wordCount(for text: String) -> Int {
        text.split { $0.isWhitespace || $0.isNewline }.count
    }

    var body: some View {
        ZStack {
            backgroundView

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    pageIntro(
                        title: "Study Settings",
                        subtitle: "Let the app size each study set automatically, or override it yourself."
                    )

                    contentPanel {
                        Toggle(isOn: $studyUsesSmartCounts) {
                            settingsRow(
                                title: "Smart Study Counts",
                                detail: "Automatically scale flashcards and quiz questions from the current summary."
                            )
                        }
                        .tint(primaryAccent)

                        countsSummaryCard

                        if studyUsesSmartCounts {
                            Text("Manual controls stay available here if you want tighter or longer study sets later.")
                                .font(.footnote)
                                .foregroundStyle(cardSecondaryTextColor)
                        } else {
                            studyCountControl(
                                title: "Flashcards",
                                value: studyFlashcardCount,
                                range: studyCountRange
                            ) {
                                studyFlashcardCount -= 1
                            } onIncrement: {
                                studyFlashcardCount += 1
                            }

                            studyCountControl(
                                title: "Questions",
                                value: studyQuizQuestionCount,
                                range: studyCountRange
                            ) {
                                studyQuizQuestionCount -= 1
                            } onIncrement: {
                                studyQuizQuestionCount += 1
                            }
                        }
                    }
                }
                .frame(maxWidth: contentWidth)
                .padding(.horizontal, horizontalScreenPadding)
                .padding(.vertical, verticalScreenPadding)
            }
        }
        .navigationTitle("Study Settings")
        .navigationBarTitleDisplayMode(.inline)
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

    private func settingsRow(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .foregroundStyle(cardTextColor)

            Text(detail)
                .font(.subheadline)
                .foregroundStyle(cardSecondaryTextColor)
        }
    }

    private func headerBadge(title: String, value: String) -> some View {
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
    }

    private var countsSummaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(studyUsesSmartCounts ? "Smart Study Counts" : "Manual Study Counts")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(cardTextColor)

                    Text(studyUsesSmartCounts
                         ? "The app adjusts the study set size from the summary length and note density."
                         : "The study set will use your chosen flashcard and quiz counts.")
                        .font(.footnote)
                        .foregroundStyle(cardSecondaryTextColor)
                }

                Spacer()

                Image(systemName: studyUsesSmartCounts ? "sparkles" : "slider.horizontal.3")
                    .font(.headline)
                    .foregroundStyle(primaryAccent)
            }

            HStack(spacing: 12) {
                headerBadge(title: "Flashcards", value: "\(counts.flashcards)")
                headerBadge(title: "Questions", value: "\(counts.questions)")
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    isDarkModeActive
                    ? Color(red: 0.18, green: 0.24, blue: 0.34).opacity(0.84)
                    : Color.white.opacity(0.74)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(primaryAccent.opacity(isDarkModeActive ? 0.26 : 0.12), lineWidth: 1)
                )
        )
    }

    private func studyCountControl(
        title: String,
        value: Int,
        range: ClosedRange<Int>,
        onDecrement: @escaping () -> Void,
        onIncrement: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 16) {
            Text("\(title): \(value)")
                .font(.title3.weight(.medium))
                .foregroundStyle(cardSecondaryTextColor)

            Spacer()

            HStack(spacing: 10) {
                Button(action: onDecrement) {
                    Image(systemName: "minus")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(actionButtonBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(value <= range.lowerBound)
                .opacity(value <= range.lowerBound ? 0.55 : 1)

                Button(action: onIncrement) {
                    Image(systemName: "plus")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(actionButtonBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(value >= range.upperBound)
                .opacity(value >= range.upperBound ? 0.55 : 1)
            }
        }
        .padding(.vertical, 4)
    }

    private var actionButtonBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [primaryAccent, secondaryAccent],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
    }
}
