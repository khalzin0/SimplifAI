import Combine
import SwiftUI
import UniformTypeIdentifiers
import PDFKit
import PhotosUI
import StoreKit
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
    private let appDescription = "Import a file or paste your notes, review the text, then turn it into a cleaner summary."
    @AppStorage("appAppearance") private var appAppearanceRawValue = AppAppearance.dark.rawValue
    @AppStorage("preferLargeText") private var preferLargeText = false
    @AppStorage("reduceVisualEffects") private var reduceVisualEffects = false
    @AppStorage("defaultTemplate") private var defaultTemplateRawValue = SummaryTemplate.simpleSummary.rawValue
    @AppStorage("autoCopySummary") private var autoCopySummary = false
    @AppStorage("confirmBeforeClear") private var confirmBeforeClear = true
    @AppStorage("historyTitleStyle") private var historyTitleStyleRawValue = HistoryTitleStyle.aiShortened.rawValue
    @AppStorage("studyFlashcardCount") private var studyFlashcardCount = 4
    @AppStorage("studyQuizQuestionCount") private var studyQuizQuestionCount = 4
    @AppStorage("studyUsesSmartCounts") private var studyUsesSmartCounts = true
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Query(sort: \Item.timestamp, order: .reverse) private var historyItems: [Item]
    @State private var selectedTab: AppTab = .summarise
    @State private var notesText: String = ""
    @State private var historySearchText: String = ""
    @State private var summaryBullets: [String] = []
    @State private var studyFlashcards: [StudyFlashcard] = []
    @State private var studyQuizQuestions: [QuizQuestion] = []
    @State private var selectedStudyMode: StudyMode = .flashcards
    @State private var revealedFlashcardIndices: Set<Int> = []
    @State private var activeFlashcardIndex = 0
    @State private var summaryFormat: SummaryFormat = .bullets
    @State private var summaryDetail: SummaryDetail = .standard
    @State private var summaryBulletCount = 4
    @State private var selectedTemplate: SummaryTemplate = .simpleSummary
    @State private var showingFileImporter = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showingPhotoPicker = false
    @State private var showingCamera = false
    @State private var importedFileName = "No file selected"
    @State private var importedFilePreviewURL: URL?
    @State private var importedFileData: Data?
    @State private var importedFileExtension: String?
    @State private var importedPreviewText = ""
    @State private var isLoading = false
    @State private var isGeneratingStudyPack = false
    @State private var errorMessage: String?
    @State private var animateBackground = false
    @State private var pendingDestructiveAction: DestructiveAction?
    @State private var didCopySummary = false
    @State private var importNotice: String?
    @State private var hasAppliedInitialPreferences = false
    @State private var showingSummaryPage = false
    @State private var showingSummaryLoading = false
    @State private var showingSubscriptionPaywall = false
    @State private var paywallFeatureName = "SimplifAI Pro"
    @FocusState private var isNotesEditorFocused: Bool
    
    private let primaryAccent = Color(red: 0.08, green: 0.36, blue: 0.67)
    private let secondaryAccent = Color(red: 0.17, green: 0.63, blue: 0.77)
    private let studyCountRange = 2...12
    private let editorPanelMinHeight: CGFloat = 220
    private let editorPanelMaxHeight: CGFloat = 360
    private let embeddedWorkerURL = "https://simplifai-proxy.simplifai.workers.dev"
    private let embeddedOpenRouterModel = "google/gemma-3n-e4b-it"
    private var isSmallPhoneLayout: Bool {
        guard UIDevice.current.userInterfaceIdiom == .phone else {
            return false
        }

        let screenBounds = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.screen.bounds }
            .first ?? CGRect(x: 0, y: 0, width: 390, height: 844)

        return min(screenBounds.width, screenBounds.height) <= 375
    }

    private var heroTitleSize: CGFloat {
        isSmallPhoneLayout ? 27 : 34
    }

    private var sectionHeroTitleSize: CGFloat {
        isSmallPhoneLayout ? 24 : 30
    }

    private var paywallTitleSize: CGFloat {
        isSmallPhoneLayout ? 26 : 32
    }

    private var supportedDynamicTypeRange: ClosedRange<DynamicTypeSize> {
        return .xSmall ... (isSmallPhoneLayout ? .xLarge : .xxxLarge)
    }

    private var preferredDynamicTypeSize: DynamicTypeSize {
        isSmallPhoneLayout ? .xLarge : .xxLarge
    }

    private var selectedAppearance: AppAppearance {
        AppAppearance(rawValue: appAppearanceRawValue) ?? .dark
    }
    
    private var preferredColorScheme: ColorScheme? {
        selectedAppearance.colorScheme
    }

    private var defaultTemplate: SummaryTemplate {
        SummaryTemplate(rawValue: defaultTemplateRawValue) ?? .simpleSummary
    }

    private var selectedHistoryTitleStyle: HistoryTitleStyle {
        HistoryTitleStyle(rawValue: historyTitleStyleRawValue) ?? .aiShortened
    }

    private var filteredHistoryItems: [Item] {
        let query = historySearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return historyItems
        }

        return historyItems.filter { item in
            [item.title, item.sourceName, item.notesText, item.summaryText]
                .joined(separator: "\n")
                .localizedCaseInsensitiveContains(query)
        }
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

    private var houseGradientTint: LinearGradient {
        LinearGradient(
            colors: [primaryAccent, secondaryAccent],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                ZStack {
                    backgroundView

                    tabScrollContent {
                        headerSection
                        contentPanel(spacing: 16) {
                            importSection
                        }
                        contentPanel(spacing: 16) {
                            notesSection
                        }
                        if isLoading || importNotice != nil || errorMessage != nil {
                            contentPanel(spacing: 16) {
                                if isLoading {
                                    loadingSection
                                }
                                if let importNotice {
                                    noticeSection(message: importNotice)
                                }
                                if let errorMessage {
                                    errorSection(message: errorMessage)
                                }
                            }
                        }
                        contentPanel(spacing: 16) {
                            summarySection
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isNotesEditorFocused = false
                    }

                    if showingSummaryLoading {
                        summaryLoadingScreen
                            .transition(.opacity)
                            .zIndex(10)
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(isPresented: $showingSummaryPage) {
                    SummaryResultScreen(
                        summaryBullets: summaryBullets,
                        summaryFormat: summaryFormat,
                        summaryWordCount: summaryWordCount,
                        didCopySummary: didCopySummary,
                        onCopySummary: copySummaryToClipboard,
                        onOpenStudyMode: {
                            selectedTab = .study
                        }
                    )
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if isNotesEditorFocused {
                        HStack {
                            Spacer()

                            Button("Done") {
                                isNotesEditorFocused = false
                            }
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .modifier(
                                FloatingDoneButtonModifier(
                                    primaryAccent: primaryAccent,
                                    secondaryAccent: secondaryAccent,
                                    isDarkModeActive: isDarkModeActive
                                )
                            )
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 8)
                        .background(Color.clear)
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
                            studyPageIntro

                            if summaryBullets.isEmpty {
                                contentPanel {
                                    guideCard(
                                        title: "No Study Set Yet",
                                        text: "Create a summary first, then come back here to review flashcards and quiz yourself."
                                    )

                                    Button {
                                        selectedTab = .summarise
                                    } label: {
                                        Label("Go To Summarise", systemImage: "sparkles")
                                            .fontWeight(.semibold)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 14)
                                            .foregroundStyle(.white)
                                            .background(importButtonBackground)
                                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    }
                                }
                            } else {
                                contentPanel {
                                    if hasStudyPack {
                                        studyPackSection
                                    } else {
                                        generateStudySetSection
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .tabItem {
                Label("Study", systemImage: "book.closed")
            }
            .tag(AppTab.study)

            NavigationStack {
                ZStack {
                    backgroundView

                    tabScrollContent {
                        VStack(alignment: .leading, spacing: 18) {
                            pageIntro(
                                title: "History",
                                subtitle: "Reopen previous summaries and continue from them."
                            )

                            contentPanel(spacing: 16) {
                                if !historyItems.isEmpty {
                                    searchField(
                                        text: $historySearchText,
                                        placeholder: "Search history"
                                    )

                                    HStack {
                                        secondaryActionButton(
                                            title: "Clear All",
                                            systemImage: "trash",
                                            accessibilityLabel: "Clear all history"
                                        ) {
                                            requestDestructiveAction(.clearHistory)
                                        }

                                        Spacer()
                                    }
                                }

                                if historyItems.isEmpty {
                                    guideCard(
                                        title: "No History Yet",
                                        text: "Create a summary in the Summarise tab and it will appear here."
                                    )
                                } else if filteredHistoryItems.isEmpty {
                                    guideCard(
                                        title: "No Matches",
                                        text: "Try a different search term or clear the search to see all saved summaries."
                                    )
                                } else {
                                    ForEach(filteredHistoryItems) { item in
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
                            pageIntro(
                                title: "Templates",
                                subtitle: "Choose a simpler preset without scrolling through a long wall of cards."
                            )

                            contentPanel(spacing: 14) {
                                settingsSectionTitle("Quick Picks")
                                templatePickerRow(.simpleSummary)
                                templatePickerRow(.studyNotes)
                                templatePickerRow(.plainEnglish)
                            }

                            contentPanel(spacing: 14) {
                                settingsSectionTitle("General")
                                ForEach(generalTemplates) { template in
                                    templatePickerRow(template)
                                }
                            }

                            contentPanel(spacing: 14) {
                                settingsSectionTitle("Student")
                                Text("Student presets work best with the Study tab after you generate a summary.")
                                    .font(.footnote)
                                    .foregroundStyle(cardSecondaryTextColor)

                                ForEach(studentTemplates) { template in
                                    templatePickerRow(template)
                                }
                            }
                        }
                    }
                }
            }
            .tabItem {
                Label("Templates", systemImage: "square.grid.2x2")
            }
            .tag(AppTab.templates)

            NavigationStack {
                ZStack {
                    backgroundView

                    tabScrollContent {
                        VStack(alignment: .leading, spacing: 18) {
                            pageIntro(
                                title: "Settings",
                                subtitle: "Choose the app appearance and accessibility preferences."
                            )

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
                                .tint(houseGradientTint)

                                Toggle(isOn: $reduceVisualEffects) {
                                    settingsRow(
                                        title: "Reduce Visual Effects",
                                        detail: "Uses a calmer background with less visual layering."
                                    )
                                }
                                .tint(houseGradientTint)

                                Spacer()
                                    .frame(height: 8)

                                settingsSectionTitle("Summary Defaults")

                                settingsMenuSelector(
                                    title: "Default Template",
                                    value: defaultTemplate.title
                                ) {
                                    ForEach(SummaryTemplate.allCases) { template in
                                        Button(template.title) {
                                            defaultTemplateRawValue = template.rawValue
                                            selectedTemplate = template
                                            applyTemplate(template, switchToSummarise: false)
                                        }
                                    }
                                }

                                Toggle(isOn: $autoCopySummary) {
                                    settingsRow(
                                        title: "Auto-Copy Summary",
                                        detail: "Copies each successful summary to the clipboard automatically."
                                    )
                                }
                                .tint(houseGradientTint)

                                Toggle(isOn: $confirmBeforeClear) {
                                    settingsRow(
                                        title: "Confirm Before Clearing",
                                        detail: "Shows a confirmation prompt before clearing notes, imports, or history."
                                    )
                                }
                                .tint(houseGradientTint)

                                settingsMenuSelector(
                                    title: "History Title Style",
                                    value: selectedHistoryTitleStyle.title
                                ) {
                                    ForEach(HistoryTitleStyle.allCases) { style in
                                        Button(style.title) {
                                            historyTitleStyleRawValue = style.rawValue
                                        }
                                    }
                                }

                                Spacer()
                                    .frame(height: 8)

                                settingsSectionTitle("Subscription")

                                settingsRow(
                                    title: "SimplifAI Pro",
                                    detail: subscriptionManager.hasActiveSubscription ? "Active subscription" : "Unlock AI summaries and study mode."
                                )

                                Button {
                                    presentPaywall(for: "SimplifAI Pro")
                                } label: {
                                    Text(subscriptionManager.hasActiveSubscription ? "Manage Subscription" : "View Plans")
                                        .fontWeight(.semibold)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .foregroundStyle(.white)
                                        .background(importButtonBackground)
                                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }

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
        .onAppear {
            animateBackground = true
            applyInitialPreferencesIfNeeded()
        }
        .task(id: selectedPhotoItem) {
            await loadSelectedPhoto()
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPicker { image in
                loadCapturedImage(image)
            }
        }
        .alert("Are you sure?", isPresented: destructiveActionBinding) {
            Button("Cancel", role: .cancel) {
                pendingDestructiveAction = nil
            }
            Button(destructiveActionButtonTitle, role: .destructive) {
                performPendingDestructiveAction()
            }
        } message: {
            Text(destructiveActionMessage)
        }
        .sheet(isPresented: $showingSubscriptionPaywall) {
            SubscriptionPaywallScreen(featureName: paywallFeatureName)
                .environmentObject(subscriptionManager)
        }
        .preferredColorScheme(preferredColorScheme)
        .modifier(
            PreferredDynamicTypeModifier(
                preferLargeText: preferLargeText,
                preferredSize: preferredDynamicTypeSize,
                normalRange: supportedDynamicTypeRange
            )
        )
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
                    .scaleEffect(animateBackground ? 1.08 : 0.94)
                    .offset(
                        x: animateBackground ? 190 : 150,
                        y: animateBackground ? -250 : -220
                    )
                    .animation(
                        .easeInOut(duration: 9).repeatForever(autoreverses: true),
                        value: animateBackground
                    )

                Circle()
                    .fill(primaryAccent.opacity(isDarkModeActive ? 0.14 : 0.18))
                    .frame(width: 280, height: 280)
                    .blur(radius: 44)
                    .scaleEffect(animateBackground ? 0.96 : 1.10)
                    .offset(
                        x: animateBackground ? -170 : -130,
                        y: animateBackground ? 260 : 220
                    )
                    .animation(
                        .easeInOut(duration: 11).repeatForever(autoreverses: true),
                        value: animateBackground
                    )

                RoundedRectangle(cornerRadius: 80, style: .continuous)
                    .fill((isDarkModeActive ? Color.white : Color.white).opacity(isDarkModeActive ? 0.12 : 0.38))
                    .frame(width: 260, height: 260)
                    .blur(radius: 34)
                    .rotationEffect(.degrees(animateBackground ? 18 : 4))
                    .offset(
                        x: animateBackground ? -120 : -80,
                        y: animateBackground ? -140 : -170
                    )
                    .animation(
                        .easeInOut(duration: 13).repeatForever(autoreverses: true),
                        value: animateBackground
                    )
            }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                appHeaderIcon

                VStack(alignment: .leading, spacing: 4) {
                    Text("SimplifAI")
                        .font(.system(size: heroTitleSize, weight: .bold, design: .rounded))
                        .foregroundStyle(cardTextColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)

                    Text(appDescription)
                        .font(.subheadline)
                        .foregroundStyle(cardSecondaryTextColor)
                        .lineSpacing(1)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(alignment: .bottom, spacing: 10) {
                headerInfoCard(
                    title: "Supported Files",
                    value: ".txt .md .rtf .pdf"
                )

                headerInfoCard(
                    title: "Limit",
                    value: "\(maximumSummaryWordCount) words"
                )
            }
        }
        .padding(.horizontal, 2)
        .padding(.top, 0)
    }

    private var importSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Import")
                        .font(.headline)
                        .foregroundStyle(cardTextColor)
                }

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

            Menu {
                Button {
                    showingFileImporter = true
                } label: {
                    Label("Choose File", systemImage: "doc.badge.plus")
                }

                Button {
                    showingPhotoPicker = true
                } label: {
                    Label("Photo Library", systemImage: "photo.on.rectangle")
                }

                Button {
                    openCamera()
                } label: {
                    Label("Camera", systemImage: "camera")
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "square.and.arrow.down.on.square")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Import Source")
                            .font(.headline)
                        Text("File, photo, or camera")
                            .font(.footnote)
                            .opacity(0.84)
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.footnote.weight(.bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(importButtonBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            Text(hasImportedFile ? importedFileName : "No file selected")
                .font(.footnote)
                .foregroundStyle(cardSecondaryTextColor)
                .lineLimit(1)

            if hasImportedFile {
                secondaryActionButton(
                    title: "Remove File",
                    systemImage: "xmark.circle",
                    accessibilityLabel: "Remove imported file"
                ) {
                    requestDestructiveAction(.removeImportedFile)
                }
            }
        }
    }

    private var summarySettingsPage: some View {
        SummarySettingsScreen(
            summaryFormat: $summaryFormat,
            summaryDetail: $summaryDetail,
            summaryBulletCount: $summaryBulletCount,
            selectedTab: $selectedTab
        )
    }

    private func templateCard(_ template: SummaryTemplate) -> some View {
        let isSelected = selectedTemplate == template

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.title)
                        .font(.headline)
                        .foregroundStyle(cardTextColor)

                    Text(template.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(cardSecondaryTextColor)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(primaryAccent)
                }
            }

            HStack(spacing: 10) {
                templateBadge(template.format.title)
                templateBadge(template.detail.title)
                templateBadge("\(template.bulletCount) bullets")
            }

            Button {
                applyTemplate(template)
            } label: {
                Text(isSelected ? "Applied" : "Use Template")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(.white)
                    .background(importButtonBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(isSelected)
            .opacity(isSelected ? 0.8 : 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(editorBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(primaryAccent.opacity(isSelected ? 0.28 : 0.10), lineWidth: 1)
        )
    }

    private func templateBadge(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(cardSecondaryTextColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(primaryAccent.opacity(isDarkModeActive ? 0.14 : 0.08))
            )
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

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if importedPreviewText.isEmpty && !notesText.isEmpty {
                HStack {
                    secondaryActionButton(title: "Clear All", systemImage: "xmark.circle") {
                        requestDestructiveAction(.clearNotes)
                    }

                    Spacer()
                }
            }

            sectionHeader(
                title: importedFilePreviewURL != nil ? "Imported File" : (importedPreviewText.isEmpty ? "Notes" : "Preview"),
                detail: importedFilePreviewURL != nil
                    ? "\(currentWordCount) extracted words"
                    : (importedPreviewText.isEmpty ? "\(currentWordCount)/\(maximumSummaryWordCount) words" : "\(previewWordCount) words"),
                detailColor: importedFilePreviewURL == nil && importedPreviewText.isEmpty && wordLimitExceeded ? .red : cardSecondaryTextColor
            )

            Group {
                if let importedFilePreviewURL {
                    ScrollView {
                        importedFileCard(for: importedFilePreviewURL, allowsEditing: true)
                            .padding(16)
                    }
                } else if importedPreviewText.isEmpty {
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
                } else {
                    ScrollView {
                        Text(importedPreviewText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundStyle(cardTextColor)
                            .textSelection(.enabled)
                            .font(.callout)
                            .padding(16)
                    }
                }
            }
            .frame(
                minHeight: importedFilePreviewURL != nil ? 460 : editorPanelMinHeight,
                maxHeight: importedFilePreviewURL != nil ? 560 : editorPanelMaxHeight,
                alignment: .top
            )
            .background(editorBackground)

            if wordLimitExceeded {
                Text("Reduce the note to \(maximumSummaryWordCount) words or fewer before summarising.")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            summariseButton
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

    private func importedFileCard(for url: URL, allowsEditing: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(primaryAccent.opacity(isDarkModeActive ? 0.20 : 0.10))
                    .frame(width: 54, height: 54)
                    .overlay {
                        Image(systemName: quickLookSystemImage(for: url))
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(primaryAccent)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(importedFileName)
                        .font(.headline)
                        .foregroundStyle(cardTextColor)
                        .lineLimit(2)

                    Text(importedFileMetadata)
                        .font(.footnote)
                        .foregroundStyle(cardSecondaryTextColor)

                    Text("The file stays previewable here, while the extracted text is used for summarising.")
                        .font(.footnote)
                        .foregroundStyle(cardSecondaryTextColor)
                }

                Spacer(minLength: 0)
            }

            importedFilePreviewContent(
                for: url,
                text: importedPreviewText,
                editableText: allowsEditing ? $notesText : nil
            )

            Text("\(currentWordCount) extracted words ready")
                .font(.footnote)
                .foregroundStyle(cardSecondaryTextColor)
            }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.clear)
    }

    private func quickLookSystemImage(for url: URL) -> String {
        if let contentType = UTType(filenameExtension: url.pathExtension.lowercased()) {
            if contentType.conforms(to: .pdf) {
                return "doc.richtext"
            }

            if contentType.conforms(to: .image) {
                return "photo"
            }

            if contentType.conforms(to: .text) {
                return "doc.text"
            }
        }

        return "doc"
    }

    private func presentPaywall(for featureName: String) {
        paywallFeatureName = featureName
        showingSubscriptionPaywall = true
    }

    private func guardPremiumAccess(for featureName: String, action: () -> Void) {
        if subscriptionManager.hasActiveSubscription {
            action()
        } else {
            presentPaywall(for: featureName)
        }
    }

    private func importedFilePreviewContent(
        for url: URL,
        text: String,
        editableText: Binding<String>? = nil
    ) -> some View {
        Group {
            if shouldUseAppTextPreview(for: url) {
                if let editableText {
                    TextEditor(text: editableText)
                        .focused($isNotesEditorFocused)
                        .scrollContentBackground(.hidden)
                        .padding(12)
                        .font(.body)
                        .foregroundStyle(cardTextColor)
                        .background(editorBackground)
                } else {
                    ScrollView {
                        Text(text)
                            .font(.body)
                            .foregroundStyle(cardTextColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .padding(16)
                    }
                    .background(editorBackground)
                }
            } else {
                ImportedFileQuickLookPreview(url: url)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(isDarkModeActive ? Color.black.opacity(0.16) : Color.white.opacity(0.88))
                    )
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 320)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(primaryAccent.opacity(isDarkModeActive ? 0.22 : 0.12), lineWidth: 1)
        )
    }

    private func shouldUseAppTextPreview(for url: URL) -> Bool {
        if let contentType = UTType(filenameExtension: url.pathExtension.lowercased()) {
            return contentType.conforms(to: .text) || contentType.conforms(to: .rtf)
        }

        return ["txt", "rtf", "md"].contains(url.pathExtension.lowercased())
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

    private func noticeSection(message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(primaryAccent)

            Text(message)
                .foregroundStyle(cardTextColor)
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
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Summary")
                        .font(.headline)
                        .foregroundStyle(cardTextColor)
                }

                Spacer()

                Text("\(summaryWordCount) words")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(cardSecondaryTextColor)
            }

            if summaryBullets.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your summary will open on a dedicated page after the AI finishes.")
                        .foregroundStyle(cardSecondaryTextColor)

                    Text("Tap Summarise to begin.")
                        .font(.footnote)
                        .foregroundStyle(cardSecondaryTextColor)
                }
                .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
                .padding()
                .background(editorBackground)
            } else {
                Button {
                    showingSummaryPage = true
                } label: {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Latest Summary Ready")
                                    .font(.headline)
                                    .foregroundStyle(cardTextColor)

                                Text(summaryPreviewText)
                                    .font(.subheadline)
                                    .foregroundStyle(cardSecondaryTextColor)
                                    .lineLimit(3)
                            }

                            Spacer()

                            Image(systemName: "chevron.right.circle.fill")
                                .font(.title3)
                                .foregroundStyle(primaryAccent)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
                    .padding()
                    .background(editorBackground)
                }
                .buttonStyle(.plain)
            }

            if !summaryBullets.isEmpty {
                HStack(spacing: 12) {
                    Button {
                        showingSummaryPage = true
                    } label: {
                        Label("View Summary", systemImage: "doc.text")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(cardTextColor)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(primaryAccent.opacity(isDarkModeActive ? 0.12 : 0.08))
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        selectedTab = .study
                    } label: {
                        Label("Open Study Mode", systemImage: "book.closed")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(actionButtonBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("AI can make mistakes. Check important details.")
                .font(.footnote)
                .foregroundStyle(cardSecondaryTextColor)
        }
    }

    private var generalTemplates: [SummaryTemplate] {
        [.meetingNotes, .actionItems, .leaseContract]
    }

    private var studentTemplates: [SummaryTemplate] {
        [.examPrep, .flashcards, .keyTerms]
    }

    private var heroPanelBackground: some View {
        Color.clear
    }

    private func quickImportButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(importButtonBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(cardTextColor)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(editorBackground)
        }
        .buttonStyle(.plain)
    }

    private var hasStudyPack: Bool {
        !studyFlashcards.isEmpty || !studyQuizQuestions.isEmpty
    }

    private var studyPageIntro: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Study Mode")
                    .font(.system(size: heroTitleSize, weight: .bold, design: .rounded))
                    .foregroundStyle(cardTextColor)

                Text("Review your latest summary using flashcards and quiz questions.")
                    .font(.subheadline)
                    .foregroundStyle(cardSecondaryTextColor)
            }

            Spacer()

            NavigationLink {
                StudySettingsScreen(
                    studyUsesSmartCounts: $studyUsesSmartCounts,
                    studyFlashcardCount: $studyFlashcardCount,
                    studyQuizQuestionCount: $studyQuizQuestionCount,
                    notesText: notesText,
                    summaryBullets: summaryBullets
                )
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
            .accessibilityLabel("Study settings")
        }
    }

    private var generateStudySetSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            guideCard(
                title: "Generate Study Set",
                text: studyGenerationDescription(notes: notesText, bullets: summaryBullets)
            )

            studyCountsSummaryCard(notes: notesText, bullets: summaryBullets)

            Button {
                Task {
                    await generateStudyPackIfPossible()
                }
            } label: {
                HStack {
                    if isGeneratingStudyPack {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "book.pages")
                    }

                    Text(isGeneratingStudyPack ? "Generating Study Set..." : "Generate Study Set")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(.white)
                .background(importButtonBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .disabled(isGeneratingStudyPack)
            .opacity(isGeneratingStudyPack ? 0.7 : 1)
        }
    }

    private var studyPackSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Study Mode", detail: "\(studyFlashcards.count + studyQuizQuestions.count) items")

            if selectedTemplate.isStudentFocused {
                guideCard(
                    title: "Student Mode",
                    text: selectedTemplate.studentValueMessage
                )
            }

            Picker("Study Mode", selection: $selectedStudyMode) {
                Text("Flashcards").tag(StudyMode.flashcards)
                Text("Quiz").tag(StudyMode.quiz)
            }
            .pickerStyle(.segmented)

            studyCountsSummaryCard(notes: notesText, bullets: summaryBullets)

            secondaryActionButton(
                title: isGeneratingStudyPack ? "Generating..." : "Regenerate",
                systemImage: "arrow.triangle.2.circlepath",
                accessibilityLabel: "Regenerate study set"
            ) {
                Task {
                    await generateStudyPackIfPossible()
                }
            }

            if selectedStudyMode == .flashcards {
                NavigationLink {
                    FlashcardsScreen(
                        studyFlashcards: studyFlashcards,
                        activeFlashcardIndex: $activeFlashcardIndex,
                        revealedFlashcardIndices: $revealedFlashcardIndices
                    )
                } label: {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Flashcards")
                                    .font(.headline)
                                    .foregroundStyle(cardTextColor)

                                Text("Open a dedicated card view with flip animation and next/previous controls.")
                                    .font(.subheadline)
                                    .foregroundStyle(cardSecondaryTextColor)
                            }

                            Spacer()

                            Image(systemName: "chevron.right.circle.fill")
                                .font(.title3)
                                .foregroundStyle(primaryAccent)
                        }

                        HStack(spacing: 10) {
                            headerBadge(title: "Cards", value: "\(studyFlashcards.count)")

                            if let firstCard = studyFlashcards.first {
                                templateBadge(firstCard.kind.title)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(editorBackground)
                }
                .buttonStyle(.plain)
            } else {
                NavigationLink {
                    QuizScreen(studyQuizQuestions: studyQuizQuestions)
                } label: {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Quiz")
                                    .font(.headline)
                                    .foregroundStyle(cardTextColor)

                                Text("Open a dedicated quiz session with scoring and a final results screen.")
                                    .font(.subheadline)
                                    .foregroundStyle(cardSecondaryTextColor)
                            }

                            Spacer()

                            Image(systemName: "chevron.right.circle.fill")
                                .font(.title3)
                                .foregroundStyle(primaryAccent)
                        }

                        HStack(spacing: 10) {
                            headerBadge(title: "Questions", value: "\(studyQuizQuestions.count)")

                            if let firstQuestion = studyQuizQuestions.first {
                                templateBadge(firstQuestion.style.title)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(editorBackground)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func templatePickerRow(_ template: SummaryTemplate) -> some View {
        let isSelected = selectedTemplate == template

        return Button {
            applyTemplate(template)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(template.title)
                            .font(.headline)
                            .foregroundStyle(cardTextColor)

                        if template.isStudentFocused {
                            templateBadge("Study")
                        }
                    }

                    Text(template.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(cardSecondaryTextColor)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "chevron.right.circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? primaryAccent : cardSecondaryTextColor)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(editorBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(primaryAccent.opacity(isSelected ? 0.26 : 0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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
                        .background(importButtonBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(value <= range.lowerBound)
                .opacity(value <= range.lowerBound ? 0.55 : 1)

                Button(action: onIncrement) {
                    Image(systemName: "plus")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(importButtonBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(value >= range.upperBound)
                .opacity(value >= range.upperBound ? 0.55 : 1)
            }
        }
        .padding(.vertical, 4)
    }

    private func studyCountsSummaryCard(notes: String, bullets: [String]) -> some View {
        let counts = effectiveStudyCounts(for: notes, bullets: bullets)

        return VStack(alignment: .leading, spacing: 10) {
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
        .padding(18)
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
            NavigationLink {
                historyDetailView(for: item)
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.headline)
                            .foregroundStyle(cardTextColor)

                        Text(item.sourceName)
                            .font(.subheadline)
                            .foregroundStyle(cardSecondaryTextColor)

                        Text(item.timestamp.formatted(date: .abbreviated, time: .shortened))
                            .font(.footnote)
                            .foregroundStyle(cardSecondaryTextColor)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(cardSecondaryTextColor)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text(historyPreviewText(for: item))
                .font(.subheadline)
                .foregroundStyle(cardSecondaryTextColor)
                .lineLimit(4)

            HStack(spacing: 10) {
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

                Spacer()

                secondaryActionButton(
                    title: "Delete",
                    systemImage: "trash",
                    accessibilityLabel: "Delete history item"
                ) {
                    deleteHistoryItem(item)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(editorBackground)
    }

    private func historyDetailView(for item: Item) -> some View {
        let storedStudyPack = decodedStudyPack(from: item.studyPackData)

        return ZStack {
            backgroundView

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    contentPanel {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(item.title)
                                .font(.system(size: sectionHeroTitleSize, weight: .bold, design: .rounded))
                                .foregroundStyle(cardTextColor)

                            Text(item.sourceName)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(cardSecondaryTextColor)

                            Text(item.timestamp.formatted(date: .complete, time: .shortened))
                                .font(.subheadline)
                                .foregroundStyle(cardSecondaryTextColor)
                        }

                        if item.importedFileData != nil {
                            historyImportedFileSection(for: item)
                        } else {
                            historyDetailSection(
                                title: "Original Notes",
                                detail: "\(wordCount(for: item.notesText)) words",
                                text: item.notesText
                            )
                        }

                        historyDetailSection(
                            title: "Summary",
                            detail: "\(wordCount(for: item.summaryText)) words",
                            text: formattedHistorySummaryText(for: item)
                        )

                        if let storedStudyPack,
                           !storedStudyPack.flashcards.isEmpty || !storedStudyPack.quizQuestions.isEmpty {
                            historyStudyPackSection(studyPack: storedStudyPack)
                        }

                        Button {
                            useHistoryItem(item)
                        } label: {
                            Label("Use This Summary", systemImage: "arrow.clockwise")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 14)
                                .foregroundStyle(.white)
                                .background(importButtonBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }
                }
                .frame(maxWidth: contentWidth)
                .padding(.horizontal, horizontalScreenPadding)
                .padding(.vertical, verticalScreenPadding)
            }
        }
        .navigationTitle("History Detail")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func historyStudyPackSection(studyPack: StudyPack) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                title: "Saved Study Mode",
                detail: "\(studyPack.flashcards.count) cards • \(studyPack.quizQuestions.count) quiz questions"
            )

            if let firstCard = studyPack.flashcards.first {
                Text("Flashcard preview")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(primaryAccent)

                Text(firstCard.prompt)
                    .foregroundStyle(cardTextColor)

                Text(firstCard.answer)
                    .foregroundStyle(cardSecondaryTextColor)
            }

            if let firstQuestion = studyPack.quizQuestions.first {
                Divider()

                Text("Quiz preview")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(primaryAccent)

                Text(firstQuestion.prompt)
                    .foregroundStyle(cardTextColor)

                Text(firstQuestion.options[safe: firstQuestion.correctAnswerIndex] ?? firstQuestion.options.first ?? "")
                    .foregroundStyle(cardSecondaryTextColor)
            }
        }
        .padding(16)
        .background(editorBackground)
    }

    private func historyImportedFileSection(for item: Item) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                title: "Imported File",
                detail: "\(wordCount(for: item.notesText)) extracted words"
            )

            if let previewURL = historyImportedFilePreviewURL(for: item) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 14) {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(primaryAccent.opacity(isDarkModeActive ? 0.20 : 0.10))
                            .frame(width: 54, height: 54)
                            .overlay {
                                Image(systemName: quickLookSystemImage(for: previewURL))
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(primaryAccent)
                            }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.sourceName)
                                .font(.headline)
                                .foregroundStyle(cardTextColor)
                                .lineLimit(2)

                            Text(historyImportedFileMetadata(for: previewURL))
                                .font(.footnote)
                                .foregroundStyle(cardSecondaryTextColor)

                            Text("This is the original imported file saved with the history entry.")
                                .font(.footnote)
                                .foregroundStyle(cardSecondaryTextColor)
                        }

                        Spacer(minLength: 0)
                    }

                    importedFilePreviewContent(for: previewURL, text: item.notesText)
                }
                .padding(16)
                .background(editorBackground)
            } else {
                historyDetailSection(
                    title: "Original Notes",
                    detail: "\(wordCount(for: item.notesText)) words",
                    text: item.notesText
                )
            }
        }
    }

    private func historyDetailSection(title: String, detail: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: title, detail: detail)

            ScrollView {
                Text(text)
                    .foregroundStyle(cardTextColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(16)
            }
            .frame(minHeight: 180, maxHeight: 280)
            .background(editorBackground)
        }
    }

    private func historyImportedFilePreviewURL(for item: Item) -> URL? {
        guard
            let fileData = item.importedFileData,
            let fileExtension = item.importedFileExtension
        else {
            return nil
        }

        let previewsDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SimplifAIHistoryPreviews", isDirectory: true)

        try? FileManager.default.createDirectory(at: previewsDirectory, withIntermediateDirectories: true)

        let sanitizedSourceName = item.sourceName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: " ", with: "-")
        let fileName = "\(Int(item.timestamp.timeIntervalSince1970))-\(sanitizedSourceName)"
        let destinationURL = previewsDirectory
            .appendingPathComponent(fileName)
            .appendingPathExtension(fileExtension)

        if !FileManager.default.fileExists(atPath: destinationURL.path) {
            try? fileData.write(to: destinationURL, options: .atomic)
        }

        return destinationURL
    }

    private func historyImportedFileMetadata(for url: URL) -> String {
        let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        let formattedSize = ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)

        if let contentType = UTType(filenameExtension: url.pathExtension.lowercased()) {
            let typeName = contentType.localizedDescription ?? "Imported file"
            return fileSize > 0 ? "\(typeName) • \(formattedSize)" : typeName
        }

        return fileSize > 0 ? formattedSize : "Imported file"
    }

    private var appHeaderIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [secondaryAccent, primaryAccent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.22), lineWidth: 1.2)
                )
                .shadow(color: primaryAccent.opacity(0.28), radius: 6, x: 0, y: 3)

            Image("iconUI")
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 36)
                .offset(x: 1, y: -1)
        }
        .frame(width: 58, height: 58, alignment: .center)
    }

    private func settingsSectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(cardTextColor)
    }

    private func pageIntro(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: heroTitleSize, weight: .bold, design: .rounded))
                .foregroundStyle(cardTextColor)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(cardSecondaryTextColor)
        }
    }

    private func sectionHeader(title: String, detail: String, detailColor: Color? = nil) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.headline)
                .foregroundStyle(cardTextColor)

            Spacer()

            Text(detail)
                .font(.footnote)
                .foregroundStyle(detailColor ?? cardSecondaryTextColor)
        }
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

    private func settingsMenuSelector<Content: View>(
        title: String,
        value: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Menu {
            content()
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(cardTextColor)

                    Text(value)
                        .font(.footnote)
                        .foregroundStyle(cardSecondaryTextColor)
                }

                Spacer()

                ZStack {
                    Capsule(style: .continuous)
                        .fill(primaryAccent.opacity(isDarkModeActive ? 0.20 : 0.12))
                        .frame(width: 36, height: 28)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.92))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                isDarkModeActive
                                ? Color.white.opacity(0.08)
                                : Color.white.opacity(0.78),
                                primaryAccent.opacity(isDarkModeActive ? 0.10 : 0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(primaryAccent.opacity(isDarkModeActive ? 0.24 : 0.12), lineWidth: 1)
            )
        }
    }

    private func searchField(
        text: Binding<String>,
        placeholder: String
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(cardSecondaryTextColor)

            TextField(placeholder, text: text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(cardTextColor)

            if !text.wrappedValue.isEmpty {
                Button {
                    text.wrappedValue = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(cardSecondaryTextColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            isDarkModeActive
                            ? Color.white.opacity(0.08)
                            : Color.white.opacity(0.82),
                            primaryAccent.opacity(isDarkModeActive ? 0.10 : 0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(primaryAccent.opacity(isDarkModeActive ? 0.24 : 0.12), lineWidth: 1)
        )
    }

    private func headerInfoCard(
        title: String,
        value: String,
        alignment: HorizontalAlignment = .leading
    ) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(cardSecondaryTextColor)
                .multilineTextAlignment(alignment == .trailing ? .trailing : .leading)

            Text(value)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(cardTextColor)
                .multilineTextAlignment(alignment == .trailing ? .trailing : .leading)
                .lineLimit(2)
                .minimumScaleFactor(0.9)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
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

    private func secondaryActionButton(
        title: String,
        systemImage: String,
        accessibilityLabel: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
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
        .accessibilityLabel(accessibilityLabel ?? title)
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

    private var previewWordCount: Int {
        importedPreviewText.split { $0.isWhitespace || $0.isNewline }.count
    }

    private var currentWordCount: Int {
        notesText.split { $0.isWhitespace || $0.isNewline }.count
    }

    private var summaryWordCount: Int {
        summaryBullets.joined(separator: " ").split { $0.isWhitespace || $0.isNewline }.count
    }

    private var summaryPreviewText: String {
        if summaryFormat == .paragraph {
            return summaryBullets.joined(separator: " ")
        }

        return summaryBullets.prefix(2).joined(separator: " ")
    }

    private var importedFileTypeLabel: String {
        guard let importedFilePreviewURL else {
            return "Imported file"
        }

        if let contentType = UTType(filenameExtension: importedFilePreviewURL.pathExtension.lowercased()) {
            return contentType.localizedDescription ?? contentType.preferredFilenameExtension?.uppercased() ?? "Imported file"
        }

        let fileExtension = importedFilePreviewURL.pathExtension.trimmingCharacters(in: .whitespacesAndNewlines)
        return fileExtension.isEmpty ? "Imported file" : "\(fileExtension.uppercased()) file"
    }

    private var importedFileMetadata: String {
        guard let importedFilePreviewURL else {
            return ""
        }

        let fileSize = (try? importedFilePreviewURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        let formattedSize = ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
        return fileSize > 0 ? "\(importedFileTypeLabel) • \(formattedSize)" : importedFileTypeLabel
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

    private var summaryLoadingScreen: some View {
        ZStack {
            backgroundView

            VStack(spacing: 18) {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.4)

                Text("Building your summary...")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(cardTextColor)

                Text("The AI is reading your notes and preparing the result page.")
                    .font(.subheadline)
                    .foregroundStyle(cardSecondaryTextColor)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }
            .padding(28)
            .frame(maxWidth: 340)
            .background(mainPanelBackground)
        }
        .interactiveDismissDisabled()
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
            let processedImport = processedImportedText(from: fileText, canTrimToLimit: false)
            let fileData = try Data(contentsOf: fileURL)
            let previewURL = try makeImportedFilePreviewCopy(from: fileData, fileExtension: fileURL.pathExtension)

            notesText = processedImport.text
            importedPreviewText = processedImport.text
            importedFileName = fileURL.lastPathComponent
            importedFileData = fileData
            importedFileExtension = fileURL.pathExtension
            importedFilePreviewURL = previewURL
            errorMessage = nil
            importNotice = processedImport.notice
        } catch {
            importedFileName = "Could not import file"
            clearImportedFilePreview()
            importedPreviewText = ""
            errorMessage = "The selected file could not be read as supported text content."
            importNotice = nil
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
            let processedImport = processedImportedText(from: extractedText, canTrimToLimit: true)
            let fileExtension = importedImageFileExtension(from: data) ?? "jpg"
            let previewURL = try makeImportedFilePreviewCopy(from: data, fileExtension: fileExtension)

            guard !processedImport.text.isEmpty else {
                throw CocoaError(.fileReadInapplicableStringEncoding)
            }

            notesText = processedImport.text
            importedPreviewText = processedImport.text
            importedFileName = "Photo Library Image"
            importedFileData = data
            importedFileExtension = fileExtension
            importedFilePreviewURL = previewURL
            errorMessage = nil
            importNotice = processedImport.notice
        } catch {
            importedFileName = "Could not import image"
            clearImportedFilePreview()
            importedPreviewText = ""
            errorMessage = "The selected photo could not be read as text."
            importNotice = nil
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
            let processedImport = processedImportedText(from: extractedText, canTrimToLimit: true)
            let imageData = image.jpegData(compressionQuality: 0.92) ?? image.pngData()
            let fileExtension = imageData.flatMap(importedImageFileExtension(from:)) ?? "jpg"

            guard !processedImport.text.isEmpty else {
                throw CocoaError(.fileReadInapplicableStringEncoding)
            }

            guard let imageData else {
                throw CocoaError(.fileReadUnknown)
            }

            let previewURL = try makeImportedFilePreviewCopy(from: imageData, fileExtension: fileExtension)

            notesText = processedImport.text
            importedPreviewText = processedImport.text
            importedFileName = "Camera Capture"
            importedFileData = imageData
            importedFileExtension = fileExtension
            importedFilePreviewURL = previewURL
            errorMessage = nil
            importNotice = processedImport.notice
        } catch {
            importedFileName = "Could not import image"
            clearImportedFilePreview()
            importedPreviewText = ""
            errorMessage = "The captured image did not contain readable text."
            importNotice = nil
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

    private func makeImportedFilePreviewCopy(from sourceURL: URL) throws -> URL {
        let fileData = try Data(contentsOf: sourceURL)
        return try makeImportedFilePreviewCopy(from: fileData, fileExtension: sourceURL.pathExtension)
    }

    private func makeImportedFilePreviewCopy(from fileData: Data, fileExtension: String) throws -> URL {
        let previewsDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SimplifAIImportedPreviews", isDirectory: true)

        try FileManager.default.createDirectory(at: previewsDirectory, withIntermediateDirectories: true)

        let destinationURL = previewsDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtension)

        clearImportedFilePreview()
        try fileData.write(to: destinationURL, options: .atomic)
        return destinationURL
    }

    private func clearImportedFilePreview() {
        if let importedFilePreviewURL, FileManager.default.fileExists(atPath: importedFilePreviewURL.path) {
            try? FileManager.default.removeItem(at: importedFilePreviewURL)
        }

        self.importedFilePreviewURL = nil
        importedFileData = nil
        importedFileExtension = nil
    }

    private func importedImageFileExtension(from data: Data) -> String? {
        if let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
           let imageType = CGImageSourceGetType(imageSource),
           let type = UTType(imageType as String) {
            return type.preferredFilenameExtension
        }

        return nil
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
        showingSummaryPage = false

        let trimmedNotes = notesText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedNotes.isEmpty else {
            errorMessage = "Enter or import some notes first."
            return
        }

        guard !isClearlyChatInput(trimmedNotes) else {
            errorMessage = "Enter actual notes or document text to simplify, not a chat message."
            return
        }

        guard !wordLimitExceeded else {
            errorMessage = "This note is over the \(maximumSummaryWordCount)-word limit. Shorten it before summarising."
            return
        }

        isLoading = true
        showingSummaryLoading = true
        defer {
            isLoading = false
        }

        do {
            let bullets = try await summariseOnDevice(notes: trimmedNotes)

            summaryBullets = bullets
            applyStudyPack(.empty)
            await saveHistoryEntry(notes: trimmedNotes, bullets: bullets)
            if autoCopySummary {
                copySummaryToClipboard()
            }
            showingSummaryLoading = false
            DispatchQueue.main.async {
                showingSummaryPage = true
            }
        } catch let error as SummaryError {
            showingSummaryLoading = false
            errorMessage = error.message
        } catch {
            showingSummaryLoading = false
            errorMessage = "Something unexpected went wrong. Please try again."
        }
    }

    private func summariseOnDevice(notes: String) async throws -> [String] {
        return try await OpenRouterSummaryAI(
            endpointURL: embeddedWorkerURL,
            model: validatedOpenRouterModel()
        ).summariseNotes(
            notes: notes,
            configuration: summaryConfiguration
        )
    }

    private func saveHistoryEntry(notes: String, bullets: [String]) async {
        let sourceName = importedFileName == noFileSelectedName ? manualNotesSourceName : importedFileName
        let summaryText = bullets.joined(separator: "\n")
        let title = await generatedHistoryTitle(notes: notes, bullets: bullets, sourceName: sourceName)
        let item = Item(
            title: title,
            sourceName: sourceName,
            notesText: notes,
            summaryText: summaryText,
            studyPackData: encodedStudyPack(.empty),
            importedFileData: importedFileData,
            importedFileExtension: importedFileExtension
        )
        modelContext.insert(item)
    }

    private func useHistoryItem(_ item: Item) {
        notesText = item.notesText
        summaryBullets = normalisedBulletLines(from: item.summaryText)
        let storedStudyPack = decodedStudyPack(from: item.studyPackData) ?? .empty
        applyStudyPack(storedStudyPack)
        let isManualNotesHistory = item.sourceName == manualNotesSourceName
        importedFileName = isManualNotesHistory ? noFileSelectedName : item.sourceName
        clearImportedFilePreview()

        if
            let storedFileData = item.importedFileData,
            let storedFileExtension = item.importedFileExtension,
            !isManualNotesHistory,
            let previewURL = try? makeImportedFilePreviewCopy(from: storedFileData, fileExtension: storedFileExtension)
        {
            importedFileData = storedFileData
            importedFileExtension = storedFileExtension
            importedFilePreviewURL = previewURL
            importedPreviewText = item.notesText
        } else {
            importedPreviewText = isManualNotesHistory ? "" : item.notesText
        }

        errorMessage = nil
        selectedTab = .summarise
    }

    private func deleteHistoryItem(_ item: Item) {
        modelContext.delete(item)
    }

    private func clearAllHistory() {
        for item in historyItems {
            modelContext.delete(item)
        }
    }

    private func copySummaryToClipboard() {
        let summaryText = summaryFormat == .paragraph
            ? summaryBullets.joined(separator: " ")
            : summaryBullets.map { "• \($0)" }.joined(separator: "\n")

        UIPasteboard.general.string = summaryText
        didCopySummary = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            didCopySummary = false
        }
    }

    private func removeImportedFile() {
        importedFileName = noFileSelectedName
        clearImportedFilePreview()
        importedPreviewText = ""
        notesText = ""
        summaryBullets = []
        applyStudyPack(.empty)
        errorMessage = nil
        importNotice = nil
    }

    private func clearNotesEditor() {
        notesText = ""
        clearImportedFilePreview()
        summaryBullets = []
        applyStudyPack(.empty)
        errorMessage = nil
        importNotice = nil
    }

    @MainActor
    private func buildStudyPack(notes: String, bullets: [String]) async throws -> StudyPack {
        let counts = effectiveStudyCounts(for: notes, bullets: bullets)
        let fallbackPack = fallbackStudyPack(
            from: bullets,
            flashcardCount: counts.flashcards,
            quizQuestionCount: counts.questions
        )

        guard !bullets.isEmpty else {
            return fallbackPack
        }

        let generatedPack = try await selectedStudyPackProvider(
            notes: notes,
            bullets: bullets,
            flashcardCount: counts.flashcards,
            quizQuestionCount: counts.questions
        )
        return repairedStudyPack(generatedPack, fallback: fallbackPack, bullets: bullets)
    }

    @MainActor
    private func generateStudyPackIfPossible() async {
        errorMessage = nil

        let trimmedNotes = notesText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNotes.isEmpty, !summaryBullets.isEmpty else {
            errorMessage = "Create a summary first before generating a study set."
            return
        }

        isGeneratingStudyPack = true
        defer { isGeneratingStudyPack = false }

        do {
            let studyPack = try await buildStudyPack(notes: trimmedNotes, bullets: summaryBullets)
            applyStudyPack(studyPack)
            persistStudyPack(studyPack, notes: trimmedNotes, bullets: summaryBullets)
        } catch let error as SummaryError {
            errorMessage = error.message
        } catch {
            errorMessage = "The study set could not be created right now. Please try again."
        }
    }

    private func persistStudyPack(_ studyPack: StudyPack, notes: String, bullets: [String]) {
        let summaryText = bullets.joined(separator: "\n")

        if let matchingItem = historyItems.first(where: {
            $0.notesText == notes && $0.summaryText == summaryText
        }) {
            matchingItem.studyPackData = encodedStudyPack(studyPack)
        }
    }

    @MainActor
    private func applyStudyPack(_ studyPack: StudyPack) {
        studyFlashcards = studyPack.flashcards
        studyQuizQuestions = studyPack.quizQuestions
        selectedStudyMode = .flashcards
        revealedFlashcardIndices = []
        activeFlashcardIndex = 0
    }

    private func fallbackStudyPack(from bullets: [String], flashcardCount: Int, quizQuestionCount: Int) -> StudyPack {
        let cleanedBullets = bullets
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let flashcards = (0..<flashcardCount).compactMap { index -> StudyFlashcard? in
            guard !cleanedBullets.isEmpty else {
                return nil
            }

            let sourcePoint = flashcardSourcePoint(for: index, bulletCount: cleanedBullets.count)
            let bullet = cleanedBullets[sourcePoint - 1]
            let cycle = studyCycle(for: index, itemCount: cleanedBullets.count)
            let kind = flashcardKind(for: index, sourcePoint: sourcePoint, cycle: cycle)

            return StudyFlashcard(
                kind: kind,
                sourceSummaryPoint: sourcePoint,
                prompt: fallbackFlashcardPrompt(for: kind, bullet: bullet, variant: cycle),
                answer: bullet
            )
        }

        let quizQuestions = (0..<quizQuestionCount).compactMap { index -> QuizQuestion? in
            guard !cleanedBullets.isEmpty else {
                return nil
            }

            let sourcePoint = ((index % cleanedBullets.count) + 1)
            let bullet = cleanedBullets[sourcePoint - 1]
            let cycle = studyCycle(for: index, itemCount: cleanedBullets.count)
            return fallbackQuizQuestion(
                correctAnswer: bullet,
                from: cleanedBullets,
                index: index,
                sourcePoint: sourcePoint,
                variant: cycle
            )
        }

        return StudyPack(flashcards: flashcards, quizQuestions: quizQuestions)
    }

    private func effectiveStudyCounts(for notes: String, bullets: [String]) -> StudyCounts {
        guard studyUsesSmartCounts else {
            return StudyCounts(
                flashcards: boundedStudyCount(studyFlashcardCount),
                questions: boundedStudyCount(studyQuizQuestionCount)
            )
        }

        let recommended = recommendedStudyCounts(for: notes, bullets: bullets)
        return StudyCounts(
            flashcards: boundedStudyCount(recommended.flashcards),
            questions: boundedStudyCount(recommended.questions)
        )
    }

    private func boundedStudyCount(_ value: Int) -> Int {
        max(studyCountRange.lowerBound, min(studyCountRange.upperBound, value))
    }

    private func recommendedStudyCounts(for notes: String, bullets: [String]) -> StudyCounts {
        let cleanedBullets = bullets
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let noteWordCount = notes.split { $0.isWhitespace || $0.isNewline }.count
        let bulletWordAverage = cleanedBullets.isEmpty
            ? 0
            : cleanedBullets.map { wordCount(for: $0) }.reduce(0, +) / cleanedBullets.count

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
        let flashcards = max(2, min(studyCountRange.upperBound, bulletCount + densityBoost + detailBoost))
        let questions = max(
            2,
            min(
                studyCountRange.upperBound,
                Int(ceil(Double(bulletCount) * 0.75)) + max(densityBoost - 1, 0) + detailBoost
            )
        )

        return StudyCounts(flashcards: flashcards, questions: questions)
    }

    private func studyGenerationDescription(notes: String, bullets: [String]) -> String {
        let counts = effectiveStudyCounts(for: notes, bullets: bullets)
        if studyUsesSmartCounts {
            return "Create a study set when you want it. Based on this summary, the app recommends \(counts.flashcards) flashcards and \(counts.questions) quiz questions."
        }

        return "Create a study set when you want it. Your manual settings will generate \(counts.flashcards) flashcards and \(counts.questions) quiz questions."
    }

    private func flashcardSourcePoint(for index: Int, bulletCount: Int) -> Int {
        guard bulletCount > 0 else {
            return 1
        }

        return (index % bulletCount) + 1
    }

    private func studyCycle(for index: Int, itemCount: Int) -> Int {
        guard itemCount > 0 else {
            return 0
        }

        return index / itemCount
    }

    private func repairedStudyPack(_ generated: StudyPack, fallback: StudyPack, bullets: [String]) -> StudyPack {
        let repairedFlashcards = zipLongest(generated.flashcards, fallback.flashcards).compactMap { generatedCard, fallbackCard in
            if let generatedCard, isValid(generatedCard) {
                return generatedCard
            }
            return fallbackCard
        }

        let repairedQuizQuestions = zipLongest(generated.quizQuestions, fallback.quizQuestions).compactMap { generatedQuestion, fallbackQuestion in
            if let generatedQuestion,
               isValid(generatedQuestion),
               hasCorrelatedOptions(generatedQuestion, bullets: bullets) {
                return generatedQuestion
            }
            return fallbackQuestion
        }

        return StudyPack(
            flashcards: repairedFlashcards.isEmpty ? fallback.flashcards : repairedFlashcards,
            quizQuestions: repairedQuizQuestions.isEmpty ? fallback.quizQuestions : repairedQuizQuestions
        )
    }

    private func isValid(_ flashcard: StudyFlashcard) -> Bool {
        let prompt = flashcard.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let answer = flashcard.answer.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !prompt.isEmpty, !answer.isEmpty else {
            return false
        }

        let invalidValues = ["prompt", "answer", "question", "definition", "flashcard"]
        if invalidValues.contains(prompt.lowercased()) || invalidValues.contains(answer.lowercased()) {
            return false
        }

        let genericPromptFragments = [
            "define this idea",
            "what fact or date should you remember",
            "what causes this",
            "how does this connect"
        ]
        if genericPromptFragments.contains(where: { prompt.lowercased().contains($0) }) {
            return false
        }

        if prompt.caseInsensitiveCompare(answer) == .orderedSame {
            return false
        }

        return wordCount(for: prompt) >= 3 && wordCount(for: answer) >= 2
    }

    private func isValid(_ question: QuizQuestion) -> Bool {
        let prompt = question.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, question.options.count == 4, question.options.indices.contains(question.correctAnswerIndex) else {
            return false
        }

        let normalizedOptions = question.options
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard normalizedOptions.count == 4 else {
            return false
        }

        let uniqueOptions = Set(normalizedOptions.map { $0.lowercased() })
        guard uniqueOptions.count == 4 else {
            return false
        }

        let invalidValues = ["ai", "option", "answer", "true", "false"]
        if normalizedOptions.allSatisfy({ invalidValues.contains($0.lowercased()) }) {
            return false
        }

        let metaPhrases = [
            "the summary says",
            "the summary links",
            "the summary presents",
            "the summary shows",
            "the notes say",
            "the notes mention"
        ]
        if normalizedOptions.contains(where: { option in
            let lowered = option.lowercased()
            return metaPhrases.contains(where: lowered.contains)
        }) {
            return false
        }

        let genericQuestionFragments = [
            "concept from the notes",
            "supported by the notes",
            "matches the notes",
            "best answer on an exam"
        ]
        if genericQuestionFragments.contains(where: { prompt.lowercased().contains($0) }) {
            return false
        }

        guard let correctAnswer = normalizedOptions[safe: question.correctAnswerIndex] else {
            return false
        }
        if prompt.caseInsensitiveCompare(correctAnswer) == .orderedSame {
            return false
        }

        return wordCount(for: prompt) >= 4
    }

    private func hasCorrelatedOptions(_ question: QuizQuestion, bullets: [String]) -> Bool {
        guard let sourceSummaryPoint = question.sourceSummaryPoint,
              bullets.indices.contains(sourceSummaryPoint - 1) else {
            return false
        }

        let sourceBullet = bullets[sourceSummaryPoint - 1]
        let focusTerms = focusedStudyTerms(from: sourceBullet)
        guard !focusTerms.isEmpty else {
            return false
        }

        let alignedOptions = question.options.filter { option in
            let normalizedOption = option.lowercased()
            return focusTerms.contains { normalizedOption.contains($0) }
        }

        return alignedOptions.count >= 3
    }

    private func focusedStudyTerms(from text: String) -> [String] {
        let words = text
            .replacingOccurrences(of: "[^A-Za-z0-9\\s-]", with: " ", options: .regularExpression)
            .lowercased()
            .split(separator: " ")
            .map(String.init)
            .filter { word in
                !word.isEmpty &&
                !["the", "a", "an", "and", "or", "but", "this", "that", "with", "from", "into", "about", "because", "there", "their", "they", "them", "for", "are", "is", "was", "were", "can", "will", "has", "have", "had", "its"].contains(word)
            }

        let trailingTerms = Array(words.suffix(4))
        let leadingTerms = Array(words.prefix(2))
        return Array(Set(leadingTerms + trailingTerms)).filter { $0.count > 2 }
    }

    private func studyTopic(from bullet: String) -> String {
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

    private func zipLongest<T>(_ lhs: [T], _ rhs: [T]) -> [(T?, T?)] {
        let count = max(lhs.count, rhs.count)
        return (0..<count).map { index in
            let left = lhs.indices.contains(index) ? lhs[index] : nil
            let right = rhs.indices.contains(index) ? rhs[index] : nil
            return (left, right)
        }
    }

    private func flashcardKind(for index: Int, sourcePoint: Int, cycle: Int) -> StudyFlashcardKind {
        let kinds: [StudyFlashcardKind] = [.definition, .factRecall, .causeEffect, .connection]
        let position = (sourcePoint - 1 + cycle + index / max(kinds.count, 1)) % kinds.count
        return kinds[position]
    }

    private func fallbackFlashcardPrompt(for kind: StudyFlashcardKind, bullet: String, variant: Int) -> String {
        let topic = studyTopic(from: bullet)

        switch kind {
        case .definition:
            let prompts = [
                "How does the summary define \(topic)?",
                "What is the clearest one-line definition of \(topic) from the summary?",
                "How would you describe \(topic) using the summary's wording?"
            ]
            return prompts[variant % prompts.count]
        case .factRecall:
            let prompts = [
                "What key fact does the summary mention about \(topic)?",
                "Which detail about \(topic) is most important to remember?",
                "What specific point about \(topic) should you recall from the summary?"
            ]
            return prompts[variant % prompts.count]
        case .causeEffect:
            let prompts = [
                "According to the summary, what impact or result is linked to \(topic)?",
                "What does the summary say \(topic) leads to or causes?",
                "How is \(topic) connected to an outcome in the summary?"
            ]
            return prompts[variant % prompts.count]
        case .connection:
            let prompts = [
                "How does \(topic) connect to the rest of the summary?",
                "Why does \(topic) matter in the bigger picture of the summary?",
                "How does the summary link \(topic) to the wider topic?"
            ]
            return prompts[variant % prompts.count]
        }
    }

    private func applyTemplate(_ template: SummaryTemplate) {
        applyTemplate(template, switchToSummarise: true)
    }

    private func applyInitialPreferencesIfNeeded() {
        guard !hasAppliedInitialPreferences else {
            return
        }

        hasAppliedInitialPreferences = true
        selectedTemplate = defaultTemplate
        applyTemplate(defaultTemplate, switchToSummarise: false)
    }

    private func applyTemplate(_ template: SummaryTemplate, switchToSummarise: Bool) {
        selectedTemplate = template
        summaryFormat = template.format
        summaryDetail = template.detail
        summaryBulletCount = template.bulletCount

        if switchToSummarise {
            selectedTab = .summarise
        }
    }

    private func requestDestructiveAction(_ action: DestructiveAction) {
        guard confirmBeforeClear else {
            performDestructiveAction(action)
            return
        }

        pendingDestructiveAction = action
    }

    private func performPendingDestructiveAction() {
        guard let pendingDestructiveAction else {
            return
        }

        performDestructiveAction(pendingDestructiveAction)
        self.pendingDestructiveAction = nil
    }

    private func performDestructiveAction(_ action: DestructiveAction) {
        switch action {
        case .clearHistory:
            clearAllHistory()
        case .clearNotes:
            clearNotesEditor()
        case .removeImportedFile:
            removeImportedFile()
        }
    }

    private func normalisedBulletLines(from text: String) -> [String] {
        text
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func isClearlyChatInput(_ text: String) -> Bool {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let wordCount = wordCount(for: normalized)

        guard wordCount <= 12 else {
            return false
        }

        let chatPatterns = [
            "hello",
            "hi",
            "hey",
            "how are you",
            "what's up",
            "whats up",
            "thanks",
            "thank you",
            "good morning",
            "good afternoon",
            "good evening"
        ]

        return chatPatterns.contains(normalized)
    }

    private func historyPreviewText(for item: Item) -> String {
        formattedHistorySummaryText(for: item)
    }

    private func generatedHistoryTitle(notes: String, bullets: [String], sourceName: String) async -> String {
        switch selectedHistoryTitleStyle {
        case .aiShortened:
            if let aiTitle = try? await generatedAITitle(notes: notes, bullets: bullets) {
                let cleanedTitle = aiTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleanedTitle.isEmpty {
                    return cleanedTitle
                }
            }
        case .sourceName:
            let sourceBaseName = URL(fileURLWithPath: sourceName)
                .deletingPathExtension()
                .lastPathComponent
                .trimmingCharacters(in: .whitespacesAndNewlines)

            return sourceBaseName.isEmpty ? "Untitled Summary" : sourceBaseName
        case .firstLine:
            break
        }

        let preferredText = bullets.first ?? notes
        let cleanedText = preferredText
            .replacingOccurrences(of: "[^A-Za-z0-9\\s]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let titleWords = cleanedText
            .split(separator: " ")
            .prefix(6)
            .map(String.init)

        if !titleWords.isEmpty {
            return titleWords.joined(separator: " ")
        }

        let sourceBaseName = URL(fileURLWithPath: sourceName)
            .deletingPathExtension()
            .lastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return sourceBaseName.isEmpty ? "Untitled Summary" : sourceBaseName
    }

    private func selectedStudyPackProvider(
        notes: String,
        bullets: [String],
        flashcardCount: Int,
        quizQuestionCount: Int
    ) async throws -> StudyPack {
        return try await OpenRouterSummaryAI(
            endpointURL: embeddedWorkerURL,
            model: validatedOpenRouterModel()
        ).generateStudyPack(
            notes: notes,
            bullets: bullets,
            flashcardCount: flashcardCount,
            quizQuestionCount: quizQuestionCount
        )
    }

    private func generatedAITitle(notes: String, bullets: [String]) async throws -> String {
        return try await OpenRouterSummaryAI(
            endpointURL: embeddedWorkerURL,
            model: validatedOpenRouterModel()
        ).generateHistoryTitle(
            notes: notes,
            bullets: bullets
        )
    }

    private func validatedOpenRouterModel() -> String {
        let trimmedModel = embeddedOpenRouterModel.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedModel.isEmpty ? "openai/gpt-4o-mini" : trimmedModel
    }

    private func formattedHistorySummaryText(for item: Item) -> String {
        let lines = normalisedBulletLines(from: item.summaryText)

        if lines.count > 1 {
            return lines.map { "• \($0)" }.joined(separator: "\n")
        }

        return item.summaryText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func encodedStudyPack(_ studyPack: StudyPack) -> String {
        guard let data = try? JSONEncoder().encode(studyPack),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }

        return string
    }

    private func decodedStudyPack(from rawValue: String) -> StudyPack? {
        guard let data = rawValue.data(using: .utf8) else {
            return nil
        }

        return try? JSONDecoder().decode(StudyPack.self, from: data)
    }

    private func fallbackQuizQuestion(
        correctAnswer: String,
        from bullets: [String],
        index: Int,
        sourcePoint: Int,
        variant: Int
    ) -> QuizQuestion {
        let cleanedCorrectAnswer = correctAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        let style = quizStyle(for: index, sourcePoint: sourcePoint, cycle: variant)
        let topic = studyTopic(from: correctAnswer)
        let distractors = correlatedDistractors(
            for: cleanedCorrectAnswer,
            topic: topic,
            style: style
        )

        var options = [cleanedCorrectAnswer]
        options.append(contentsOf: distractors)

        while options.count < 4 {
            options.append("\(topic) is described in a way that is not supported by the summary.")
        }

        var arrangedOptions = Array(options.prefix(4))
        arrangedOptions.shuffle()
        let correctIndex = arrangedOptions.firstIndex {
            $0.caseInsensitiveCompare(cleanedCorrectAnswer) == .orderedSame
        } ?? 0

        let prompt = fallbackQuizPrompt(for: style, topic: topic, variant: variant)
        return QuizQuestion(
            style: style,
            sourceSummaryPoint: sourcePoint,
            prompt: prompt,
            options: arrangedOptions,
            correctAnswerIndex: correctIndex,
            explanation: cleanedCorrectAnswer
        )
    }

    private func correlatedDistractors(for correctAnswer: String, topic: String, style: QuizQuestionStyle) -> [String] {
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
                "\(conciseTopic) is mentioned, but the summary does not support this interpretation.",
                "\(conciseTopic) is discussed in a narrower way than this option suggests.",
                "\(conciseTopic) appears in the summary, but not with this conclusion or implication."
            ]
        }

        return candidates.filter { $0.caseInsensitiveCompare(correctAnswer) != .orderedSame }
    }

    private func quizStyle(for index: Int, sourcePoint: Int, cycle: Int) -> QuizQuestionStyle {
        let styles: [QuizQuestionStyle] = [.definitionCheck, .factDate, .causeEffect, .examStyle]
        let position = (sourcePoint - 1 + cycle + index / max(styles.count, 1)) % styles.count
        return styles[position]
    }

    private func fallbackQuizPrompt(for style: QuizQuestionStyle, topic: String, variant: Int) -> String {
        switch style {
        case .definitionCheck:
            let prompts = [
                "Which summary point best explains \(topic)?",
                "Which option gives the most accurate definition of \(topic)?",
                "Which answer best captures what the summary means by \(topic)?"
            ]
            return prompts[variant % prompts.count]
        case .factDate:
            let prompts = [
                "Which option gives the key fact about \(topic)?",
                "Which detail about \(topic) is directly supported by the summary?",
                "Which answer matches the main factual point about \(topic)?"
            ]
            return prompts[variant % prompts.count]
        case .causeEffect:
            let prompts = [
                "Which option describes a cause or effect related to \(topic)?",
                "Which answer correctly explains what \(topic) leads to or results from?",
                "Which option best matches the outcome linked to \(topic)?"
            ]
            return prompts[variant % prompts.count]
        case .examStyle:
            let prompts = [
                "If you were asked about \(topic) on an exam, which option is best supported by the summary?",
                "Which answer would be the strongest exam response about \(topic) based on the summary?",
                "Which option is the best-supported interpretation of \(topic)?"
            ]
            return prompts[variant % prompts.count]
        }
    }

    private func wordCount(for text: String) -> Int {
        text
            .split { $0.isWhitespace || $0.isNewline }
            .count
    }

    private var hasImportedFile: Bool {
        importedFileName != noFileSelectedName && importedFileName != manualNotesSourceName
    }

    private func processedImportedText(from rawText: String, canTrimToLimit: Bool) -> (text: String, notice: String?) {
        let lines = rawText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter {
                !$0.isEmpty &&
                $0.rangeOfCharacter(from: .letters) != nil
            }

        var deduplicatedLines: [String] = []
        deduplicatedLines.reserveCapacity(lines.count)

        for line in lines where deduplicatedLines.last != line {
            deduplicatedLines.append(line)
        }

        let cleanedText = deduplicatedLines.joined(separator: "\n")
        let cleanedWordCount = wordCount(for: cleanedText)

        guard canTrimToLimit, cleanedWordCount > maximumSummaryWordCount else {
            return (
                cleanedText.trimmingCharacters(in: .whitespacesAndNewlines),
                nil
            )
        }

        return (
            firstWords(maximumSummaryWordCount, from: cleanedText),
            "The imported image text was trimmed to \(maximumSummaryWordCount) words so it can be summarised more reliably."
        )
    }

    private func firstWords(_ limit: Int, from text: String) -> String {
        text
            .split { $0.isWhitespace || $0.isNewline }
            .prefix(limit)
            .joined(separator: " ")
    }

    private var destructiveActionBinding: Binding<Bool> {
        Binding(
            get: { pendingDestructiveAction != nil },
            set: { newValue in
                if !newValue {
                    pendingDestructiveAction = nil
                }
            }
        )
    }

    private var destructiveActionButtonTitle: String {
        switch pendingDestructiveAction {
        case .clearHistory:
            return "Clear All History"
        case .clearNotes:
            return "Clear Notes"
        case .removeImportedFile:
            return "Remove File"
        case nil:
            return "Confirm"
        }
    }

    private var destructiveActionMessage: String {
        switch pendingDestructiveAction {
        case .clearHistory:
            return "Are you sure you want to delete all saved history items? This cannot be undone."
        case .clearNotes:
            return "Are you sure you want to clear all notes and the current summary?"
        case .removeImportedFile:
            return "Are you sure you want to remove the imported file text from the current screen?"
        case nil:
            return ""
        }
    }
}
private struct SummaryResultScreen: View {
    let summaryBullets: [String]
    let summaryFormat: SummaryFormat
    let summaryWordCount: Int
    let didCopySummary: Bool
    let onCopySummary: () -> Void
    let onOpenStudyMode: () -> Void

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

    private var isSmallPhoneLayout: Bool {
        guard UIDevice.current.userInterfaceIdiom == .phone else {
            return false
        }

        let screenBounds = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.screen.bounds }
            .first ?? CGRect(x: 0, y: 0, width: 390, height: 844)

        return min(screenBounds.width, screenBounds.height) <= 375
    }

    private var heroTitleSize: CGFloat {
        isSmallPhoneLayout ? 30 : 34
    }

    var body: some View {
        ZStack {
            backgroundView

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    pageIntro(
                        title: "Summary",
                        subtitle: "Review the generated result on its own page."
                    )

                    contentPanel {
                        sectionHeader(title: "Result", detail: "\(summaryWordCount) words")

                        summaryCard

                        HStack(spacing: 12) {
                            secondaryActionButton(
                                title: didCopySummary ? "Copied" : "Copy Summary",
                                systemImage: didCopySummary ? "checkmark" : "doc.on.doc"
                            ) {
                                onCopySummary()
                            }

                            Button {
                                onOpenStudyMode()
                            } label: {
                                Label("Open Study Mode", systemImage: "book.closed")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(actionButtonBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }

                        Text("AI can make mistakes. Check important details.")
                            .font(.footnote)
                            .foregroundStyle(cardSecondaryTextColor)
                    }
                }
                .frame(maxWidth: contentWidth)
                .padding(.horizontal, horizontalScreenPadding)
                .padding(.vertical, verticalScreenPadding)
            }
        }
        .navigationTitle("Summary")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if summaryBullets.isEmpty {
                Text("No summary available yet.")
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
        .frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
        .padding()
        .background(editorBackground)
    }

    private func pageIntro(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: heroTitleSize, weight: .bold, design: .rounded))
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

    private func sectionHeader(title: String, detail: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.headline)
                .foregroundStyle(cardTextColor)

            Spacer()

            Text(detail)
                .font(.footnote)
                .foregroundStyle(cardSecondaryTextColor)
        }
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
        .buttonStyle(.plain)
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

    private var editorBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(isDarkModeActive ? Color.white.opacity(0.08) : Color.white.opacity(0.82))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(primaryAccent.opacity(isDarkModeActive ? 0.22 : 0.12), lineWidth: 1)
            )
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
}
private struct SummarySettingsScreen: View {
    @Binding var summaryFormat: SummaryFormat
    @Binding var summaryDetail: SummaryDetail
    @Binding var summaryBulletCount: Int
    @Binding var selectedTab: AppTab

    private let primaryAccent = Color(red: 0.08, green: 0.36, blue: 0.67)
    private let secondaryAccent = Color(red: 0.17, green: 0.63, blue: 0.77)
    private let contentWidth: CGFloat = 640
    private let horizontalScreenPadding: CGFloat = 20
    private let verticalScreenPadding: CGFloat = 28

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    private var isDarkModeActive: Bool {
        colorScheme == .dark
    }

    private var cardTextColor: Color {
        isDarkModeActive ? Color(red: 0.92, green: 0.95, blue: 0.98) : Color(red: 0.14, green: 0.18, blue: 0.24)
    }

    private var cardSecondaryTextColor: Color {
        isDarkModeActive ? Color(red: 0.68, green: 0.74, blue: 0.82) : Color(red: 0.39, green: 0.45, blue: 0.54)
    }

    private var isSmallPhoneLayout: Bool {
        guard UIDevice.current.userInterfaceIdiom == .phone else {
            return false
        }

        let screenBounds = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.screen.bounds }
            .first ?? CGRect(x: 0, y: 0, width: 390, height: 844)

        return min(screenBounds.width, screenBounds.height) <= 375
    }

    private var heroTitleSize: CGFloat {
        isSmallPhoneLayout ? 30 : 34
    }

    var body: some View {
        ZStack {
            backgroundView

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    pageIntro(
                        title: "Summary Settings",
                        subtitle: "Control how the app formats and sizes each summary."
                    )

                    contentPanel {
                        summaryOptionsSection
                    }
                }
                .frame(maxWidth: contentWidth)
                .padding(.horizontal, horizontalScreenPadding)
                .padding(.vertical, verticalScreenPadding)
            }
        }
        .navigationTitle("Summary Settings")
        .navigationBarTitleDisplayMode(.inline)
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

            VStack(alignment: .leading, spacing: 10) {
                Text("Not sure what to pick?")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(cardTextColor)

                Text("Use Templates instead and start from a preset that fits the kind of summary you want.")
                    .font(.footnote)
                    .foregroundStyle(cardSecondaryTextColor)

                Button {
                    selectedTab = .templates
                    dismiss()
                } label: {
                    Label("Open Templates", systemImage: "square.grid.2x2")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(.white)
                        .background(actionButtonBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .padding(.top, 6)
        }
    }

    private func pageIntro(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: heroTitleSize, weight: .bold, design: .rounded))
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
}

