import Foundation
import SwiftUI
import TinyKit

// MARK: - Data Model

enum TaskStatus: Equatable {
    case pending
    case done(String?)      // completion date
    case cancelled(String?) // cancellation date
}

enum ItemKind: Equatable {
    case section(String)
    case task(String, TaskStatus)
    case checklist(String, Bool)  // title, isDone — lightweight sub-item
    case note(String)             // annotation line on preceding task
}

struct ListItem: Identifiable, Equatable {
    let id: UUID
    var kind: ItemKind
    var startDate: String?
    var dueDate: String?

    init(id: UUID = UUID(), kind: ItemKind, startDate: String? = nil, dueDate: String? = nil) {
        self.id = id
        self.kind = kind
        self.startDate = startDate
        self.dueDate = dueDate
    }

    var title: String {
        get {
            switch kind {
            case .section(let t): return t
            case .task(let t, _): return t
            case .checklist(let t, _): return t
            case .note(let t): return t
            }
        }
        set {
            switch kind {
            case .section: kind = .section(newValue)
            case .task(_, let status): kind = .task(newValue, status)
            case .checklist(_, let done): kind = .checklist(newValue, done)
            case .note: kind = .note(newValue)
            }
        }
    }

    var isDone: Bool {
        switch kind {
        case .task(_, .done): return true
        case .checklist(_, let done): return done
        default: return false
        }
    }

    var isCancelled: Bool {
        if case .task(_, .cancelled) = kind { return true }
        return false
    }

    var completionDate: String? {
        if case .task(_, .done(let date)) = kind { return date }
        return nil
    }

    var isSection: Bool {
        if case .section = kind { return true }
        return false
    }

    var isTask: Bool {
        if case .task = kind { return true }
        return false
    }

    var isChecklist: Bool {
        if case .checklist = kind { return true }
        return false
    }

    var isNote: Bool {
        if case .note = kind { return true }
        return false
    }

