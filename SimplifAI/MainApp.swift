import SwiftUI
import UniformTypeIdentifiers
import FoundationModels

struct ContentView: View {
    @State private var notesText: String = ""
    @State private var summaryBullets: [String] = []
    @State private var showingFileImporter = false
    @State private var importedFileName = "No file selected"
    @State private var isLoading = false
    @State private var errorMessage: String?
    @FocusState private var isNotesEditorFocused: Bool
    @State private var animateBackground = false

    private let primaryAccent = Color(red: 0.08, green: 0.36, blue: 0.67)
    private let secondaryAccent = Color(red: 0.17, green: 0.63, blue: 0.77)
    private let cardTextColor = Color(red: 0.14, green: 0.18, blue: 0.24)
    private let cardSecondaryTextColor = Color(red: 0.39, green: 0.45, blue: 0.54)

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundView

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        headerSection
                        importSection
                        notesSection
                        summariseButton
                        if isLoading {
                            loadingSection
                        }
                        if let errorMessage {
                            errorSection(message: errorMessage)
                        }
                        summarySection
                    }
                    .frame(maxWidth: 560)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    isNotesEditorFocused = false
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()

                    Button("Done") {
                        isNotesEditorFocused = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.plainText]
        ) { result in
            loadImportedFile(from: result)
        }
        .onAppear {
            animateBackground = true
        }
    }

    private var aiStatus: AIModelStatus {
        if #available(iOS 26.0, *) {
            let model = SystemLanguageModel.default

            switch model.availability {
            case .available:
                return .available
            case .unavailable(.deviceNotEligible):
                return .unavailable(
                    title: "This device does not support Apple Intelligence",
                    message: "You can still use the app, but on-device AI summaries need a supported Apple Intelligence device.",
                    icon: "iphone.slash"
                )
            case .unavailable(.appleIntelligenceNotEnabled):
                return .unavailable(
                    title: "Turn on Apple Intelligence",
                    message: "Enable Apple Intelligence in Settings before using on-device summaries.",
                    icon: "gearshape.fill"
                )
            case .unavailable(.modelNotReady):
                return .unavailable(
                    title: "The on-device model is still preparing",
                    message: "The model may still be downloading or preparing. Try again in a moment.",
                    icon: "arrow.down.circle.fill"
                )
            case .unavailable:
                return .unavailable(
                    title: "On-device AI is unavailable",
                    message: "The on-device model is not available right now.",
                    icon: "exclamationmark.circle.fill"
                )
            }
        } else {
            return .unavailable(
                title: "This iPhone version is too old",
                message: "On-device AI summaries require a newer iOS version with Apple Intelligence support.",
                icon: "exclamationmark.circle.fill"
            )
        }
    }

    private var backgroundView: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.90, green: 0.95, blue: 1.0),
                    Color(red: 0.96, green: 0.98, blue: 1.0),
                    Color(red: 0.98, green: 0.99, blue: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(secondaryAccent.opacity(0.30))
                .frame(width: 260, height: 260)
                .blur(radius: 26)
                .scaleEffect(animateBackground ? 1.15 : 0.92)
                .offset(
                    x: animateBackground ? 150 : 110,
                    y: animateBackground ? -240 : -285
                )
                .animation(
                    .easeInOut(duration: 8).repeatForever(autoreverses: true),
                    value: animateBackground
                )

            Circle()
                .fill(primaryAccent.opacity(0.22))
                .frame(width: 300, height: 300)
                .blur(radius: 32)
                .scaleEffect(animateBackground ? 0.95 : 1.16)
                .offset(
                    x: animateBackground ? -170 : -125,
                    y: animateBackground ? 290 : 225
                )
                .animation(
                    .easeInOut(duration: 10).repeatForever(autoreverses: true),
                    value: animateBackground
                )

            RoundedRectangle(cornerRadius: 80, style: .continuous)
                .fill(Color.white.opacity(0.55))
                .frame(width: 240, height: 240)
                .blur(radius: 28)
                .rotationEffect(.degrees(animateBackground ? 24 : -8))
                .offset(
                    x: animateBackground ? -130 : -70,
                    y: animateBackground ? -120 : -170
                )
                .animation(
                    .easeInOut(duration: 12).repeatForever(autoreverses: true),
                    value: animateBackground
                )
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [secondaryAccent, primaryAccent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 64, height: 64)

                    Image(systemName: "text.badge.star")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("SimplifAI")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(cardTextColor)

                    Text("Import your notes or type them below, then turn them into clean AI-ready summaries.")
                        .font(.subheadline)
                        .foregroundStyle(cardSecondaryTextColor)
                }
            }
        }
        .padding(20)
        .background(cardBackground)
    }

    private var importSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Import Notes")
                .font(.headline)
                .foregroundStyle(cardTextColor)

            Button(action: {
                showingFileImporter = true
            }) {
                Label("Import File", systemImage: "doc.badge.plus")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [secondaryAccent, primaryAccent],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(14)
            }

            Text("Selected file: \(importedFileName)")
                .font(.footnote)
                .foregroundStyle(cardSecondaryTextColor)

            Text("Supported file types: .txt")
                .font(.footnote)
                .foregroundStyle(cardSecondaryTextColor)
        }
        .padding(20)
        .background(cardBackground)
    }
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Enter your notes:")
                .font(.headline)
                .foregroundStyle(cardTextColor)

            TextEditor(text: $notesText)
                .frame(minHeight: 220)
                .focused($isNotesEditorFocused)
                .scrollContentBackground(.hidden)
                .padding(12)
                .background(Color.white.opacity(0.92))
                .foregroundStyle(cardTextColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(primaryAccent.opacity(0.14), lineWidth: 1)
                )
                .cornerRadius(16)
        }
        .padding(20)
        .background(cardBackground)
    }

    private var summariseButton: some View {
        Button(action: {
            Task {
                await summariseNotes()
            }
        }) {
            HStack {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "sparkles")
                }

                Text(isLoading ? "Summarising..." : "Summarise")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: [primaryAccent, secondaryAccent],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(16)
            .shadow(color: primaryAccent.opacity(0.22), radius: 14, x: 0, y: 8)
        }
        .disabled(isLoading || !aiStatus.isReady)
        .opacity((isLoading || !aiStatus.isReady) ? 0.8 : 1.0)
    }

    private var loadingSection: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text("The AI is reading your notes and building a summary.")
                .foregroundStyle(cardSecondaryTextColor)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private func errorSection(message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)

            Text(message)
                .foregroundStyle(cardTextColor)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Summary:")
                .font(.headline)
                .foregroundStyle(cardTextColor)

            VStack(alignment: .leading, spacing: 10) {
                if summaryBullets.isEmpty {
                    Text("Your AI summary will appear here.")
                        .foregroundStyle(cardSecondaryTextColor)
                } else {
                    ForEach(summaryBullets, id: \.self) { bullet in
                        HStack(alignment: .top, spacing: 10) {
                            Text("•")
                                .foregroundStyle(primaryAccent)

                            Text(bullet)
                                .foregroundStyle(cardTextColor)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
            .padding()
            .background(Color.white.opacity(0.92))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(primaryAccent.opacity(0.14), lineWidth: 1)
            )
            .cornerRadius(16)
        }
        .padding(20)
        .background(cardBackground)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color.white.opacity(0.84))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.65), lineWidth: 1)
            )
            .shadow(color: primaryAccent.opacity(0.10), radius: 18, x: 0, y: 10)
    }

    private func loadImportedFile(from result: Result<URL, Error>) {
        do {
            let fileURL = try result.get()
            let didAccessSecurityScopedResource = fileURL.startAccessingSecurityScopedResource()
            defer {
                if didAccessSecurityScopedResource {
                    fileURL.stopAccessingSecurityScopedResource()
                }
            }

            let fileData = try Data(contentsOf: fileURL)
            let fileText = try decodeImportedText(from: fileData)

            notesText = fileText
            importedFileName = fileURL.lastPathComponent
            errorMessage = nil
        } catch {
            importedFileName = "Could not import file"
            errorMessage = "The selected file could not be read as plain text."
        }
    }

    private func decodeImportedText(from data: Data) throws -> String {
        let supportedEncodings: [String.Encoding] = [
            .utf8,
            .unicode,
            .utf16,
            .utf16LittleEndian,
            .utf16BigEndian,
            .ascii,
            .isoLatin1
        ]

        for encoding in supportedEncodings {
            if let text = String(data: data, encoding: encoding) {
                return text
            }
        }

        throw CocoaError(.fileReadInapplicableStringEncoding)
    }

    @MainActor
    private func summariseNotes() async {
        errorMessage = nil

        let trimmedNotes = notesText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedNotes.isEmpty else {
            errorMessage = "Enter or import some notes first."
            return
        }

        guard aiStatus.isReady else {
            errorMessage = aiStatus.message
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let bullets = try await summariseOnDevice(notes: trimmedNotes)

            summaryBullets = bullets
        } catch let error as SummaryError {
            errorMessage = error.message
        } catch {
            errorMessage = "Something unexpected went wrong. Please try again."
        }
    }

    private func summariseOnDevice(notes: String) async throws -> [String] {
        if #available(iOS 26.0, *) {
            return try await OnDeviceSummaryService().summariseNotes(notes: notes)
        } else {
            throw SummaryError(message: "This iPhone version does not support on-device AI summaries.")
        }
    }
}

