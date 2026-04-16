import Foundation

struct OpenRouterSummaryAI {
    let endpointURL: String
    let model: String

    func generateHistoryTitle(notes: String, bullets: [String]) async throws -> String {
        let sourceText = bullets.isEmpty ? notes : bullets.joined(separator: "\n")
        let content = try await sendChat(
            systemPrompt: """
            Create a very short title for a saved summary.
            Return only one title line.
            Keep it between 2 and 5 words.
            Do not use quotation marks, labels, hashtags, punctuation-heavy text, or conversational replies.
            Focus on the main topic of the document or notes.
            """,
            userPrompt: sourceText,
            temperature: 0.2
        )

        let title = cleanedHistoryTitle(content)
        guard !title.isEmpty else {
            throw SummaryError(message: "The cloud model returned an empty history title.")
        }
        return title
    }

    func summariseNotes(notes: String, configuration: SummaryConfiguration) async throws -> [String] {
        let content = try await sendChat(
            systemPrompt: """
            You are a text simplifier, not a chatbot.
            Your only job is to simplify and summarise document, OCR, or note-like text into short factual output.
            Treat contracts, forms, letters, study notes, meeting notes, and scanned document text as valid input.
            Only restate information already present in the text.
            Do not reply conversationally.
            \(outputInstructions(for: configuration))
            """,
            userPrompt: notes,
            temperature: 0.2
        )

        let bullets = parsedSummaryItems(from: content, configuration: configuration)
        let limit = configuration.format == .paragraph ? 1 : min(configuration.bulletCount, 6)
        let limitedBullets = Array(bullets.prefix(limit))
        guard !limitedBullets.isEmpty else {
            throw SummaryError(message: "The cloud model could not produce a usable summary from these notes.")
        }
        return limitedBullets
    }

    func generateStudyPack(
        notes: String,
        bullets: [String],
        flashcardCount: Int,
        quizQuestionCount: Int
    ) async throws -> StudyPack {
        async let flashcards = generateFlashcards(
            notes: notes,
            bullets: bullets,
            flashcardCount: flashcardCount
        )
        async let quizQuestions = generateQuizQuestions(
            notes: notes,
            bullets: bullets,
            quizQuestionCount: quizQuestionCount
        )

        return try await StudyPack(
            flashcards: flashcards,
            quizQuestions: quizQuestions
        )
    }

    private func generateFlashcards(notes: String, bullets: [String], flashcardCount: Int) async throws -> [StudyFlashcard] {
        let content = try await sendChat(
            systemPrompt: """
            Create revision flashcards for a student from the provided summary points and notes.
            Return exactly \(flashcardCount) flashcards.
            Vary the card kinds across definition, factRecall, causeEffect, and connection.
            Keep every flashcard tied directly to one summary point.
            Use this exact format, one flashcard per line:
            kind | source point number | prompt | answer
            Do not add numbering, markdown, or extra commentary.
            """,
            userPrompt: """
            Summary points:
            \(enumeratedSummaryPoints(from: bullets))

            Supporting notes:
            \(notes)
            """,
            temperature: 0.4
        )

        let flashcards = content
            .split(whereSeparator: \.isNewline)
            .compactMap { parseFlashcardLine(String($0)) }

        guard !flashcards.isEmpty else {
            throw SummaryError(message: "The cloud model could not build usable flashcards.")
        }

        return Array(flashcards.prefix(flashcardCount))
    }

    private func generateQuizQuestions(
        notes: String,
        bullets: [String],
        quizQuestionCount: Int
    ) async throws -> [QuizQuestion] {
        let content = try await sendChat(
            systemPrompt: """
            Create multiple choice quiz questions for a student from the provided summary points and notes.
            Return only valid JSON.
            Return exactly \(quizQuestionCount) objects in a JSON array.
            Each object must use this schema:
            {
              "style": "definitionCheck" | "factDate" | "causeEffect" | "examStyle",
              "sourceSummaryPoint": Int,
              "prompt": String,
              "correctAnswer": String,
              "wrongAnswers": [String, String, String]
            }
            Every wrong answer must stay on the same topic as the correct answer and read like a normal answer choice.
            Do not use meta phrases such as "the summary says" or "the notes mention".
            """,
            userPrompt: """
            Summary points:
            \(enumeratedSummaryPoints(from: bullets))

            Supporting notes:
            \(notes)
            """,
            temperature: 0.45
        )

        let drafts = try parseQuizDrafts(from: content)
        let questions = drafts.map(assembledQuizQuestion(from:))
        guard !questions.isEmpty else {
            throw SummaryError(message: "The cloud model could not build usable quiz questions.")
        }
        return Array(questions.prefix(quizQuestionCount))
    }