    /// Whether this item is "active" (not done, not cancelled)
    var isActive: Bool {
        switch kind {
        case .task(_, .pending): return true
        case .checklist(_, false): return true
        default: return false
        }
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

    private static let spotlightDomain = "com.tinyapps.tinytask.files"

    init() {
        super.init(
            bookmarkKey: "lastFolderBookmark",
            defaultExtension: "md",
            supportedExtensions: ["md", "markdown", "txt", "text", "todo"]
        )
    }

    override func didOpenFile(_ url: URL) {
        let summary = items.filter { $0.isTask }.prefix(5).map { $0.title }.joined(separator: ", ")
        SpotlightIndexer.index(file: url, content: content, domainID: Self.spotlightDomain, displayName: summary.isEmpty ? nil : summary)
    }

    override func didSaveFile(_ url: URL) {
        didOpenFile(url)
    }

    // MARK: - Export HTML

    var exportHTML: String {
        var rows = ""
        for item in items {
            switch item.kind {
            case .section(let title):
                let escaped = ExportManager.escapeHTML(title)
                rows += "<tr><td colspan=\"3\" class=\"section\">\(escaped)</td></tr>"
            case .task(let title, let status):
                let escaped = ExportManager.escapeHTML(title)
                let checkbox: String
                let cls: String
                switch status {
                case .pending: checkbox = "☐"; cls = ""
                case .done: checkbox = "☑"; cls = " class=\"task done\""
                case .cancelled: checkbox = "☒"; cls = " class=\"task cancelled\""
                }
                var meta = ""
                if let due = item.dueDate { meta += " <span class=\"due\">due \(ExportManager.escapeHTML(due))</span>" }
                rows += "<tr\(cls)><td>\(checkbox)</td><td>\(escaped)</td><td>\(meta)</td></tr>"
            case .checklist(let title, let done):
                let escaped = ExportManager.escapeHTML(title)
                let checkbox = done ? "☑" : "☐"
                let cls = done ? " class=\"task done\"" : ""
                rows += "<tr\(cls)><td style=\"padding-left:24px\">\(checkbox)</td><td>\(escaped)</td><td></td></tr>"
            case .note(let text):
                let escaped = ExportManager.escapeHTML(text)
                rows += "<tr class=\"note\"><td></td><td colspan=\"2\">\(escaped)</td></tr>"
            }
        }
        let body = "<table><tbody>\(rows)</tbody></table>"
        let title = selectedFile?.lastPathComponent ?? "tasks"
        return ExportManager.wrapHTML(body: body, title: title)
    }

    // MARK: - Parse

    /// Matches `@tag(value)` inline tags
    private static let inlineTagPattern = try! NSRegularExpression(pattern: #"\s*@(\w+)\(([^)]*)\)"#)

    /// Parse all inline @tags from a task line, returning (cleanTitle, tags dict)
    private func parseInlineTags(_ raw: String) -> (String, [String: String]) {
        var tags: [String: String] = [:]
        let range = NSRange(raw.startIndex..., in: raw)
        let matches = Self.inlineTagPattern.matches(in: raw, range: range)

        var title = raw
        // Remove tags from end to start to preserve indices
        for match in matches.reversed() {
            let keyRange = Range(match.range(at: 1), in: raw)!
            let valRange = Range(match.range(at: 2), in: raw)!
            tags[String(raw[keyRange])] = String(raw[valRange])
            let fullRange = Range(match.range, in: raw)!
            title.removeSubrange(fullRange)
        }
        return (title, tags)
    }

    func parseContent() {
        let lines = content.components(separatedBy: "\n")
        var newItems: [ListItem] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Section header
            if trimmed.hasPrefix("# ") {
                let title = String(trimmed.dropFirst(2))
                if !title.isEmpty {
                    newItems.append(ListItem(kind: .section(title)))
                }
            }
            // Indented note: `    > text`
            else if line.hasPrefix("    > ") || line.hasPrefix("\t> ") {
                let text = line.hasPrefix("    > ")
                    ? String(line.dropFirst(6))
                    : String(line.dropFirst(3))
                newItems.append(ListItem(kind: .note(text)))
            }
            // Indented checklist: `    - [ ] ` or `    - [x] `
            else if line.hasPrefix("    - [ ] ") || line.hasPrefix("\t- [ ] ") {
                let text = line.hasPrefix("    - [ ] ")
                    ? String(line.dropFirst(10))
                    : String(line.dropFirst(8))
                newItems.append(ListItem(kind: .checklist(text, false)))
            }
            else if line.hasPrefix("    - [x] ") || line.hasPrefix("    - [X] ")
                 || line.hasPrefix("\t- [x] ") || line.hasPrefix("\t- [X] ") {
                let text = (line.hasPrefix("    - [x] ") || line.hasPrefix("    - [X] "))
                    ? String(line.dropFirst(10))
                    : String(line.dropFirst(8))
                newItems.append(ListItem(kind: .checklist(text, true)))
            }
            // Done task: `- [x] `
            else if trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("- [X] ") {
                let raw = String(trimmed.dropFirst(6))
                let (title, tags) = parseInlineTags(raw)
                newItems.append(ListItem(
                    kind: .task(title, .done(tags["done"])),
                    startDate: tags["start"],
                    dueDate: tags["due"]
                ))
            }
            // Cancelled task: `- [-] `
            else if trimmed.hasPrefix("- [-] ") {
                let raw = String(trimmed.dropFirst(6))
                let (title, tags) = parseInlineTags(raw)
                newItems.append(ListItem(
                    kind: .task(title, .cancelled(tags["cancelled"])),
                    startDate: tags["start"],
                    dueDate: tags["due"]
                ))
            }
            // Pending task: `- [ ] `
            else if trimmed.hasPrefix("- [ ] ") {
                let raw = String(trimmed.dropFirst(6))
                let (title, tags) = parseInlineTags(raw)
                newItems.append(ListItem(
                    kind: .task(title, .pending),
                    startDate: tags["start"],
                    dueDate: tags["due"]
                ))
            }
            // Preserve unrecognized lines as-is (don't drop them)
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

            case .task(let title, let status):
                let checkbox: String
                switch status {
                case .pending: checkbox = "[ ]"
                case .done: checkbox = "[x]"
                case .cancelled: checkbox = "[-]"
                }
                var line = "- \(checkbox) \(title)"
                // Append inline tags
                if let s = item.startDate { line += " @start(\(s))" }
                if let d = item.dueDate { line += " @due(\(d))" }
                switch status {
                case .done(let date):
                    if let d = date { line += " @done(\(d))" }
                case .cancelled(let date):
                    if let d = date { line += " @cancelled(\(d))" }
                case .pending: break
                }
                lines.append(line)

            case .checklist(let title, let done):
                let checkbox = done ? "[x]" : "[ ]"
                lines.append("    - \(checkbox) \(title)")

            case .note(let text):
                lines.append("    > \(text)")
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
        guard items.indices.contains(index) else { return }
        switch items[index].kind {
        case .task(let title, let status):
            switch status {
            case .pending:
                items[index].kind = .task(title, .done(Self.todayString()))
            case .done:
                items[index].kind = .task(title, .pending)
            case .cancelled:
                items[index].kind = .task(title, .pending)
            }
        case .checklist(let title, let done):
            items[index].kind = .checklist(title, !done)
        default: return
        }
        serializeItems()
    }

    func cancelTask(at index: Int) {
        guard items.indices.contains(index),
              case .task(let title, let status) = items[index].kind else { return }
        switch status {
        case .cancelled:
            items[index].kind = .task(title, .pending)
        default:
            items[index].kind = .task(title, .cancelled(Self.todayString()))
        }
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
        items.insert(ListItem(kind: .task("", .pending)), at: clamped)
        selectedIndex = clamped
        startEdit(at: clamped)
        serializeItems()
    }

    func addChecklist(after index: Int?) {
        let insertAt: Int
        if let idx = index {
            insertAt = idx + 1
        } else {
            insertAt = items.count
        }
        let clamped = min(insertAt, items.count)
        items.insert(ListItem(kind: .checklist("", false)), at: clamped)
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

    override func openFile() {
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
        if let data = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(data, forKey: Self.fileBookmarkKey)
        }
    }

    func restoreLastFile() {
        guard let data = UserDefaults.standard.data(forKey: Self.fileBookmarkKey) else { return }
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: [], bookmarkDataIsStale: &isStale) else { return }
        if isStale { saveFileBookmark(url) }
        loadTaskFile(url)
    }

    // MARK: - Stats

    var totalTasks: Int {
        items.filter { $0.isTask }.count
    }

    var doneTasks: Int {
        items.filter { $0.isTask && $0.isDone }.count
    }

    var cancelledTasks: Int {
        items.filter { $0.isCancelled }.count
    }

    var sectionCount: Int {
        items.filter { $0.isSection }.count
    }

    var overdueTasks: Int {
        let today = Self.todayString()
        return items.filter { item in
            guard item.isTask, !item.isDone, !item.isCancelled,
                  let due = item.dueDate else { return false }
            return due < today
        }.count
    }

    /// Returns (done, total) task counts for items under a section at the given index
    func sectionProgress(at sectionIndex: Int) -> (Int, Int) {
        var done = 0, total = 0
        for i in (sectionIndex + 1)..<items.count {
            if items[i].isSection { break }
            if items[i].isTask {
                total += 1
                if items[i].isDone || items[i].isCancelled { done += 1 }
            }
        }
        return (done, total)
    }
}