private struct OnDeviceSummaryService {
    @available(iOS 26.0, *)
    func summariseNotes(notes: String) async throws -> [String] {
        let instructions = """
        Summarise the person's notes into 3 to 6 short bullet points.
        Return only the bullet points.
        Keep each bullet concise, clear, and easy to scan.
        """

        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(to: notes)
        let text = response.content

        let bullets = text
            .split(whereSeparator: \.isNewline)
            .map { line in
                line
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "- ", with: "")
                    .replacingOccurrences(of: "• ", with: "")
                    .replacingOccurrences(of: "* ", with: "")
            }
            .filter { !$0.isEmpty }

        if bullets.isEmpty {
            throw SummaryError(message: "The AI response did not contain any bullet points.")
        }

        return bullets
    }
}

private struct AIModelStatus {
    let title: String
    let message: String
    let icon: String
    let isReady: Bool

    static let available = AIModelStatus(
        title: "Apple Intelligence is ready",
        message: "Your summaries will run directly on this device. No API key is needed.",
        icon: "checkmark.circle.fill",
        isReady: true
    )

    static func unavailable(title: String, message: String, icon: String) -> AIModelStatus {
        AIModelStatus(title: title, message: message, icon: icon, isReady: false)
    }
}

private struct SummaryError: Error {
    let message: String
}

@available(iOS 26.0, *)
extension SummaryError {
    init(generationError: LanguageModelSession.GenerationError) {
        switch generationError {
        case .unsupportedLanguageOrLocale:
            self.init(message: "This language is not supported by the on-device model.")
        case .exceededContextWindowSize:
            self.init(message: "These notes are too long for one on-device summary. Try a shorter note or split it into parts.")
        default:
            self.init(message: "The on-device model could not create a summary right now.")
        }
    }
}
