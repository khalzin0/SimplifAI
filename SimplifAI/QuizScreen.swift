import SwiftUI

struct QuizScreen: View {
    let studyQuizQuestions: [QuizQuestion]

    private let primaryAccent = Color(red: 0.08, green: 0.36, blue: 0.67)
    private let secondaryAccent = Color(red: 0.17, green: 0.63, blue: 0.77)
    private let contentWidth: CGFloat = 640
    private let horizontalScreenPadding: CGFloat = 20
    private let verticalScreenPadding: CGFloat = 28

    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedQuizAnswers: [Int: Int] = [:]
    @State private var submittedQuizQuestions: Set<Int> = []
    @State private var hasStartedQuiz = false
    @State private var hasFinishedQuiz = false

    private var isDarkModeActive: Bool {
        colorScheme == .dark
    }

    private var cardTextColor: Color {
        isDarkModeActive ? Color(red: 0.92, green: 0.95, blue: 0.98) : Color(red: 0.14, green: 0.18, blue: 0.24)
    }

    private var cardSecondaryTextColor: Color {
        isDarkModeActive ? Color(red: 0.68, green: 0.74, blue: 0.82) : Color(red: 0.39, green: 0.45, blue: 0.54)
    }

    private var quizScore: Int {
        studyQuizQuestions.enumerated().reduce(into: 0) { score, pair in
            if isQuizAnswerCorrect(questionIndex: pair.offset, question: pair.element) {
                score += 1
            }
        }
    }

