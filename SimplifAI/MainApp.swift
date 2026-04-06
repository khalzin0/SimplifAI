import SwiftUI
import UniformTypeIdentifiers
import FoundationModels
import PDFKit
import PhotosUI
import SwiftData
import UIKit
import Vision

struct MainContentView: View {
    private let contentWidth: CGFloat = 640
    private let horizontalScreenPadding: CGFloat = 20
    private let verticalScreenPadding: CGFloat = 28
    private let maximumSummaryWordCount = 3_000
    private let noFileSelectedName = "No file selected"
    private let manualNotesSourceName = "Manual Notes"
    @AppStorage("appAppearance") private var appAppearanceRawValue = AppAppearance.system.rawValue
    @AppStorage("preferLargeText") private var preferLargeText = false
    @AppStorage("reduceVisualEffects") private var reduceVisualEffects = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Item.timestamp, order: .reverse) private var historyItems: [Item]
    @State private var selectedTab: AppTab = .summarise
    @State private var notesText: String = ""
    @State private var summaryBullets: [String] = []
    @State private var summaryFormat: SummaryFormat = .bullets
    @State private var summaryDetail: SummaryDetail = .standard
    @State private var summaryBulletCount = 4
    @State private var showingFileImporter = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showingPhotoPicker = false
    @State private var showingCamera = false
    @State private var importedFileName = "No file selected"
    @State private var importedPreviewText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @FocusState private var isNotesEditorFocused: Bool
    
    private let primaryAccent = Color(red: 0.08, green: 0.36, blue: 0.67)
    private let secondaryAccent = Color(red: 0.17, green: 0.63, blue: 0.77)
    private var selectedAppearance: AppAppearance {
        AppAppearance(rawValue: appAppearanceRawValue) ?? .system
    }
    
    private var preferredColorScheme: ColorScheme? {
        selectedAppearance.colorScheme
    }

    private var cardTextColor: Color {
        isDarkModeActive ? Color(red: 0.92, green: 0.95, blue: 0.98) : Color(red: 0.14, green: 0.18, blue: 0.24)
    }

    private var cardSecondaryTextColor: Color {
        isDarkModeActive ? Color(red: 0.68, green: 0.74, blue: 0.82) : Color(red: 0.39, green: 0.45, blue: 0.54)
    }

    private var isDarkModeActive: Bool {
        colorScheme == .dark
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                ZStack {
                    backgroundView

                    tabScrollContent {
                        headerSection
                        contentPanel {
                            importSection
                            if !importedPreviewText.isEmpty {
                                importedPreviewSection
                            }
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
            .tabItem {
                Label("Summarise", systemImage: "sparkles.rectangle.stack")
            }
            .tag(AppTab.summarise)

            NavigationStack {
                ZStack {
                    backgroundView

                    tabScrollContent {
                        VStack(alignment: .leading, spacing: 18) {
                            Text("History")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(cardTextColor)

                            Text("Reopen previous summaries and continue from them.")
                                .font(.subheadline)
                                .foregroundStyle(cardSecondaryTextColor)

                            contentPanel(spacing: 16) {
                                if historyItems.isEmpty {
                                    guideCard(
                                        title: "No History Yet",
                                        text: "Create a summary in the Summarise tab and it will appear here."
                                    )
                                } else {
                                    ForEach(historyItems) { item in
                                        historyCard(item)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .tabItem {
                Label("History", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
            }
            .tag(AppTab.history)

            NavigationStack {
                ZStack {
                    backgroundView

                    tabScrollContent {
                        VStack(alignment: .leading, spacing: 18) {
                            Text("Settings")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(cardTextColor)

                            Text("Choose the app appearance and accessibility preferences.")
                                .font(.subheadline)
                                .foregroundStyle(cardSecondaryTextColor)

                            contentPanel {
                                settingsSectionTitle("Appearance")

                                Picker("Appearance", selection: $appAppearanceRawValue) {
                                    ForEach(AppAppearance.allCases) { appearance in
                                        Text(appearance.title).tag(appearance.rawValue)
                                    }
                                }
                                .pickerStyle(.segmented)

                                Spacer()
                                    .frame(height: 8)

                                settingsSectionTitle("Accessibility")

                                Toggle(isOn: $preferLargeText) {
                                    settingsRow(
                                        title: "Larger Text",
                                        detail: "Uses a larger dynamic type size throughout the app."
                                    )
                                }
                                .tint(primaryAccent)

                                Toggle(isOn: $reduceVisualEffects) {
                                    settingsRow(
                                        title: "Reduce Visual Effects",
                                        detail: "Uses a calmer background with less visual layering."
                                    )
                                }
                                .tint(primaryAccent)

                                Spacer()
                                    .frame(height: 8)

                                settingsSectionTitle("App Info")

                                settingsRow(
                                    title: "Version",
                                    detail: appVersionDescription
                                )

                                settingsRow(
                                    title: "Made By",
                                    detail: "Khalid Alenizy"
                                )
                            }
                        }
                    }
                }
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
            .tag(AppTab.settings)
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: supportedContentTypes
        ) { result in
            loadImportedFile(from: result)
        }
        .photosPicker(
            isPresented: $showingPhotoPicker,
            selection: $selectedPhotoItem,
            matching: .images
        )
        .task(id: selectedPhotoItem) {
            await loadSelectedPhoto()
        }
        .sheet(isPresented: $showingCamera) {
            CameraPicker { image in
                loadCapturedImage(image)
            }
        }
        .preferredColorScheme(preferredColorScheme)
        .dynamicTypeSize(preferLargeText ? .large ... .accessibility1 : .xSmall ... .xxxLarge)
    }

    private var supportedContentTypes: [UTType] {
        var contentTypes: [UTType] = [.plainText, .utf8PlainText, .rtf, .pdf, .image]

        if let markdownType = UTType(filenameExtension: "md") {
            contentTypes.append(markdownType)
        }

        return contentTypes
    }

    private func tabScrollContent<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                content()
            }
            .frame(maxWidth: contentWidth)
            .padding(.horizontal, horizontalScreenPadding)
            .padding(.vertical, verticalScreenPadding)
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

            if !reduceVisualEffects {
                Circle()
                    .fill(secondaryAccent.opacity(isDarkModeActive ? 0.18 : 0.22))
                    .frame(width: 320, height: 320)
                    .blur(radius: 36)
                    .offset(x: 180, y: -250)

                Circle()
                    .fill(primaryAccent.opacity(isDarkModeActive ? 0.14 : 0.18))
                    .frame(width: 280, height: 280)
                    .blur(radius: 44)
                    .offset(x: -170, y: 260)

                RoundedRectangle(cornerRadius: 80, style: .continuous)
                    .fill((isDarkModeActive ? Color.white : Color.white).opacity(isDarkModeActive ? 0.12 : 0.38))
                    .frame(width: 260, height: 260)
                    .blur(radius: 34)
                    .rotationEffect(.degrees(18))
                    .offset(x: -120, y: -140)
            }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [secondaryAccent, primaryAccent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 58, height: 58)

                    appHeaderIcon
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("SimplifAI")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(cardTextColor)

                    Text("Import a file or paste your notes, review the text, then turn it into a cleaner summary.")
                        .font(.subheadline)
                        .foregroundStyle(cardSecondaryTextColor)
                }
            }

            HStack {
                headerBadge(title: "Supported Files", value: ".txt .md .rtf .pdf")
                Spacer()
                headerBadge(title: "Limit", value: "\(maximumSummaryWordCount) words")
            }
        }
        .padding(.horizontal, 2)
    }

    private var importSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Import")
                    .font(.headline)
                    .foregroundStyle(cardTextColor)

                Spacer()

                NavigationLink {
                    summarySettingsPage
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(actionButtonBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.35), lineWidth: 1)
                        )
                        .shadow(color: primaryAccent.opacity(0.18), radius: 10, x: 0, y: 6)
                }
                .accessibilityLabel("Summary settings")
            }

            HStack(spacing: 12) {
                Menu {
                    Button {
                        showingFileImporter = true
                    } label: {
                        Label("Choose File", systemImage: "doc.badge.plus")
                    }

                    Button {
                        showingPhotoPicker = true
                    } label: {
                        Label("Photos", systemImage: "photo.on.rectangle")
                    }

                    Button(action: openCamera) {
                        Label("Camera", systemImage: "camera")
                    }
                } label: {
                    importButtonLabel("Import", systemImage: "square.and.arrow.down")
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(importedFileName)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(cardTextColor)
                        .lineLimit(1)

                    Text("Supports plain text, markdown, rich text, PDF, and images.")
                        .font(.footnote)
                        .foregroundStyle(cardSecondaryTextColor)
                }
            }
        }
    }

    private var summarySettingsPage: some View {
        ZStack {
            backgroundView

            tabScrollContent {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Summary Settings")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(cardTextColor)

                    Text("Control how the app formats and sizes each summary.")
                        .font(.subheadline)
                        .foregroundStyle(cardSecondaryTextColor)

                    contentPanel {
                        summaryOptionsSection
                    }
                }
            }
        }
        .navigationTitle("Summary Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var importedPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Imported Preview")
                    .font(.headline)
                    .foregroundStyle(cardTextColor)

                Spacer()

                Text("\(previewLineCount) lines")
                    .font(.footnote)
                    .foregroundStyle(cardSecondaryTextColor)
            }

            ScrollView {
                Text(importedPreviewText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(cardTextColor)
                    .textSelection(.enabled)
                    .font(.callout)
            }
            .frame(maxWidth: .infinity, minHeight: 140, maxHeight: 220, alignment: .topLeading)
            .padding()
            .background(editorBackground)
        }
    }

    private var summaryOptionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Summary Options")
                .font(.headline)
                .foregroundStyle(cardTextColor)

            Picker("Format", selection: $summaryFormat) {
                ForEach(SummaryFormat.allCases) { format in
                    Text(format.title).tag(format)
                }
            }
            .pickerStyle(.segmented)

            Picker("Length", selection: $summaryDetail) {
                ForEach(SummaryDetail.allCases) { detail in
                    Text(detail.title).tag(detail)
                }
            }
            .pickerStyle(.segmented)

            if summaryFormat == .bullets {
                Stepper(value: $summaryBulletCount, in: 3...6) {
                    Text("Bullet points: \(summaryBulletCount)")
                        .foregroundStyle(cardSecondaryTextColor)
                }
            } else {
                Text("Paragraph summaries use the selected length to control how concise or detailed the result is.")
                    .font(.footnote)
                    .foregroundStyle(cardSecondaryTextColor)
            }
        }
    }
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Notes")
                    .font(.headline)
                    .foregroundStyle(cardTextColor)
                Spacer()

                Text("\(currentWordCount)/\(maximumSummaryWordCount) words")
                    .font(.footnote)
                    .foregroundStyle(wordLimitExceeded ? .red : cardSecondaryTextColor)
            }

            ZStack(alignment: .topLeading) {
                if notesText.isEmpty {
                    Text("Enter your notes here.")
                        .foregroundStyle(cardSecondaryTextColor)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 20)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $notesText)
                    .focused($isNotesEditorFocused)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .font(.body)
                    .foregroundStyle(cardTextColor)
            }
            .frame(minHeight: 220)
            .background(editorBackground)

            if wordLimitExceeded {
                Text("Reduce the note to \(maximumSummaryWordCount) words or fewer before summarising.")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    private var summariseButton: some View {
        Button(action: {
            Task {
                await summariseNotes()
            }
        }) {
            summariseButtonLabel
        }
        .disabled(isLoading || wordLimitExceeded)
        .opacity((isLoading || wordLimitExceeded) ? 0.65 : 1.0)
    }

    private var loadingSection: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text("The AI is reading your notes and building a summary.")
                .foregroundStyle(cardSecondaryTextColor)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(statusBackground)
    }

    private func errorSection(message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)

            Text(message)
                .foregroundStyle(cardTextColor)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.orange.opacity(0.10))
        )
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Summary")
                    .font(.headline)
                    .foregroundStyle(cardTextColor)

                Spacer()

                if !summaryBullets.isEmpty {
                    Text("\(summaryBullets.count) bullets")
                        .font(.footnote)
                        .foregroundStyle(cardSecondaryTextColor)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                if summaryBullets.isEmpty {
                    Text("Your AI summary will appear here.")
                        .foregroundStyle(cardSecondaryTextColor)
                } else if summaryFormat == .paragraph {
                    Text(summaryBullets.joined(separator: " "))
                        .foregroundStyle(cardTextColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineSpacing(4)
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
            .background(editorBackground)
        }
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

    private var statusBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(primaryAccent.opacity(isDarkModeActive ? 0.18 : 0.09))
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

    private func historyCard(_ item: Item) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.sourceName)
                        .font(.headline)
                        .foregroundStyle(cardTextColor)

                    Text(item.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.footnote)
                        .foregroundStyle(cardSecondaryTextColor)
                }

                Spacer()

                Button {
                    deleteHistoryItem(item)
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(cardSecondaryTextColor)
                }
                .accessibilityLabel("Delete history item")
            }

            Text(item.summaryText)
                .font(.subheadline)
                .foregroundStyle(cardSecondaryTextColor)
                .lineLimit(4)

            Button {
                useHistoryItem(item)
            } label: {
                Label("Use Again", systemImage: "arrow.clockwise")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .foregroundStyle(.white)
                    .background(importButtonBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(editorBackground)
    }

    private var appHeaderIcon: some View {
        ZStack {
            Color.clear

            Image("iconUI")
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 36)
                .offset(x: 1, y: -1)
        }
        .frame(width: 44, height: 44, alignment: .center)
        .shadow(color: Color.black.opacity(isDarkModeActive ? 0.18 : 0.10), radius: 6, x: 0, y: 3)
    }

    private func settingsSectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(cardTextColor)
    }

    private func settingsRow(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .foregroundStyle(cardTextColor)
            Text(detail)
                .font(.footnote)
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
        .modifier(HeaderGlassModifier())
    }

    private func importButtonLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .fontWeight(.semibold)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .foregroundColor(.white)
            .background(importButtonBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.35), lineWidth: 1)
            )
            .shadow(color: primaryAccent.opacity(0.18), radius: 10, x: 0, y: 6)
    }

    private var summariseButtonLabel: some View {
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
        .padding(.vertical, 14)
        .foregroundColor(.white)
        .background(actionButtonBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: primaryAccent.opacity(0.18), radius: 10, x: 0, y: 6)
    }

    private var actionButtonBackground: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)

        return shape
            .fill(
                LinearGradient(
                    colors: [primaryAccent, secondaryAccent],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .modifier(ImportButtonGlassModifier())
    }

    private var importButtonBackground: some View {
        actionButtonBackground
    }

    private var previewLineCount: Int {
        importedPreviewText.split(whereSeparator: \.isNewline).count
    }

    private var currentWordCount: Int {
        notesText.split { $0.isWhitespace || $0.isNewline }.count
    }

    private var wordLimitExceeded: Bool {
        currentWordCount > maximumSummaryWordCount
    }

    private var summaryConfiguration: SummaryConfiguration {
        SummaryConfiguration(
            format: summaryFormat,
            detail: summaryDetail,
            bulletCount: summaryBulletCount
        )
    }

    private var appVersionDescription: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "Version \(version) (\(build))"
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

            let fileText = try extractText(from: fileURL)

            notesText = fileText
            importedPreviewText = fileText
            importedFileName = fileURL.lastPathComponent
            errorMessage = nil
        } catch {
            importedFileName = "Could not import file"
            importedPreviewText = ""
            errorMessage = "The selected file could not be read as supported text content."
        }
    }

    @MainActor
    private func loadSelectedPhoto() async {
        guard let selectedPhotoItem else {
            return
        }

        defer {
            self.selectedPhotoItem = nil
        }

        do {
            guard let data = try await selectedPhotoItem.loadTransferable(type: Data.self) else {
                throw CocoaError(.fileReadUnknown)
            }

            guard
                let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
                let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
            else {
                throw CocoaError(.fileReadCorruptFile)
            }

            let extractedText = try recognizedText(from: cgImage)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !extractedText.isEmpty else {
                throw CocoaError(.fileReadInapplicableStringEncoding)
            }

            notesText = extractedText
            importedPreviewText = extractedText
            importedFileName = "Photo Library Image"
            errorMessage = nil
        } catch {
            importedFileName = "Could not import image"
            importedPreviewText = ""
            errorMessage = "The selected photo could not be read as text."
        }
    }

    private func openCamera() {
        guard hasUsageDescription(for: "NSCameraUsageDescription") else {
            errorMessage = "Camera access is not configured for this app yet."
            return
        }

        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            errorMessage = "This device does not have an available camera."
            return
        }

        showingCamera = true
    }

    private func hasUsageDescription(for key: String) -> Bool {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            return false
        }

        return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func loadCapturedImage(_ image: UIImage) {
        guard let cgImage = image.cgImage else {
            errorMessage = "The captured image could not be processed."
            return
        }

        do {
            let extractedText = try recognizedText(from: cgImage)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !extractedText.isEmpty else {
                throw CocoaError(.fileReadInapplicableStringEncoding)
            }

            notesText = extractedText
            importedPreviewText = extractedText
            importedFileName = "Camera Capture"
            errorMessage = nil
        } catch {
            importedFileName = "Could not import image"
            importedPreviewText = ""
            errorMessage = "The captured image did not contain readable text."
        }
    }

    private func extractText(from fileURL: URL) throws -> String {
        if fileURL.pathExtension.lowercased() == "pdf" {
            return try extractTextFromPDF(at: fileURL)
        }

        if let contentType = UTType(filenameExtension: fileURL.pathExtension.lowercased()),
           contentType.conforms(to: .image) {
            return try extractTextFromImage(at: fileURL)
        }

        let fileData = try Data(contentsOf: fileURL)
        return try decodeImportedText(from: fileData)
    }

    private func extractTextFromPDF(at fileURL: URL) throws -> String {
        guard let document = PDFDocument(url: fileURL) else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let extractedText = (0..<document.pageCount)
            .compactMap { document.page(at: $0)?.string }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if !extractedText.isEmpty {
            return extractedText
        }

        let ocrText = try (0..<document.pageCount)
            .compactMap { document.page(at: $0) }
            .map(recognizedText(from:))
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !ocrText.isEmpty else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }

        return ocrText
    }

    private func extractTextFromImage(at fileURL: URL) throws -> String {
        guard
            let imageSource = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
            let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let extractedText = try recognizedText(from: cgImage)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !extractedText.isEmpty else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }

        return extractedText
    }

    private func recognizedText(from page: PDFPage) throws -> String {
        let pageBounds = page.bounds(for: .mediaBox)
        let renderSize = CGSize(
            width: max(pageBounds.width * 2, 1200),
            height: max(pageBounds.height * 2, 1600)
        )
        let renderedImage = page.thumbnail(of: renderSize, for: .mediaBox)

        guard let cgImage = renderedImage.cgImage else {
            throw CocoaError(.fileReadCorruptFile)
        }

        return try recognizedText(from: cgImage)
    }

    private func recognizedText(from cgImage: CGImage) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage)
        try handler.perform([request])

        let observations = request.results ?? []
        return observations
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
    }

    private func decodeImportedText(from data: Data) throws -> String {
        if let attributedString = try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        ) {
            let plainText = attributedString.string.trimmingCharacters(in: .whitespacesAndNewlines)
            if !plainText.isEmpty {
                return plainText
            }
        }

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
                let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedText.isEmpty {
                    return trimmedText
                }
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

        guard !wordLimitExceeded else {
            errorMessage = "This note is over the \(maximumSummaryWordCount)-word limit. Shorten it before summarising."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let bullets = try await summariseOnDevice(notes: trimmedNotes)

            summaryBullets = bullets
            saveHistoryEntry(notes: trimmedNotes, bullets: bullets)
        } catch let error as SummaryError {
            errorMessage = error.message
        } catch {
            errorMessage = "Something unexpected went wrong. Please try again."
        }
    }

    private func summariseOnDevice(notes: String) async throws -> [String] {
        if #available(iOS 26.0, *) {
            return try await OnDeviceSummaryAI().summariseNotes(
                notes: notes,
                configuration: summaryConfiguration
            )
        } else {
            throw SummaryError(message: "This iPhone version does not support on-device AI summaries.")
        }
    }

    private func saveHistoryEntry(notes: String, bullets: [String]) {
        let sourceName = importedFileName == noFileSelectedName ? manualNotesSourceName : importedFileName
        let summaryText = bullets.joined(separator: "\n")
        let item = Item(sourceName: sourceName, notesText: notes, summaryText: summaryText)
        modelContext.insert(item)
    }

    private func useHistoryItem(_ item: Item) {
        notesText = item.notesText
        summaryBullets = normalisedBulletLines(from: item.summaryText)
        importedFileName = item.sourceName
        importedPreviewText = item.sourceName == manualNotesSourceName ? "" : item.notesText
        errorMessage = nil
        selectedTab = .summarise
    }

    private func deleteHistoryItem(_ item: Item) {
        modelContext.delete(item)
    }

    private func normalisedBulletLines(from text: String) -> [String] {
        text
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

private enum AppTab: Hashable {
    case summarise
    case history
    case settings
}

private enum AppAppearance: String, CaseIterable, Identifiable {
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

private enum SummaryFormat: String, CaseIterable, Identifiable {
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

private enum SummaryDetail: String, CaseIterable, Identifiable {
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
}

private struct SummaryConfiguration {
    let format: SummaryFormat
    let detail: SummaryDetail
    let bulletCount: Int
}

private struct HeaderGlassModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            content
        }
    }
}

