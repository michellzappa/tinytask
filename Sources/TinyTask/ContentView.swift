import SwiftUI
import TinyKit

struct ContentView: View {
    @Bindable var state: AppState
    @State private var eventMonitor: Any?

    var body: some View {
        VStack(spacing: 0) {
            if state.selectedFile == nil {
                emptyState
            } else if state.items.isEmpty {
                emptyFileState
            } else {
                taskList
            }

            if state.selectedFile != nil {
                taskStatusBar
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .onAppear { installKeyboardMonitor() }
        .onDisappear { removeKeyboardMonitor() }
        .onChange(of: state.content) { _, _ in
            state.contentDidChange()
        }
    }

    // MARK: - Task List

    private var taskList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(state.items.enumerated()), id: \.element.id) { index, item in
                        TaskRowView(
                            item: item,
                            isSelected: state.selectedIndex == index,
                            isEditing: state.editingIndex == index,
                            editText: state.editingIndex == index ? $state.editText : .constant(""),
                            onToggle: { state.toggleTask(at: index) },
                            onCommitEdit: { state.commitEdit() },
                            onCancelEdit: { state.cancelEdit() },
                            onSelect: {
                                state.selectedIndex = index
                                if state.editingIndex != nil && state.editingIndex != index {
                                    state.commitEdit()
                                }
                            },
                            onDoubleClick: {
                                state.selectedIndex = index
                                state.startEdit(at: index)
                            }
                        )
                        .id(item.id)
                    }
                }
                .padding(.vertical, 4)
            }
            .onChange(of: state.selectedIndex) { _, newValue in
                if let idx = newValue, state.items.indices.contains(idx) {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo(state.items[idx].id, anchor: .center)
                    }
                }
            }
        }
    }

    // MARK: - Empty States

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checklist")
                .font(.system(size: 48))
                .foregroundStyle(.quaternary)
            Text("Open a file or create a new list")
                .foregroundStyle(.secondary)
                .font(.system(size: 14))
            HStack(spacing: 12) {
                Button("Open File\u{2026}") { state.openFile() }
                    .controlSize(.large)
                Button("New List\u{2026}") { state.newList() }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyFileState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "text.badge.plus")
                .font(.system(size: 36))
                .foregroundStyle(.quaternary)
            Text("Empty list")
                .foregroundStyle(.secondary)
                .font(.system(size: 14))
            Text("\u{2318}\u{21A9} to add a task  \u{00B7}  \u{21E7}\u{2318}\u{21A9} to add a section")
                .foregroundStyle(.tertiary)
                .font(.system(size: 12, design: .monospaced))
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Status Bar

    private var taskStatusBar: some View {
        HStack(spacing: 16) {
            if state.totalTasks > 0 {
                Text("\(state.totalTasks) task\(state.totalTasks == 1 ? "" : "s")")
                Text("\(state.doneTasks) done")
                if state.sections > 0 {
                    Text("\(state.sections) section\(state.sections == 1 ? "" : "s")")
                }
            }
            Spacer()
            if let file = state.selectedFile {
                Text(file.lastPathComponent)
            }
            if state.isDirty {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 6, height: 6)
            }
        }
        .font(.system(size: 11, design: .monospaced))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 5)
        .background(.bar)
    }

    // MARK: - Keyboard

    private func installKeyboardMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            return handleKeyEvent(event)
        }
    }

    private func removeKeyboardMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
        guard state.selectedFile != nil else { return event }

        // Strip numericPad & function flags — arrow keys set these automatically
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            .subtracting([.numericPad, .function])
        let key = event.keyCode

        // When editing, let TextField handle most keys
        if state.editingIndex != nil {
            // Escape → cancel edit
            if key == 53 {
                state.cancelEdit()
                return nil
            }
            // Cmd+Enter → commit and add new task below
            if key == 36 && flags == .command {
                state.commitEdit()
                state.addTask(after: state.selectedIndex)
                return nil
            }
            // Let TextField handle everything else (including Return for onSubmit)
            return event
        }

        // ↑ Move selection up
        if key == 126 && flags.isEmpty {
            if let idx = state.selectedIndex, idx > 0 {
                state.selectedIndex = idx - 1
            } else if state.selectedIndex == nil && !state.items.isEmpty {
                state.selectedIndex = 0
            }
            return nil
        }

        // ↓ Move selection down
        if key == 125 && flags.isEmpty {
            if let idx = state.selectedIndex, idx < state.items.count - 1 {
                state.selectedIndex = idx + 1
            } else if state.selectedIndex == nil && !state.items.isEmpty {
                state.selectedIndex = 0
            }
            return nil
        }

        // Space → toggle task
        if key == 49 && flags.isEmpty {
            if let idx = state.selectedIndex {
                state.toggleTask(at: idx)
            }
            return nil
        }

        // Return → start editing
        if key == 36 && flags.isEmpty {
            if let idx = state.selectedIndex {
                state.startEdit(at: idx)
            }
            return nil
        }

        // Cmd+Return → new task
        if key == 36 && flags == .command {
            state.addTask(after: state.selectedIndex)
            return nil
        }

        // Cmd+Shift+Return → new section
        if key == 36 && flags == [.command, .shift] {
            state.addSection(after: state.selectedIndex)
            return nil
        }

        // Cmd+↑ → move item up
        if key == 126 && flags == .command {
            if let idx = state.selectedIndex {
                state.moveItem(from: idx, by: -1)
            }
            return nil
        }

        // Cmd+↓ → move item down
        if key == 125 && flags == .command {
            if let idx = state.selectedIndex {
                state.moveItem(from: idx, by: 1)
            }
            return nil
        }

        // Cmd+Backspace → delete item
        if key == 51 && flags == .command {
            if let idx = state.selectedIndex {
                state.deleteItem(at: idx)
            }
            return nil
        }

        // Backspace on empty task → delete
        if key == 51 && flags.isEmpty {
            if let idx = state.selectedIndex,
               !state.items[idx].isSection,
               state.items[idx].title.isEmpty {
                state.deleteItem(at: idx)
                return nil
            }
            // Otherwise start editing (backspace feels like "I want to change this")
            if let idx = state.selectedIndex {
                state.startEdit(at: idx)
                return nil
            }
        }

        // Cmd+= / Cmd+- / Cmd+0 → font size (pass through for system handling)
        if flags == .command && (event.charactersIgnoringModifiers == "=" ||
                                 event.charactersIgnoringModifiers == "+" ||
                                 event.charactersIgnoringModifiers == "-" ||
                                 event.charactersIgnoringModifiers == "0") {
            return event
        }

        // Cmd+F → find (pass through)
        if flags == .command && event.charactersIgnoringModifiers == "f" {
            return event
        }

        return event
    }
}

