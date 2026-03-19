import Foundation
import SwiftUI
import TinyKit

// MARK: - Data Model

enum ItemKind: Equatable {
    case section(String)
    /// task(title, isDone, completionDate)
    case task(String, Bool, String?)
}

struct ListItem: Identifiable, Equatable {
    let id: UUID
    var kind: ItemKind

    init(id: UUID = UUID(), kind: ItemKind) {
        self.id = id
        self.kind = kind
    }

    var title: String {
        get {
            switch kind {
            case .section(let t): return t
            case .task(let t, _, _): return t
            }
        }
        set {
            switch kind {
            case .section: kind = .section(newValue)
            case .task(_, let done, let date): kind = .task(newValue, done, date)
            }
        }
    }

    var isDone: Bool {
        if case .task(_, let done, _) = kind { return done }
        return false
    }

    var completionDate: String? {
        if case .task(_, _, let date) = kind { return date }
        return nil
    }

    var isSection: Bool {
        if case .section = kind { return true }
        return false
    }
}

// MARK: - AppState

@Observable
final class AppState: FileState {

    var items: [ListItem] = []
    var selectedIndex: Int? = nil
    var editingIndex: Int? = nil
    var editText: String = ""

    /// Tracks the last content we serialized, so we can skip re-parsing our own writes
    private var lastSerializedContent: String = ""

    /// Bookmark key for restoring the last opened file
    private static let fileBookmarkKey = "lastFileBookmark"

    init() {
        super.init(
            bookmarkKey: "lastFolderBookmark",
            defaultExtension: "md",
            supportedExtensions: ["md", "markdown", "txt", "text", "todo"]
        )
    }

    // MARK: - Parse

    /// Matches ` @done(YYYY-MM-DD)` at end of line
    private static let doneTagPattern = try! NSRegularExpression(pattern: #"\s*@done\((\d{4}-\d{2}-\d{2})\)\s*$"#)

    /// Extract title and optional completion date from a done-task line
    private func parseDoneTag(_ raw: String) -> (String, String?) {
        let range = NSRange(raw.startIndex..., in: raw)
        if let match = Self.doneTagPattern.firstMatch(in: raw, range: range) {
            let dateRange = Range(match.range(at: 1), in: raw)!
            let date = String(raw[dateRange])
            let titleEnd = raw.index(raw.startIndex, offsetBy: match.range.location)
            let title = String(raw[raw.startIndex..<titleEnd])
            return (title, date)
        }
        return (raw, nil)
    }

    func parseContent() {
        let lines = content.components(separatedBy: "\n")
        var newItems: [ListItem] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("# ") {
                let title = String(trimmed.dropFirst(2))
                if !title.isEmpty {
                    newItems.append(ListItem(kind: .section(title)))
                }
            } else if trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("- [X] ") {
                let raw = String(trimmed.dropFirst(6))
                let (title, date) = parseDoneTag(raw)
                newItems.append(ListItem(kind: .task(title, true, date)))
            } else if trimmed.hasPrefix("- [ ] ") {
                let title = String(trimmed.dropFirst(6))
                newItems.append(ListItem(kind: .task(title, false, nil)))
            }
            // Unrecognized lines are dropped (normalize on load)
        }

        items = newItems
        lastSerializedContent = content

        // Clamp selection
        if let sel = selectedIndex {
            if items.isEmpty {
                selectedIndex = nil
            } else if sel >= items.count {
                selectedIndex = items.count - 1
            }
        }
    }

    // MARK: - Serialize

    private static let todayString: () -> String = {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return { fmt.string(from: Date()) }
    }()

    func serializeItems() {
        var lines: [String] = []

        for (i, item) in items.enumerated() {
            switch item.kind {
            case .section(let title):
                if i > 0 { lines.append("") }
                lines.append("# \(title)")
            case .task(let title, let done, let date):
                let checkbox = done ? "[x]" : "[ ]"
                var line = "- \(checkbox) \(title)"
                if done, let d = date {
                    line += " @done(\(d))"
                }
                lines.append(line)
            }
        }

        let serialized = lines.joined(separator: "\n")
        lastSerializedContent = serialized
        content = serialized
    }

    // MARK: - Content change detection (called from view's onChange)

