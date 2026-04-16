import SwiftUI
import SwiftData
import UIKit

@main
struct SimpilyfAIApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var subscriptionManager = SubscriptionManager()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let persistentStoreURL = storeURL()
        let modelConfiguration = ModelConfiguration(schema: schema, url: persistentStoreURL)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            clearPersistentStore(at: persistentStoreURL)

            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer after resetting the store: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(subscriptionManager)
        }
        .modelContainer(sharedModelContainer)
    }

    private static func storeURL() -> URL {
        let applicationSupportURL = URL.applicationSupportDirectory
        let directoryURL = applicationSupportURL.appending(path: "SimplifAI", directoryHint: .isDirectory)

        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL.appending(path: "SimplifAI.store")
    }

    private static func clearPersistentStore(at url: URL) {
        let fileManager = FileManager.default
        let relatedURLs = [
            url,
            URL(fileURLWithPath: url.path + "-shm"),
            URL(fileURLWithPath: url.path + "-wal")
        ]

        for relatedURL in relatedURLs where fileManager.fileExists(atPath: relatedURL.path) {
            try? fileManager.removeItem(at: relatedURL)
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        UIDevice.current.userInterfaceIdiom == .pad ? .all : .portrait
    }
}