@MainActor
final class SubscriptionManager: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var activeSubscriptionIDs: Set<String> = []
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var isProcessingPurchase = false
    @Published var purchaseErrorMessage: String?

    let productIDs = [
        "com.simplifai.pro.monthly",
        "com.simplifai.pro.yearly"
    ]

    private var updatesTask: Task<Void, Never>?

    var hasActiveSubscription: Bool {
        !activeSubscriptionIDs.isEmpty
    }

    init() {
        updatesTask = observeTransactionUpdates()

        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            let fetchedProducts = try await Product.products(for: productIDs)
            products = fetchedProducts.sorted { $0.price < $1.price }
            purchaseErrorMessage = nil
        } catch {
            purchaseErrorMessage = "Subscriptions could not be loaded right now."
        }
    }

    func refreshEntitlements() async {
        var activeIDs: Set<String> = []

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? verifiedTransaction(from: result),
                  transaction.revocationDate == nil else {
                continue
            }

            activeIDs.insert(transaction.productID)
        }

        activeSubscriptionIDs = activeIDs
    }

    func purchase(_ product: Product) async {
        isProcessingPurchase = true
        defer { isProcessingPurchase = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verificationResult):
                let transaction = try verifiedTransaction(from: verificationResult)
                await transaction.finish()
                await refreshEntitlements()
                purchaseErrorMessage = nil
            case .pending:
                purchaseErrorMessage = "Your purchase is pending approval."
            case .userCancelled:
                break
            @unknown default:
                purchaseErrorMessage = "The purchase could not be completed."
            }
        } catch {
            purchaseErrorMessage = "The purchase could not be completed."
        }
    }

    func restorePurchases() async {
        isProcessingPurchase = true
        defer { isProcessingPurchase = false }

        do {
            try await AppStore.sync()
            await refreshEntitlements()
            purchaseErrorMessage = nil
        } catch {
            purchaseErrorMessage = "Restore Purchases could not be completed."
        }
    }

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task(priority: .background) {
            for await result in Transaction.updates {
                guard let transaction = try? self.verifiedTransaction(from: result) else {
                    continue
                }

                await transaction.finish()
                await self.refreshEntitlements()
            }
        }
    }

    private func verifiedTransaction<T>(
        from result: VerificationResult<T>
    ) throws -> T {
        switch result {
        case .verified(let signedType):
            return signedType
        case .unverified:
            throw StoreError.failedVerification
        }
    }
}