    func contentDidChange() {
        guard content != lastSerializedContent else { return }
        parseContent()
    }

    // MARK: - Task Operations

    func toggleTask(at index: Int) {
        guard items.indices.contains(index),
              case .task(let title, let done, _) = items[index].kind else { return }
        let newDone = !done
        let date = newDone ? Self.todayString() : nil
        items[index].kind = .task(title, newDone, date)
        serializeItems()
    }

    func addTask(after index: Int?) {
        let insertAt: Int
        if let idx = index {
            insertAt = idx + 1
        } else {
            insertAt = items.count
        }
        let clamped = min(insertAt, items.count)
        items.insert(ListItem(kind: .task("", false, nil)), at: clamped)
        selectedIndex = clamped
        startEdit(at: clamped)
        serializeItems()
    }

    func addSection(after index: Int?) {
        let insertAt: Int
        if let idx = index {
            insertAt = idx + 1
        } else {
            insertAt = items.count
        }
        let clamped = min(insertAt, items.count)
        items.insert(ListItem(kind: .section("")), at: clamped)
        selectedIndex = clamped
        startEdit(at: clamped)
        serializeItems()
    }

    func deleteItem(at index: Int) {
        guard items.indices.contains(index) else { return }
        items.remove(at: index)
        if items.isEmpty {
            selectedIndex = nil
        } else if let sel = selectedIndex {
            selectedIndex = min(sel, items.count - 1)
        }
        serializeItems()
    }

    func moveItem(from index: Int, by offset: Int) {
        let newIndex = index + offset
        guard items.indices.contains(index), items.indices.contains(newIndex) else { return }
        items.swapAt(index, newIndex)
        selectedIndex = newIndex
        serializeItems()
    }

    // MARK: - Editing

    func startEdit(at index: Int) {
        guard items.indices.contains(index) else { return }
        editingIndex = index
        editText = items[index].title
    }

    func commitEdit() {
        guard let idx = editingIndex, items.indices.contains(idx) else {
            editingIndex = nil
            return
        }
        let trimmed = editText.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            // Delete empty items on commit
            items.remove(at: idx)
            editingIndex = nil
            if items.isEmpty {
                selectedIndex = nil
            } else {
                selectedIndex = min(idx, items.count - 1)
            }
        } else {
            items[idx].title = trimmed
            editingIndex = nil
        }
        serializeItems()
    }

    func cancelEdit() {
        guard let idx = editingIndex else { return }
        // If the item was newly created and still empty, delete it
        if items.indices.contains(idx) && items[idx].title.isEmpty {
            items.remove(at: idx)
            if items.isEmpty {
                selectedIndex = nil
            } else {
                selectedIndex = min(idx, items.count - 1)
            }
            serializeItems()
        }
        editingIndex = nil
        editText = ""
    }

    // MARK: - File Operations

    func openFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.plainText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        loadTaskFile(url)
    }

    func loadTaskFile(_ url: URL) {
        let folder = url.deletingLastPathComponent()
        if folderURL != folder {
            folderURL = folder
        }
        selectFile(url)
        parseContent()
        if !items.isEmpty && selectedIndex == nil {
            selectedIndex = 0
        }
        saveFileBookmark(url)
    }

    func newList() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "tasks.md"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let defaultContent = "# Tasks\n- [ ] First task\n"
        try? defaultContent.write(to: url, atomically: true, encoding: .utf8)
        loadTaskFile(url)
    }

    // MARK: - File Bookmark Persistence

    private func saveFileBookmark(_ url: URL) {
        if let data = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(data, forKey: Self.fileBookmarkKey)
        }
    }

    func restoreLastFile() {
        guard let data = UserDefaults.standard.data(forKey: Self.fileBookmarkKey) else { return }
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope, bookmarkDataIsStale: &isStale) else { return }
        guard url.startAccessingSecurityScopedResource() else { return }
        if isStale { saveFileBookmark(url) }
        loadTaskFile(url)
    }

    // MARK: - Stats

    var totalTasks: Int {
        items.filter { !$0.isSection }.count
    }

    var doneTasks: Int {
        items.filter { $0.isDone }.count
    }

    var sections: Int {
        items.filter { $0.isSection }.count
    }
}