private struct ImportButtonGlassModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else {
            content
        }
    }
}

private struct CameraPicker: UIViewControllerRepresentable {
    let onImagePicked: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked, dismiss: dismiss)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let onImagePicked: (UIImage) -> Void
        private let dismiss: DismissAction

        init(onImagePicked: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onImagePicked = onImagePicked
            self.dismiss = dismiss
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onImagePicked(image)
            }
            dismiss()
        }
    }
}

private struct OnDeviceSummaryAI {
    private let unsupportedInputMarker = "NO_SUMMARY"
    private let chunkWordLimit = 220
    private let finalBulletLimit = 6

    @available(iOS 26.0, *)
    func summariseNotes(notes: String, configuration: SummaryConfiguration) async throws -> [String] {
        let chunks = noteChunks(from: notes)

        if chunks.count == 1 {
            return try await summariseChunk(chunks[0], configuration: configuration)
        }

        let chunkConfiguration = SummaryConfiguration(
            format: .bullets,
            detail: configuration.detail,
            bulletCount: min(configuration.bulletCount, 4)
        )

        let partialSummaries = try await summariseChunks(chunks, configuration: chunkConfiguration)
        let mergedSummaryInput = partialSummaries
            .enumerated()
            .map { index, bullets in
                let body = bullets.map { "- \($0)" }.joined(separator: "\n")
                return "Section \(index + 1):\n\(body)"
            }
            .joined(separator: "\n\n")

        return try await mergeSummaries(mergedSummaryInput, configuration: configuration)
    }

