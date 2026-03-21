import SwiftUI
import AppKit
import TinyKit

// MARK: - FocusedValue key for per-window AppState

struct FocusedAppStateKey: FocusedValueKey {
    typealias Value = AppState
}

extension FocusedValues {
    var appState: AppState? {
        get { self[FocusedAppStateKey.self] }
        set { self[FocusedAppStateKey.self] = newValue }
    }
}

// MARK: - App

@main
struct TinyTaskApp: App {
    @NSApplicationDelegateAdaptor(TinyAppDelegate.self) var appDelegate
    @FocusedValue(\.appState) private var activeState

    var body: some Scene {
        WindowGroup(id: "editor") {
            WindowContentView()
                .frame(minWidth: 400, minHeight: 300)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New List\u{2026}") {
                    activeState?.newList()
                }
                .keyboardShortcut("n", modifiers: .command)

                NewWindowButton()
            }

            CommandGroup(replacing: .appInfo) {
                Button("About TinyTask") {
                    NSApp.orderFrontStandardAboutPanel()
                }
                Button("Welcome to TinyTask") {
                    NotificationCenter.default.post(name: .showWelcome, object: nil)
                }
            }

            CommandGroup(after: .newItem) {
                Button("Open File\u{2026}") {
                    activeState?.openFile()
                }
                .keyboardShortcut("o", modifiers: .command)

                Divider()

                Button("Save") {
                    activeState?.save()
                }
                .keyboardShortcut("s", modifiers: .command)

                Divider()

                ExportPDFButton()
                ExportHTMLButton()

                Divider()

                CopyRichTextButton()
            }
        }
    }
}

// MARK: - Window Content

struct WindowContentView: View {
    @State private var state = AppState()
    @State private var showWelcome = false

    var body: some View {
        ContentView(state: state)
            .navigationTitle(state.selectedFile?.lastPathComponent ?? "TinyTask")
            .focusedSceneValue(\.appState, state)
            .onAppear {
                if !TinyAppDelegate.pendingFiles.isEmpty {
                    let files = TinyAppDelegate.pendingFiles
                    TinyAppDelegate.pendingFiles.removeAll()
                    if let url = files.first {
                        state.loadTaskFile(url)
                    }
                } else if WelcomeState.isFirstLaunch {
                    showWelcome = true
                } else {
                    state.restoreLastFile()
                }

                TinyAppDelegate.onOpenFiles = { [weak state] urls in
                    guard let state, let url = urls.first else { return }
                    state.loadTaskFile(url)
                }
            }
            .welcomeSheet(
                isPresented: $showWelcome,
                appName: "TinyTask",
                subtitle: "A structured task editor",
                features: [
                    ("checklist", "Plain Text Tasks", "Your tasks live in a simple .md file you own forever."),
                    ("keyboard", "Keyboard-First", "Navigate, toggle, add, and reorder without touching the mouse."),
                    ("bolt.fill", "Auto-Save", "Changes saved automatically as you work."),
                ],
                onOpen: { state.openFile() },
                onDismiss: { state.newList() }
            )
            .background(WindowCloseGuard(state: state))
    }
}

// MARK: - Menu Buttons

struct NewWindowButton: View {
    @Environment(\.openWindow) var openWindow

    var body: some View {
        Button("New Window") {
            openWindow(id: "editor")
        }
        .keyboardShortcut("n", modifiers: [.command, .shift])
    }
}

// MARK: - Export Buttons

struct ExportPDFButton: View {
    @FocusedValue(\.appState) private var state

    var body: some View {
        Button("Export as PDF\u{2026}") {
            guard let state else { return }
            let name = state.selectedFile?.lastPathComponent ?? "tasks.md"
            ExportManager.exportPDF(html: state.exportHTML, suggestedName: name)
        }
        .keyboardShortcut("e", modifiers: [.command, .shift])
        .disabled(state == nil)
    }
}

struct ExportHTMLButton: View {
    @FocusedValue(\.appState) private var state

    var body: some View {
        Button("Export as HTML\u{2026}") {
            guard let state else { return }
            let name = state.selectedFile?.lastPathComponent ?? "tasks.md"
            ExportManager.exportHTML(html: state.exportHTML, suggestedName: name)
        }
        .disabled(state == nil)
    }
}

struct CopyRichTextButton: View {
    @FocusedValue(\.appState) private var state

    var body: some View {
        Button("Copy as Rich Text") {
            guard let state else { return }
            ExportManager.copyAsRichText(body: state.exportHTML)
        }
        .keyboardShortcut("c", modifiers: [.command, .option])
        .disabled(state == nil)
    }
}
