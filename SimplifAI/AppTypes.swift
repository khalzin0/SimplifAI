import SwiftUI

enum AppTab: Hashable {
    case summarise
    case study
    case history
    case templates
    case settings
}

enum StudyMode: String, CaseIterable, Identifiable {
    case flashcards
    case quiz

    var id: String { rawValue }
}

enum DestructiveAction {
    case clearHistory
    case clearNotes
    case removeImportedFile
}

enum HistoryTitleStyle: String, CaseIterable, Identifiable {
    case aiShortened
    case sourceName
    case firstLine

    var id: String { rawValue }

    var title: String {
        switch self {
        case .aiShortened:
            return "AI Shortened"
        case .sourceName:
            return "File Name"
        case .firstLine:
            return "First Line"
        }
    }
}

enum SummaryTemplate: String, CaseIterable, Identifiable {
    case simpleSummary
    case leaseContract
    case studyNotes
    case examPrep
    case flashcards
    case keyTerms
    case meetingNotes
    case actionItems
    case plainEnglish

    var id: String { rawValue }

    var title: String {
        switch self {
        case .simpleSummary:
            return "Simple Summary"
        case .leaseContract:
            return "Lease / Contract"
        case .studyNotes:
            return "Study Notes"
        case .examPrep:
            return "Exam Prep"
        case .flashcards:
            return "Flashcards"
        case .keyTerms:
            return "Key Terms"
        case .meetingNotes:
            return "Meeting Notes"
        case .actionItems:
            return "Action Items"
        case .plainEnglish:
            return "Plain English"
        }
    }

    var subtitle: String {
        switch self {
        case .simpleSummary:
            return "Balanced, general-purpose notes and document summaries."
        case .leaseContract:
            return "Clear contract takeaways, obligations, dates, and payment terms."
        case .studyNotes:
            return "Structured learning points for revision and recall."
        case .examPrep:
            return "Pulls out likely testable concepts, cause-and-effect links, and must-remember facts."
        case .flashcards:
            return "Turns dense notes into short recall-ready answers you can review fast."
        case .keyTerms:
            return "Extracts the most important vocabulary, concepts, and definitions."
        case .meetingNotes:
            return "Condensed recap of decisions, updates, and next steps."
        case .actionItems:
            return "Pulls out the most actionable tasks and commitments."
        case .plainEnglish:
            return "Rewrites dense text into a more readable summary."
        }
    }

    var format: SummaryFormat {
        switch self {
        case .plainEnglish:
            return .paragraph
        default:
            return .bullets
        }
    }

    var detail: SummaryDetail {
        switch self {
        case .simpleSummary, .meetingNotes:
            return .standard
        case .leaseContract, .studyNotes, .examPrep, .flashcards, .keyTerms, .plainEnglish:
            return .detailed
        case .actionItems:
            return .brief
        }
    }

    var bulletCount: Int {
        switch self {
        case .simpleSummary:
            return 4
        case .leaseContract, .studyNotes, .meetingNotes, .keyTerms:
            return 5
        case .examPrep:
            return 6
        case .flashcards:
            return 4
        case .actionItems:
            return 3
        case .plainEnglish:
            return 4
        }
    }

    var isStudentFocused: Bool {
        switch self {
        case .studyNotes, .examPrep, .flashcards, .keyTerms:
            return true
        default:
            return false
        }
    }

    var studentValueMessage: String {
        switch self {
        case .studyNotes:
            return "Best for turning class notes into revision bullets you can reread before a quiz."
        case .examPrep:
            return "Best for pulling out high-yield points you would expect to see on an exam."
        case .flashcards:
            return "Best for quick memory drills and active recall sessions."
        case .keyTerms:
            return "Best when you need vocabulary, definitions, and concept spotting."
        default:
            return "Built to make revision faster."
        }
    }
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

enum SummaryFormat: String, CaseIterable, Identifiable {
    case bullets
    case paragraph

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bullets:
            return "Bullets"
        case .paragraph:
            return "Paragraph"
        }
    }
}