    @available(iOS 26.0, *)
    private func summariseChunk(_ notes: String, configuration: SummaryConfiguration) async throws -> [String] {
        let instructions = """
        You are a text simplifier, not a chatbot.
        Your only job is to simplify and summarise note-like text into short factual bullet points.
        Only restate information already present in the text.
        Do not reply conversationally.
        Do not answer greetings, questions, or prompts as if you are chatting with the person.
        If the input is not real note content to simplify, return exactly \(unsupportedInputMarker).
        \(outputInstructions(for: configuration))
        """

        let session = LanguageModelSession(instructions: instructions)
        let response: LanguageModelSession.Response<String>
        do {
            response = try await session.respond(to: notes)
        } catch let error as LanguageModelSession.GenerationError {
            throw try await SummaryError(generationError: error)
        }

        let bullets = parsedSummaryItems(from: response.content, configuration: configuration)

        if bullets.count == 1, bullets[0].caseInsensitiveCompare(unsupportedInputMarker) == .orderedSame {
            throw SummaryError(message: "Please enter valid notes or files.")
        }

        let limit = configuration.format == .paragraph ? 1 : min(configuration.bulletCount, finalBulletLimit)
        let limitedBullets = Array(bullets[0..<min(bullets.count, limit)])
        if limitedBullets.isEmpty {
            throw SummaryError(message: "Please enter valid notes or files.")
        }
        return limitedBullets
    }

