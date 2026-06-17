import SwiftData
import SwiftUI

@main
struct LeetCardsApp: App {
    private let container: ModelContainer
    private let problems: [Problem]
    private let loadError: String?

    #if os(macOS)
    // Ensures the app activates and its window becomes key — needed when run as
    // a bare executable via `swift run` (no .app bundle), otherwise the window
    // never takes keyboard focus and text fields can't be typed into.
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif

    init() {
        // Load the bundled dataset (forward-compatible decoding).
        do {
            problems = try DatasetLoader().load().problems
            loadError = nil
        } catch {
            problems = []
            loadError = error.localizedDescription
        }

        // Persistent store, with an in-memory fallback so the app still runs if
        // the on-disk store can't be opened.
        if let onDisk = try? Self.makeContainer() {
            container = onDisk
        } else {
            container = try! Self.makeInMemoryContainer()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(problems: problems, loadError: loadError)
                .modelContainer(container)
        }
    }

    @MainActor private static func makeContainer() throws -> ModelContainer {
        try PersistenceStore.makeContainer()
    }

    @MainActor private static func makeInMemoryContainer() throws -> ModelContainer {
        try PersistenceStore.makeInMemoryContainer()
    }
}

#if os(macOS)
import AppKit

/// Activates the app on launch so its window becomes key and accepts keyboard
/// input — required when launched via `swift run` (no .app bundle).
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
#endif

/// Builds the `DeckStore` once the SwiftData context is available, and routes to
/// the deck, a load-error state, or a brief loading state.
struct RootView: View {
    let problems: [Problem]
    let loadError: String?

    @Environment(\.modelContext) private var modelContext
    @State private var store: DeckStore?

    var body: some View {
        Group {
            if let loadError {
                ContentUnavailableView {
                    Label("Couldn't load problems", systemImage: "tray.and.arrow.down")
                } description: {
                    Text(loadError)
                }
            } else if let store {
                DeckView(store: store, graderNotice: GraderFactory.availabilityMessage())
            } else {
                ProgressView("Loading…")
            }
        }
        .task {
            guard store == nil, loadError == nil else { return }
            store = DeckStore(
                problems: problems,
                context: modelContext,
                grader: GraderFactory.makeGrader()
            )
        }
    }
}