private enum StoreError: Error {
    case failedVerification
}

private struct SubscriptionPaywallScreen: View {
    let featureName: String

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.colorScheme) private var colorScheme

    private let primaryAccent = Color(red: 0.08, green: 0.36, blue: 0.67)
    private let secondaryAccent = Color(red: 0.17, green: 0.63, blue: 0.77)

    private var isDarkModeActive: Bool {
        colorScheme == .dark
    }

    private var cardTextColor: Color {
        isDarkModeActive ? Color(red: 0.92, green: 0.95, blue: 0.98) : Color(red: 0.14, green: 0.18, blue: 0.24)
    }

    private var cardSecondaryTextColor: Color {
        isDarkModeActive ? Color(red: 0.68, green: 0.74, blue: 0.82) : Color(red: 0.39, green: 0.45, blue: 0.54)
    }

    private var isSmallPhoneLayout: Bool {
        guard UIDevice.current.userInterfaceIdiom == .phone else {
            return false
        }

        let screenBounds = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.screen.bounds }
            .first ?? CGRect(x: 0, y: 0, width: 390, height: 844)

        return min(screenBounds.width, screenBounds.height) <= 375
    }

    private var paywallTitleSize: CGFloat {
        isSmallPhoneLayout ? 29 : 32
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundView

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        heroSection
                        productsSection
                        footerSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 28)
                }
            }
            .navigationTitle("SimplifAI Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            if subscriptionManager.products.isEmpty {
                await subscriptionManager.loadProducts()
            }

            await subscriptionManager.refreshEntitlements()
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Unlock \(featureName)")
                .font(.system(size: paywallTitleSize, weight: .bold, design: .rounded))
                .foregroundStyle(cardTextColor)

            Text("Subscribe to SimplifAI Pro to generate summaries, build study sets, and keep premium features unlocked across the app.")
                .font(.subheadline)
                .foregroundStyle(cardSecondaryTextColor)

            HStack(spacing: 10) {
                benefitBadge("Unlimited summaries")
                benefitBadge("Study mode")
                benefitBadge("Restore purchases")
            }
        }
        .padding(22)
        .background(mainPanelBackground)
    }

    private var productsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Choose a Plan")
                .font(.headline)
                .foregroundStyle(cardTextColor)

            if subscriptionManager.isLoadingProducts && subscriptionManager.products.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else if subscriptionManager.products.isEmpty {
                Text("No subscriptions are available yet. Replace the placeholder product IDs in `SubscriptionManager.swift` and configure them in App Store Connect.")
                    .font(.footnote)
                    .foregroundStyle(cardSecondaryTextColor)
                    .padding(16)
                    .background(editorBackground)
            } else {
                ForEach(subscriptionManager.products, id: \.id) { product in
                    productCard(for: product)
                }
            }

            if let purchaseErrorMessage = subscriptionManager.purchaseErrorMessage {
                Text(purchaseErrorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .padding(22)
        .background(mainPanelBackground)
    }

    private func productCard(for product: Product) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.displayName)
                        .font(.headline)
                        .foregroundStyle(cardTextColor)

                    Text(product.description)
                        .font(.footnote)
                        .foregroundStyle(cardSecondaryTextColor)
                }

                Spacer()

                Text(product.displayPrice)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(primaryAccent)
            }

            Button {
                Task {
                    await subscriptionManager.purchase(product)

                    if subscriptionManager.hasActiveSubscription {
                        dismiss()
                    }
                }
            } label: {
                Text(subscriptionManager.activeSubscriptionIDs.contains(product.id) ? "Current Plan" : "Subscribe")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(.white)
                    .background(actionButtonBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(subscriptionManager.isProcessingPurchase || subscriptionManager.activeSubscriptionIDs.contains(product.id))
            .opacity((subscriptionManager.isProcessingPurchase || subscriptionManager.activeSubscriptionIDs.contains(product.id)) ? 0.75 : 1)
        }
        .padding(18)
        .background(editorBackground)
    }

    private var footerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                Task {
                    await subscriptionManager.restorePurchases()

                    if subscriptionManager.hasActiveSubscription {
                        dismiss()
                    }
                }
            } label: {
                Text("Restore Purchases")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(cardTextColor)
                    .background(editorBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(subscriptionManager.isProcessingPurchase)

            Text("Placeholder product IDs are currently set to `com.simplifai.pro.monthly` and `com.simplifai.pro.yearly`.")
                .font(.footnote)
                .foregroundStyle(cardSecondaryTextColor)
        }
    }

    private func benefitBadge(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(cardSecondaryTextColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(primaryAccent.opacity(isDarkModeActive ? 0.14 : 0.08))
            )
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

    private var editorBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(isDarkModeActive ? Color.white.opacity(0.08) : Color.white.opacity(0.82))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(primaryAccent.opacity(isDarkModeActive ? 0.22 : 0.12), lineWidth: 1)
            )
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
}
private struct PreferredDynamicTypeModifier: ViewModifier {
    let preferLargeText: Bool
    let preferredSize: DynamicTypeSize
    let normalRange: ClosedRange<DynamicTypeSize>

    @ViewBuilder
    func body(content: Content) -> some View {
        if preferLargeText {
            content.dynamicTypeSize(preferredSize)
        } else {
            content.dynamicTypeSize(normalRange)
        }
    }
}