    @available(iOS 26.0, *)
    private func summariseChunks(_ chunks: [String], configuration: SummaryConfiguration) async throws -> [[String]] {
        var summaries: [[String]] = []
        summaries.reserveCapacity(chunks.count)

        for chunk in chunks {
            summaries.append(try await summariseChunk(chunk, configuration: configuration))
        }

        return summaries
    }

    @available(iOS 26.0, *)
    private func mergeSummaries(_ summaryText: String, configuration: SummaryConfiguration) async throws -> [String] {
        let instructions = """
        Merge the provided section summaries into one short final summary.
        \(outputInstructions(for: configuration))
        Remove duplicates and keep the most important points only.
        Do not add new information.
        """

        let session = LanguageModelSession(instructions: instructions)
        let response: LanguageModelSession.Response<String>
        do {
            response = try await session.respond(to: summaryText)
        } catch let error as LanguageModelSession.GenerationError {
            throw try await SummaryError(generationError: error)
        }

        let bullets = parsedSummaryItems(from: response.content, configuration: configuration)

        let limit = configuration.format == .paragraph ? 1 : min(configuration.bulletCount, finalBulletLimit)
        let limitedBullets = Array(bullets[0..<min(bullets.count, limit)])
        if limitedBullets.isEmpty {
            throw SummaryError(message: "The model could not produce a merged summary.")
        }

        return limitedBullets
    }