    var body: some View {
        ZStack {
            backgroundView

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    pageIntro(
                        title: "Quiz",
                        subtitle: "Take the quiz on a dedicated page and see your final score at the end."
                    )

                    contentPanel {
                        quizContent
                    }
                }
                .frame(maxWidth: contentWidth)
                .padding(.horizontal, horizontalScreenPadding)
                .padding(.vertical, verticalScreenPadding)
            }
        }
        .navigationTitle("Quiz")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var quizContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !hasStartedQuiz {
                guideCard(
                    title: "Start Quiz",
                    text: "Begin a scored quiz session when you're ready. Your final score appears after you finish all questions."
                )

                HStack {
                    sectionHeader(title: "Quiz Ready", detail: "\(studyQuizQuestions.count) questions")
                    Spacer()
                }

                Button {
                    startQuizSession()
                } label: {
                    Label("Start Quiz", systemImage: "play.fill")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(.white)
                        .background(actionButtonBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            } else if hasFinishedQuiz {
                guideCard(
                    title: "Quiz Complete",
                    text: finalScoreMessage
                )

                HStack {
                    scoreBadge
                    Spacer()
                }

                ForEach(Array(studyQuizQuestions.enumerated()), id: \.offset) { index, question in
                    quizReviewCard(index: index, question: question)
                }

                Button {
                    startQuizSession()
                } label: {
                    Label("Restart Quiz", systemImage: "arrow.clockwise")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(.white)
                        .background(actionButtonBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            } else {
                HStack {
                    sectionHeader(
                        title: "Quiz In Progress",
                        detail: "Answered \(submittedQuizQuestions.count) of \(studyQuizQuestions.count)"
                    )
                    Spacer()
                }

                ForEach(Array(studyQuizQuestions.enumerated()), id: \.offset) { index, question in
                    quizQuestionCard(index: index, question: question)
                }
            }
        }
    }

    private func quizQuestionCard(index: Int, question: QuizQuestion) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Question \(index + 1)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(cardSecondaryTextColor)

                templateBadge(question.style.title)

                Spacer()

                if submittedQuizQuestions.contains(index) {
                    Text(isQuizAnswerCorrect(questionIndex: index, question: question) ? "Correct" : "Incorrect")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(isQuizAnswerCorrect(questionIndex: index, question: question) ? .green : .red)
                }
            }

            Text(question.prompt)
                .font(.headline)
                .foregroundStyle(cardTextColor)

            ForEach(Array(question.options.enumerated()), id: \.offset) { optionIndex, option in
                Button {
                    selectedQuizAnswers[index] = optionIndex
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: quizOptionSymbol(for: index, optionIndex: optionIndex, question: question))
                            .foregroundStyle(quizOptionColor(for: index, optionIndex: optionIndex, question: question))

                        Text(option)
                            .foregroundStyle(cardTextColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(quizOptionBackground(for: index, optionIndex: optionIndex, question: question))
                    )
                }
                .buttonStyle(.plain)
            }

            Button(submittedQuizQuestions.contains(index) ? "Checked" : "Check Answer") {
                submittedQuizQuestions.insert(index)
                if submittedQuizQuestions.count == studyQuizQuestions.count {
                    hasFinishedQuiz = true
                }
            }
            .disabled(selectedQuizAnswers[index] == nil || submittedQuizQuestions.contains(index))
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(actionButtonBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity((selectedQuizAnswers[index] == nil || submittedQuizQuestions.contains(index)) ? 0.65 : 1)

            if submittedQuizQuestions.contains(index) {
                Text(quizFeedbackText(for: index, question: question))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(quizFeedbackColor(for: index, question: question))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(primaryAccent.opacity(isDarkModeActive ? 0.14 : 0.07))
        )
    }

    private func quizReviewCard(index: Int, question: QuizQuestion) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Question \(index + 1)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(cardSecondaryTextColor)

                templateBadge(question.style.title)

                Spacer()

                Text(isQuizAnswerCorrect(questionIndex: index, question: question) ? "Correct" : "Incorrect")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isQuizAnswerCorrect(questionIndex: index, question: question) ? .green : .red)
            }

            Text(question.prompt)
                .font(.headline)
                .foregroundStyle(cardTextColor)

            Text("Answer: \(question.options[safe: question.correctAnswerIndex] ?? question.options.first ?? "")")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(cardSecondaryTextColor)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(primaryAccent.opacity(isDarkModeActive ? 0.14 : 0.07))
        )
    }

    private var finalScoreMessage: String {
        "You scored \(quizScore) out of \(studyQuizQuestions.count)."
    }

    private var scoreBadge: some View {
        Text("\(quizScore)/\(studyQuizQuestions.count)")
            .font(.headline.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [primaryAccent, secondaryAccent],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
    }

    private func startQuizSession() {
        selectedQuizAnswers = [:]
        submittedQuizQuestions = []
        hasStartedQuiz = true
        hasFinishedQuiz = false
    }

    private func isQuizAnswerCorrect(questionIndex: Int, question: QuizQuestion) -> Bool {
        selectedQuizAnswers[questionIndex] == question.correctAnswerIndex
    }

    private func quizOptionSymbol(for questionIndex: Int, optionIndex: Int, question: QuizQuestion) -> String {
        guard submittedQuizQuestions.contains(questionIndex) else {
            return selectedQuizAnswers[questionIndex] == optionIndex ? "largecircle.fill.circle" : "circle"
        }

        if optionIndex == question.correctAnswerIndex {
            return "checkmark.circle.fill"
        }

        if selectedQuizAnswers[questionIndex] == optionIndex {
            return "xmark.circle.fill"
        }

        return "circle"
    }

    private func quizOptionColor(for questionIndex: Int, optionIndex: Int, question: QuizQuestion) -> Color {
        guard submittedQuizQuestions.contains(questionIndex) else {
            return selectedQuizAnswers[questionIndex] == optionIndex ? primaryAccent : cardSecondaryTextColor
        }

        if optionIndex == question.correctAnswerIndex {
            return .green
        }

        if selectedQuizAnswers[questionIndex] == optionIndex {
            return .red
        }

        return cardSecondaryTextColor
    }

    private func quizOptionBackground(for questionIndex: Int, optionIndex: Int, question: QuizQuestion) -> Color {
        guard submittedQuizQuestions.contains(questionIndex) else {
            return selectedQuizAnswers[questionIndex] == optionIndex
                ? primaryAccent.opacity(isDarkModeActive ? 0.24 : 0.14)
                : Color.white.opacity(isDarkModeActive ? 0.04 : 0.55)
        }

        if optionIndex == question.correctAnswerIndex {
            return Color.green.opacity(isDarkModeActive ? 0.22 : 0.14)
        }

        if selectedQuizAnswers[questionIndex] == optionIndex {
            return Color.red.opacity(isDarkModeActive ? 0.20 : 0.12)
        }

        return Color.white.opacity(isDarkModeActive ? 0.04 : 0.55)
    }

    private func quizFeedbackText(for questionIndex: Int, question: QuizQuestion) -> String {
        selectedQuizAnswers[questionIndex] == question.correctAnswerIndex ? "Correct" : "Incorrect"
    }

    private func quizFeedbackColor(for questionIndex: Int, question: QuizQuestion) -> Color {
        selectedQuizAnswers[questionIndex] == question.correctAnswerIndex ? .green : .red
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

    private func sectionHeader(title: String, detail: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.headline)
                .foregroundStyle(cardTextColor)

            Spacer()

            Text(detail)
                .font(.subheadline)
                .foregroundStyle(cardSecondaryTextColor)
        }
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