enum SummaryDetail: String, CaseIterable, Identifiable {
    case brief
    case standard
    case detailed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .brief:
            return "Brief"
        case .standard:
            return "Standard"
        case .detailed:
            return "Detailed"
        }
    }

    var promptFragment: String {
        switch self {
        case .brief:
            return "short and highly condensed"
        case .standard:
            return "clear and balanced"
        case .detailed:
            return "slightly more detailed while still concise"
        }
    }

    var paragraphSentenceLimit: Int {
        switch self {
        case .brief:
            return 2
        case .standard:
            return 4
        case .detailed:
            return 6
        }
    }
}

struct SummaryConfiguration {
    let format: SummaryFormat
    let detail: SummaryDetail
    let bulletCount: Int
}

enum StudyFlashcardKind: String, Codable, Hashable {
    case definition
    case causeEffect
    case factRecall
    case connection

    var title: String {
        switch self {
        case .definition:
            return "Definition"
        case .causeEffect:
            return "Cause & Effect"
        case .factRecall:
            return "Fact Recall"
        case .connection:
            return "Connection"
        }
    }
}

struct StudyFlashcard: Codable, Hashable {
    let kind: StudyFlashcardKind
    let sourceSummaryPoint: Int?
    let prompt: String
    let answer: String

    init(kind: StudyFlashcardKind = .factRecall, sourceSummaryPoint: Int? = nil, prompt: String, answer: String) {
        self.kind = kind
        self.sourceSummaryPoint = sourceSummaryPoint
        self.prompt = prompt
        self.answer = answer
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = try container.decodeIfPresent(StudyFlashcardKind.self, forKey: .kind) ?? .factRecall
        sourceSummaryPoint = try container.decodeIfPresent(Int.self, forKey: .sourceSummaryPoint)
        prompt = try container.decode(String.self, forKey: .prompt)
        answer = try container.decode(String.self, forKey: .answer)
    }
}

enum QuizQuestionStyle: String, Codable, Hashable {
    case definitionCheck
    case causeEffect
    case factDate
    case examStyle

    var title: String {
        switch self {
        case .definitionCheck:
            return "Definition Check"
        case .causeEffect:
            return "Cause & Effect"
        case .factDate:
            return "Fact / Date"
        case .examStyle:
            return "Exam Style"
        }
    }
}

struct QuizQuestion: Codable, Hashable {
    let style: QuizQuestionStyle
    let sourceSummaryPoint: Int?
    let prompt: String
    let options: [String]
    let correctAnswerIndex: Int
    let explanation: String

    init(
        style: QuizQuestionStyle = .examStyle,
        sourceSummaryPoint: Int? = nil,
        prompt: String,
        options: [String],
        correctAnswerIndex: Int,
        explanation: String
    ) {
        self.style = style
        self.sourceSummaryPoint = sourceSummaryPoint
        self.prompt = prompt
        self.options = options
        self.correctAnswerIndex = correctAnswerIndex
        self.explanation = explanation
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        style = try container.decodeIfPresent(QuizQuestionStyle.self, forKey: .style) ?? .examStyle
        sourceSummaryPoint = try container.decodeIfPresent(Int.self, forKey: .sourceSummaryPoint)
        prompt = try container.decode(String.self, forKey: .prompt)
        options = try container.decode([String].self, forKey: .options)
        correctAnswerIndex = try container.decode(Int.self, forKey: .correctAnswerIndex)
        explanation = try container.decode(String.self, forKey: .explanation)
    }
}

struct StudyPack: Codable, Hashable {
    let flashcards: [StudyFlashcard]
    let quizQuestions: [QuizQuestion]

    static let empty = StudyPack(flashcards: [], quizQuestions: [])

    func mergingFallbacks(from fallback: StudyPack) -> StudyPack {
        StudyPack(
            flashcards: flashcards.isEmpty ? fallback.flashcards : flashcards,
            quizQuestions: quizQuestions.isEmpty ? fallback.quizQuestions : quizQuestions
        )
    }
}

struct StudyCounts {
    let flashcards: Int
    let questions: Int
}