    private func noteChunks(from notes: String) -> [String] {
        let lines = notes
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else {
            return [notes]
        }

        var chunks: [String] = []
        var currentLines: [String] = []
        var currentWordCount = 0

        for line in lines {
            let lineWordCount = line.split(whereSeparator: \.isWhitespace).count

            if !currentLines.isEmpty, currentWordCount + lineWordCount > chunkWordLimit {
                chunks.append(currentLines.joined(separator: "\n"))
                currentLines.removeAll(keepingCapacity: true)
                currentWordCount = 0
            }

            currentLines.append(line)
            currentWordCount += lineWordCount
        }

        if !currentLines.isEmpty {
            chunks.append(currentLines.joined(separator: "\n"))
        }

        return chunks.isEmpty ? [notes] : chunks
    }

    private func outputInstructions(for configuration: SummaryConfiguration) -> String {
        switch configuration.format {
        case .bullets:
            return "Return only \(configuration.bulletCount) concise bullet points. Make them \(configuration.detail.promptFragment)."
        case .paragraph:
            return "Return one clean paragraph only. Make it \(configuration.detail.promptFragment). Do not use bullets, hashtags, or headings."
        }
    }

    private func parsedSummaryItems(from text: String, configuration: SummaryConfiguration) -> [String] {
        switch configuration.format {
        case .bullets:
            return text
                .split(whereSeparator: \.isNewline)
                .map(Self.cleanedBulletLine)
                .filter { !$0.isEmpty }
        case .paragraph:
            let cleanedParagraph = Self.cleanedParagraph(text)
            return cleanedParagraph.isEmpty ? [] : [cleanedParagraph]
        }
    }