    private func sendChat(systemPrompt: String, userPrompt: String, temperature: Double) async throws -> String {
        guard let url = URL(string: endpointURL) else {
            throw SummaryError(message: "The Worker URL is invalid.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = OpenRouterChatRequest(
            model: model,
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: userPrompt)
            ],
            temperature: temperature
        )

        do {
            request.httpBody = try JSONEncoder().encode(payload)
        } catch {
            throw SummaryError(message: "The app could not encode the Worker request.")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw SummaryError(message: "The app could not reach your AI worker. Check the worker URL and try again.")
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SummaryError(message: "The worker response was invalid.")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let responseError = try? JSONDecoder().decode(OpenRouterErrorResponse.self, from: data)
            let message = detailedOpenRouterErrorMessage(
                from: responseError,
                statusCode: httpResponse.statusCode
            )
            throw SummaryError(message: message)
        }

        let decodedResponse: OpenRouterChatResponse
        do {
            decodedResponse = try JSONDecoder().decode(OpenRouterChatResponse.self, from: data)
        } catch {
            throw SummaryError(message: "The app could not read the worker response.")
        }

        let content = decodedResponse.choices
            .first?.message.content
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !content.isEmpty else {
            throw SummaryError(message: "OpenRouter returned an empty response.")
        }

        return content
    }

    private func parseFlashcardLine(_ text: String) -> StudyFlashcard? {
        let parts = text.components(separatedBy: "|").map(normalizedText)
        guard parts.count >= 4 else {
            return nil
        }

        let kind = StudyFlashcardKind(rawValue: parts[0]) ?? .factRecall
        let sourceSummaryPoint = Int(parts[1])
        let prompt = parts[2]
        let answer = normalizedText(parts[3...].joined(separator: "|"))
        guard !prompt.isEmpty, !answer.isEmpty else {
            return nil
        }

        return StudyFlashcard(
            kind: kind,
            sourceSummaryPoint: sourceSummaryPoint,
            prompt: prompt,
            answer: answer
        )
    }

    private func parseQuizDrafts(from text: String) throws -> [CloudQuizDraft] {
        let cleanedText: String
        if let startIndex = text.firstIndex(of: "["), let endIndex = text.lastIndex(of: "]") {
            cleanedText = String(text[startIndex...endIndex])
        } else {
            cleanedText = text
        }

        guard let data = cleanedText.data(using: .utf8) else {
            throw SummaryError(message: "The cloud quiz response could not be decoded.")
        }

        do {
            return try JSONDecoder().decode([CloudQuizDraft].self, from: data)
        } catch {
            throw SummaryError(message: "The cloud quiz response was not in the expected format.")
        }
    }

    private func assembledQuizQuestion(from draft: CloudQuizDraft) -> QuizQuestion {
        let correctAnswer = normalizedText(draft.correctAnswer)
        var options = [correctAnswer]
        options.append(contentsOf: draft.wrongAnswers.map(normalizedText))
        options = Array(NSOrderedSet(array: options)) as? [String] ?? options

        while options.count < 4 {
            options.append(contentsOf: localCorrelatedDistractors(
                for: correctAnswer,
                topic: localStudyTopic(from: correctAnswer),
                style: draft.style
            ))
            options = Array(NSOrderedSet(array: options)) as? [String] ?? options
        }

        var arrangedOptions = Array(options.prefix(4))
        arrangedOptions.shuffle()
        let correctIndex = arrangedOptions.firstIndex {
            $0.caseInsensitiveCompare(correctAnswer) == .orderedSame
        } ?? 0

        return QuizQuestion(
            style: draft.style,
            sourceSummaryPoint: draft.sourceSummaryPoint,
            prompt: normalizedText(draft.prompt),
            options: arrangedOptions,
            correctAnswerIndex: correctIndex,
            explanation: correctAnswer
        )
    }

    private func enumeratedSummaryPoints(from bullets: [String]) -> String {
        bullets
            .enumerated()
            .map { index, bullet in
                "Point \(index + 1): \(bullet)"
            }
            .joined(separator: "\n")
    }

    private func outputInstructions(for configuration: SummaryConfiguration) -> String {
        switch configuration.format {
        case .bullets:
            return "Return only \(configuration.bulletCount) concise bullet points. Make them \(configuration.detail.promptFragment)."
        case .paragraph:
            return "Return one clean paragraph only using about \(configuration.detail.paragraphSentenceLimit) sentences. Make it \(configuration.detail.promptFragment). Do not use bullets, hashtags, or headings."
        }
    }

    private func parsedSummaryItems(from text: String, configuration: SummaryConfiguration) -> [String] {
        switch configuration.format {
        case .bullets:
            return text
                .split(whereSeparator: \.isNewline)
                .map(cleanedBulletLine)
                .filter { !$0.isEmpty }
        case .paragraph:
            let cleanedParagraph = cleanedParagraph(text, sentenceLimit: configuration.detail.paragraphSentenceLimit)
            return cleanedParagraph.isEmpty ? [] : [cleanedParagraph]
        }
    }

    private func cleanedBulletLine(_ line: Substring) -> String {
        normalizedText(
            String(line)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "- ", with: "")
                .replacingOccurrences(of: "• ", with: "")
                .replacingOccurrences(of: "* ", with: "")
                .replacingOccurrences(of: "1. ", with: "")
                .replacingOccurrences(of: "2. ", with: "")
                .replacingOccurrences(of: "3. ", with: "")
                .replacingOccurrences(of: "4. ", with: "")
                .replacingOccurrences(of: "5. ", with: "")
                .replacingOccurrences(of: "6. ", with: "")
                .replacingOccurrences(of: "#", with: "")
                .replacingOccurrences(of: "**", with: "")
                .replacingOccurrences(of: "__", with: "")
                .replacingOccurrences(of: "`", with: "")
                .replacingOccurrences(of: "[", with: "")
                .replacingOccurrences(of: "]", with: "")
                .replacingOccurrences(of: "{", with: "")
                .replacingOccurrences(of: "}", with: "")
                .replacingOccurrences(of: "|", with: "")
                .replacingOccurrences(of: "•", with: "")
                .replacingOccurrences(of: "*", with: "")
        )
    }

    private func cleanedParagraph(_ text: String, sentenceLimit: Int) -> String {
        let cleaned = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")
            .replacingOccurrences(of: "`", with: "")
            .replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
            .replacingOccurrences(of: "{", with: "")
            .replacingOccurrences(of: "}", with: "")
            .replacingOccurrences(of: "|", with: "")
            .replacingOccurrences(of: "•", with: " ")
            .replacingOccurrences(of: "*", with: " ")
            .replacingOccurrences(of: "\n", with: " ")

        let normalized = normalizedText(cleaned)
        let sentences = normalized
            .split(whereSeparator: \.isNewline)
            .flatMap { $0.split(separator: ".", omittingEmptySubsequences: true) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !sentences.isEmpty else {
            return normalized
        }

        return sentences
            .prefix(sentenceLimit)
            .map { $0.hasSuffix(".") ? $0 : "\($0)." }
            .joined(separator: " ")
    }

    private func cleanedHistoryTitle(_ text: String) -> String {
        normalizedText(
            text
                .replacingOccurrences(of: "\"", with: "")
                .replacingOccurrences(of: "'", with: "")
                .replacingOccurrences(of: ":", with: "")
                .replacingOccurrences(of: "\n", with: " ")
        )
        .split(separator: " ")
        .prefix(5)
        .joined(separator: " ")
    }

    private func normalizedText(_ text: String) -> String {
        text
            .trimmingCharacters(in: CharacterSet(charactersIn: " -•*_#[]{}|"))
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func localStudyTopic(from bullet: String) -> String {
        let cleaned = bullet
            .replacingOccurrences(of: "[^A-Za-z0-9\\s-]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let fillerWords: Set<String> = [
            "the", "a", "an", "this", "that", "these", "those", "is", "are", "was", "were",
            "and", "or", "but", "of", "to", "for", "in", "on", "with", "by", "from", "as",
            "at", "into", "it", "its", "their", "there", "can", "may", "will", "be"
        ]

        let topicWords = cleaned
            .split(separator: " ")
            .map(String.init)
            .filter { !fillerWords.contains($0.lowercased()) }
            .prefix(5)

        let topic = topicWords.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        if !topic.isEmpty {
            return topic
        }

        let fallbackWords = cleaned.split(separator: " ").prefix(5).joined(separator: " ")
        return fallbackWords.isEmpty ? "this topic" : fallbackWords
    }

    private func localCorrelatedDistractors(for correctAnswer: String, topic: String, style: QuizQuestionStyle) -> [String] {
        let conciseTopic = topic.isEmpty ? "This topic" : topic

        let candidates: [String]
        switch style {
        case .definitionCheck:
            candidates = [
                "\(conciseTopic) is presented as a minor side issue rather than a main idea.",
                "\(conciseTopic) is described as depending mostly on manual effort instead of the process in the summary.",
                "\(conciseTopic) is framed as having the opposite role from the one described in the summary."
            ]
        case .factDate:
            candidates = [
                "\(conciseTopic) is treated as a minor detail with little effect on the main outcome.",
                "\(conciseTopic) is tied to a different fact than the one actually described.",
                "\(conciseTopic) is presented as unrelated to the key detail being tested."
            ]
        case .causeEffect:
            candidates = [
                "\(conciseTopic) is shown as causing the reverse outcome from the one in the summary.",
                "\(conciseTopic) is described as having no effect on the result discussed in the summary.",
                "\(conciseTopic) is linked to a different consequence than the one actually stated."
            ]
        case .examStyle:
            candidates = [
                "\(conciseTopic) is mentioned, but the conclusion goes beyond what the summary supports.",
                "\(conciseTopic) is discussed in a narrower way than this option suggests.",
                "\(conciseTopic) appears in the summary, but not with this conclusion or implication."
            ]
        }

        return candidates.filter { $0.caseInsensitiveCompare(correctAnswer) != .orderedSame }
    }

    private func detailedOpenRouterErrorMessage(
        from responseError: OpenRouterErrorResponse?,
        statusCode: Int
    ) -> String {
        guard let responseError else {
            return "OpenRouter returned HTTP \(statusCode)."
        }

        if let raw = responseError.error.metadata?.raw,
           let rawData = raw.data(using: .utf8),
           let decodedRaw = try? JSONDecoder().decode(OpenRouterProviderRawError.self, from: rawData) {
            if let message = decodedRaw.error, !message.isEmpty {
                return message
            }

            if let message = decodedRaw.message, !message.isEmpty {
                return message
            }
        }

        if responseError.error.message == "Provider returned error",
           let providerName = responseError.error.metadata?.providerName,
           !providerName.isEmpty {
            return "The selected OpenRouter provider (\(providerName)) rejected this request."
        }

        return responseError.error.message
    }
}

struct OpenRouterChatRequest: Encodable {
    let model: String
    let messages: [OpenRouterMessage]
    let temperature: Double
    let provider = OpenRouterProviderPreferences(allowFallbacks: true)
}

struct OpenRouterMessage: Encodable, Decodable {
    let role: String
    let content: String
}

struct OpenRouterChatResponse: Decodable {
    let choices: [OpenRouterChoice]
}

struct OpenRouterChoice: Decodable {
    let message: OpenRouterMessage
}

struct OpenRouterErrorResponse: Decodable {
    let error: OpenRouterErrorBody
}

struct OpenRouterErrorBody: Decodable {
    let message: String
    let metadata: OpenRouterErrorMetadata?
}

struct OpenRouterErrorMetadata: Decodable {
    let raw: String?
    let providerName: String?

    enum CodingKeys: String, CodingKey {
        case raw
        case providerName = "provider_name"
    }
}

struct OpenRouterProviderPreferences: Encodable {
    let allowFallbacks: Bool

    enum CodingKeys: String, CodingKey {
        case allowFallbacks = "allow_fallbacks"
    }
}

struct OpenRouterProviderRawError: Decodable {
    let error: String?
    let message: String?
    let code: String?
}

struct CloudQuizDraft: Decodable {
    let style: QuizQuestionStyle
    let sourceSummaryPoint: Int?
    let prompt: String
    let correctAnswer: String
    let wrongAnswers: [String]
}

struct SummaryError: Error {
    let message: String
}

extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else {
            return nil
        }

        return self[index]
    }
}