// MARK: - Task Row View

struct TaskRowView: View {
    let item: ListItem
    let isSelected: Bool
    let isEditing: Bool
    @Binding var editText: String
    let onToggle: () -> Void
    let onCommitEdit: () -> Void
    let onCancelEdit: () -> Void
    let onSelect: () -> Void
    let onDoubleClick: () -> Void

    @FocusState private var textFieldFocused: Bool

    var body: some View {
        Group {
            switch item.kind {
            case .section(let title):
                sectionRow(title)
            case .task(let title, let done, let date):
                taskRow(title, done: done, completionDate: date)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
                .padding(.horizontal, 8)
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { onDoubleClick() }
        .onTapGesture(count: 1) { onSelect() }
    }

    // MARK: - Section Row

    @ViewBuilder
    private func sectionRow(_ title: String) -> some View {
        HStack(spacing: 0) {
            if isEditing {
                TextField("Section name", text: $editText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .bold))
                    .focused($textFieldFocused)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            textFieldFocused = true
                        }
                    }
                    .onSubmit { onCommitEdit() }
            } else {
                Text(title.isEmpty ? " " : title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.primary)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 7)
        .padding(.top, 10)
    }

    // MARK: - Task Row

    @ViewBuilder
    private func taskRow(_ title: String, done: Bool, completionDate: String?) -> some View {
        HStack(spacing: 8) {
            Button(action: onToggle) {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(done ? .secondary : Color.accentColor)
            }
            .buttonStyle(.plain)
            .frame(width: 20)

            if isEditing {
                TextField("Task", text: $editText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($textFieldFocused)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            textFieldFocused = true
                        }
                    }
                    .onSubmit { onCommitEdit() }
            } else {
                Text(title.isEmpty ? " " : title)
                    .font(.system(size: 13))
                    .foregroundStyle(done ? .secondary : .primary)
                    .strikethrough(done, color: .secondary)
            }
            Spacer()
            if done, let date = completionDate {
                Text(date)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 5)
    }
}