    nonisolated private static func cleanedBulletLine(_ line: Substring) -> String {
        let cleaned = String(line)
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
            .replacingOccurrences(of: "##", with: "")
            .replacingOccurrences(of: "###", with: "")
            .replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
            .replacingOccurrences(of: "{", with: "")
            .replacingOccurrences(of: "}", with: "")
            .replacingOccurrences(of: "|", with: "")
            .replacingOccurrences(of: "•", with: "")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "  ", with: " ")

        return normalizedText(cleaned)
    }

    nonisolated private static func cleanedParagraph(_ text: String) -> String {
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
            .replacingOccurrences(of: "  ", with: " ")

        return normalizedText(cleaned)
    }

    nonisolated private static func normalizedText(_ text: String) -> String {
        text
            .trimmingCharacters(in: CharacterSet(charactersIn: " -•*_#[]{}|"))
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct SummaryError: Error {
    let message: String
}

@available(iOS 26.0, *)
extension SummaryError {
    init(generationError: LanguageModelSession.GenerationError) async throws {
        switch generationError {
        case .unsupportedLanguageOrLocale:
            self.init(message: "This language is not supported by the on-device model.")
        case .exceededContextWindowSize:
            self.init(message: "These notes are too long for one on-device summary. Try a shorter note or split it into parts.")
        case .decodingFailure:
            self.init(message: "The model returned an invalid summary format. Try again with shorter or cleaner notes.")
        case .guardrailViolation:
            self.init(message: "The notes triggered a safety restriction, so the model could not summarise them.")
        case .assetsUnavailable:
            self.init(message: "The on-device AI model is not ready yet. Try again in a moment.")
        case .rateLimited:
            self.init(message: "The model is busy right now. Wait a moment and try again.")
        case .concurrentRequests:
            self.init(message: "A summary is already in progress. Please wait for it to finish.")
        case .refusal:
            self.init(message: "The model refused to summarise this content.")
        default:
            self.init(message: "The on-device model could not create a summary right now.")
        }
    }
}
