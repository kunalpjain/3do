import Foundation
import SwiftUI
import AppKit
import GRDB
import ThreeDoCore

@MainActor
class AppState: ObservableObject {
    @Published var workspaces: [Workspace] = []
    @Published var currentWorkspaceIndex: Int = 0
    @Published var todos: [Todo] = []
    @Published var flatTodos: [FlatTodo] = []
    @Published var selectedId: UUID? = nil
    @Published var editingId: UUID? = nil
    @Published var editText: String = ""
    @Published var isSearching: Bool = false
    @Published var searchText: String = ""
    @Published var isShowingHelp: Bool = false
    @Published var dueDatePickerId: UUID? = nil
    @Published var tagsSheetId: UUID? = nil
    @Published var anchorId: UUID? = nil         // non-nil during shift-selection
    @Published var renamingWorkspaceId: UUID? = nil
    @Published var renameWorkspaceText: String = ""

    /// All IDs currently highlighted (single or range).
    var allSelectedIds: Set<UUID> {
        guard let anchor = anchorId, let current = selectedId else {
            return selectedId.map { [$0] } ?? []
        }
        guard let ai = flatTodos.firstIndex(where: { $0.id == anchor }),
              let ci = flatTodos.firstIndex(where: { $0.id == current }) else {
            return selectedId.map { [$0] } ?? []
        }
        let lo = min(ai, ci), hi = max(ai, ci)
        return Set(flatTodos[lo...hi].map { $0.id })
    }

    private(set) var db: AppDatabase
    private var observationTask: Task<Void, Never>?
    private var pendingEditId: UUID? = nil
    private var keyMonitor: Any?
    private var undoStack: [UndoAction] = []
    private var editingOriginalText: String = ""

    init() {
        db = try! AppDatabase()
        installKeyMonitor()
        Task { await setup() }
    }

    deinit {
        if let m = keyMonitor { NSEvent.removeMonitor(m) }
        observationTask?.cancel()
    }

    // MARK: - Keyboard

    /// Virtual key codes for keys used in normal and editing mode (US layout).
    private enum Key {
        static let esc        = UInt16(53)
        static let `return`   = UInt16(36)
        static let tab        = UInt16(48)
        static let space      = UInt16(49)
        static let delete     = UInt16(51)
        static let arrowUp    = UInt16(126)
        static let arrowDown  = UInt16(125)
        static let arrowLeft  = UInt16(123)
        static let arrowRight = UInt16(124)
        // Letter keys (physical key positions, US layout)
        static let d = UInt16(2);  static let f = UInt16(3);  static let h = UInt16(4)
        static let z = UInt16(6);  static let t = UInt16(17); static let i = UInt16(34)
        static let p = UInt16(35); static let l = UInt16(37); static let j = UInt16(38)
        static let k = UInt16(40); static let n = UInt16(45)
    }

    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            // NSEvent callbacks run on the main thread — the main actor's executor.
            let consumed = MainActor.assumeIsolated { self.handleKeyEvent(event) }
            return consumed ? nil : event
        }
    }

    func handleKeyEvent(_ event: NSEvent) -> Bool {
        if isShowingHelp {
            if event.keyCode == Key.esc { isShowingHelp = false; return true }
            return false
        }
        // Modal sheets (due date, tags, rename) handle their own keyboard input.
        // Return false so arrow keys, letters, etc. reach the sheet uninterrupted.
        if TodoLogic.isModalSheetOpen(
            dueDatePickerId: dueDatePickerId,
            tagsSheetId: tagsSheetId,
            renamingWorkspaceId: renamingWorkspaceId
        ) { return false }
        if editingId != nil { return handleEditingModeKey(event) }
        return handleNormalModeKey(event)
    }

    private func handleEditingModeKey(_ event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) { return false }
        switch event.keyCode {
        case Key.esc:   // Esc — commit, stay on todo
            commitEdit()
            return true
        case Key.tab:   // Tab — commit then indent/unindent
            let eid = editingId
            commitEdit()
            if let id = eid {
                event.modifierFlags.contains(.shift) ? unindentTodo(id: id) : indentTodo(id: id)
            }
            return true
        default:
            return false // let TextField handle it
        }
    }

    private func handleNormalModeKey(_ event: NSEvent) -> Bool {
        let cmd  = event.modifierFlags.contains(.command)
        let shft = event.modifierFlags.contains(.shift)

        if cmd {
            switch event.keyCode {
            case Key.arrowDown: if let id = selectedId { moveTodo(id: id, direction: .down) }; return true  // Cmd+↓
            case Key.arrowUp:   if let id = selectedId { moveTodo(id: id, direction: .up) };   return true  // Cmd+↑
            case Key.f:         isSearching = true; return true                                             // Cmd+F
            case Key.z:         undo();             return true                                             // Cmd+Z
            default:            return false
            }
        }

        switch event.keyCode {
        case Key.esc:               isShowingHelp = false; return false                         // Esc — no-op in normal mode
        case Key.arrowDown, Key.j:  // ↓ or j
            if shft { selectNextExtending() } else { anchorId = nil; selectNext() }
            return true
        case Key.arrowUp, Key.k:    // ↑ or k
            if shft { selectPrevExtending() } else { anchorId = nil; selectPrev() }
            return true
        case Key.i, Key.return:     // i or Enter — edit mode
            if let id = selectedId { anchorId = nil; startEditing(id: id) }
            return selectedId != nil
        case Key.n:                 // n — new todo
            anchorId = nil; addTodo(after: selectedId); return true
        case Key.p:                 // p — cycle priority
            if let id = selectedId { cyclePriority(id: id) }
            return selectedId != nil
        case Key.d:                 // d — set due date
            if let id = selectedId { dueDatePickerId = id }
            return selectedId != nil
        case Key.t:                 // t — edit tags
            if let id = selectedId { tagsSheetId = id }
            return selectedId != nil
        case Key.space:             // Space — toggle done
            if let id = selectedId { toggleDone(id: id) }
            return selectedId != nil
        case Key.delete:            // Backspace — delete (multi or single)
            let ids = allSelectedIds
            if !ids.isEmpty { bulkDelete(ids: ids); return true }
            return false
        case Key.tab:               // Tab — indent / unindent
            if let id = selectedId {
                shft ? unindentTodo(id: id) : indentTodo(id: id)
                return true
            }
            return false
        case Key.arrowLeft, Key.h:  // ← or h — collapse or unindent
            if let id = selectedId {
                if let ft = flatTodos.first(where: { $0.id == id }),
                   ft.hasChildren && !ft.todo.isCollapsed {
                    collapseToggle(id: id)
                } else {
                    unindentTodo(id: id)
                }
                return true
            }
            return false
        case Key.arrowRight, Key.l: // → or l — expand or indent
            if let id = selectedId {
                if let ft = flatTodos.first(where: { $0.id == id }),
                   ft.hasChildren && ft.todo.isCollapsed {
                    collapseToggle(id: id)
                } else {
                    indentTodo(id: id)
                }
                return true
            }
            return false
        default:
            if let chars = event.characters {
                if chars == "?" { isShowingHelp = true; return true }          // ? — help
                if !chars.isEmpty,
                   chars.unicodeScalars.allSatisfy({ $0.value >= 32 }),
                   let id = selectedId {
                    startEditing(id: id, initialChar: chars)
                    return true
                }
            }
            return false
        }
    }

    // MARK: - Edit helpers

    /// Enter edit mode for the given todo, optionally starting with `initialChar` (typed-to-start).
    func startEditing(id: UUID, initialChar: String? = nil) {
        editingOriginalText = flatTodos.first(where: { $0.id == id })?.todo.text ?? ""
        editText  = initialChar ?? editingOriginalText
        editingId = id
    }

    /// Persist the current edit text and exit editing mode.
    func commitEdit() {
        if let id = editingId {
            // If the top of the undo stack is a .create for this same todo, skip
            // pushing .setText — undoing should delete the whole todo, not just clear its text.
            let isJustCreated: Bool
            if case .create(let cid) = undoStack.last, cid == id { isJustCreated = true } else { isJustCreated = false }

            if editText != editingOriginalText && !isJustCreated {
                undoStack.append(.setText(id: id, previousText: editingOriginalText))
            }
            updateText(id: id, text: editText)
        }
        editingId = nil
    }

    // MARK: - Setup

    private func setup() async {
        let loaded = (try? await db.pool.read { db in
            try Workspace
                .filter(Column("deleted_at") == nil)
                .order(Column("position"))
                .fetchAll(db)
        }) ?? []

        if loaded.isEmpty {
            let personal = Workspace(name: "Personal", position: 0)
            let work     = Workspace(name: "Work",     position: 1)
            let p = personal, w = work
            try? await db.pool.write { db in
                try p.insert(db)
                try w.insert(db)
            }
            let welcome = Todo(workspaceId: personal.id, text: "Welcome to 3do! Press j/k or arrows to navigate, Enter to add a todo, i or any key to edit.", position: 1.0)
            let wc = welcome
            try? await db.pool.write { db in try wc.insert(db) }
            workspaces = [personal, work]
        } else {
            workspaces = loaded
        }

        currentWorkspaceIndex = 0
        observeTodos()
    }

    // MARK: - Workspace

    /// Switch to the workspace at `index`, resetting selection and restarting observation.
    func switchWorkspace(to index: Int) {
        currentWorkspaceIndex = max(0, min(index, workspaces.count - 1))
        selectedId = nil
        editingId  = nil
        observeTodos()
    }

    func createWorkspace(name: String) {
        let position = workspaces.count
        let ws = Workspace(name: name, position: position)
        Task {
            try? await db.pool.write { db in try ws.insert(db) }
            let updated = (try? await db.pool.read { db in
                try Workspace.filter(Column("deleted_at") == nil).order(Column("position")).fetchAll(db)
            }) ?? []
            await MainActor.run { self.workspaces = updated }
        }
    }

    var currentWorkspace: Workspace? { workspaces[safe: currentWorkspaceIndex] }

    // MARK: - Todo observation

    func observeTodos() {
        observationTask?.cancel()
        observationTask = nil
        guard let workspace = currentWorkspace else { return }
        let wsId = workspace.id

        let observation = ValueObservation.tracking { db -> [Todo] in
            try Todo
                .filter(Column("workspace_id") == wsId)
                .filter(Column("deleted_at") == nil)
                .order(Column("position"))
                .fetchAll(db)
        }

        observationTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await fetched in observation.values(in: self.db.pool) {
                    await MainActor.run {
                        self.todos = fetched
                        self.updateFlatTodos()
                    }
                }
            } catch { /* cancelled or error */ }
        }
    }

    private func updateFlatTodos() {
        flatTodos = TodoLogic.flatten(todos)
        if let eid = pendingEditId, flatTodos.contains(where: { $0.id == eid }) {
            startEditing(id: eid)
            pendingEditId = nil
        }
    }

    // MARK: - Navigation

    var selectedIndex: Int? { flatTodos.firstIndex(where: { $0.id == selectedId }) }

    func selectNext() {
        guard !flatTodos.isEmpty else { return }
        if let idx = selectedIndex {
            selectedId = flatTodos[min(idx + 1, flatTodos.count - 1)].id
        } else {
            selectedId = flatTodos.first?.id
        }
    }

    func selectPrev() {
        guard !flatTodos.isEmpty else { return }
        if let idx = selectedIndex {
            selectedId = flatTodos[max(idx - 1, 0)].id
        } else {
            selectedId = flatTodos.last?.id
        }
    }

    func selectNextExtending() {
        if anchorId == nil { anchorId = selectedId }
        selectNext()
    }

    func selectPrevExtending() {
        if anchorId == nil { anchorId = selectedId }
        selectPrev()
    }

    // MARK: - Todo CRUD

    /// Insert a new empty todo below `selectedId` and immediately enter edit mode.
    func addTodo(after selectedId: UUID?) {
        guard let workspace = currentWorkspace else { return }

        let parentId: UUID?
        if let sid = selectedId, let sel = todos.first(where: { $0.id == sid }) {
            parentId = sel.parentId
        } else {
            parentId = nil
        }

        let siblings = todos.filter { $0.parentId == parentId && $0.deletedAt == nil }
        let position = TodoLogic.insertPosition(afterId: selectedId, among: siblings)

        let newTodo = Todo(workspaceId: workspace.id, parentId: parentId, text: "", position: position)
        let newId   = newTodo.id
        undoStack.append(.create(id: newId))
        Task {
            try? await db.pool.write { db in try newTodo.insert(db) }
            await MainActor.run {
                self.selectedId    = newId
                self.pendingEditId = newId
            }
        }
    }

    /// Toggle the done state of a todo, pushing an undo action.
    func toggleDone(id: UUID) {
        guard var t = todos.first(where: { $0.id == id }) else { return }
        undoStack.append(.setDone(id: id, previousValue: t.isDone))
        t.isDone.toggle()
        t.updatedAt = Date()
        let snap = t
        Task { try? await db.pool.write { db in try snap.update(db) } }
    }

    /// Soft-delete a todo, pushing an undo action and adjusting the selection.
    func deleteTodo(id: UUID) {
        guard var t = todos.first(where: { $0.id == id }) else { return }
        undoStack.append(.delete(snapshot: t))
        selectedId = TodoLogic.selectionAfterDelete(deletingId: id, in: flatTodos)
        t.deletedAt = Date()
        t.updatedAt = Date()
        let snap = t
        Task { try? await db.pool.write { db in try snap.update(db) } }
    }

    /// Move `todo` under its previous sibling (indent one level deeper).
    func indentTodo(id: UUID) {
        guard let todo = todos.first(where: { $0.id == id }) else { return }
        let siblings  = todos.filter { $0.parentId == todo.parentId && $0.deletedAt == nil }
        let sorted    = siblings.sorted { $0.position < $1.position }
        guard let idx = sorted.firstIndex(where: { $0.id == id }), idx > 0 else { return }
        let newParent = sorted[idx - 1]
        let children  = todos.filter { $0.parentId == newParent.id && $0.deletedAt == nil }
        guard var updated = TodoLogic.applyIndent(to: todo, siblings: siblings, existingChildren: children) else { return }
        updated.updatedAt = Date()
        let snap = updated
        Task { try? await db.pool.write { db in try snap.update(db) } }
    }

    /// Move `todo` out one level (unindent), placing it after its former parent.
    func unindentTodo(id: UUID) {
        guard let todo = todos.first(where: { $0.id == id }),
              let parentId = todo.parentId,
              let parent   = todos.first(where: { $0.id == parentId }) else { return }
        let gps = todos.filter { $0.parentId == parent.parentId && $0.deletedAt == nil }
        guard var updated = TodoLogic.applyUnindent(to: todo, parent: parent, grandparentSiblings: gps) else { return }
        updated.updatedAt = Date()
        let snap = updated
        Task { try? await db.pool.write { db in try snap.update(db) } }
    }

    /// Move `todo` up or down one position among its siblings (Cmd+↑/↓).
    func moveTodo(id: UUID, direction: MoveDirection) {
        guard var todo = todos.first(where: { $0.id == id }) else { return }
        let siblings = todos.filter { $0.parentId == todo.parentId && $0.deletedAt == nil }
        let sorted   = siblings.sorted { $0.position < $1.position }
        guard let idx = sorted.firstIndex(where: { $0.id == id }) else { return }

        switch direction {
        case .up:
            guard idx > 0 else { return }
            var other = sorted[idx - 1]
            swap(&todo.position, &other.position)
            todo.updatedAt  = Date()
            other.updatedAt = Date()
            let s1 = todo, s2 = other
            Task { try? await db.pool.write { db in try s1.update(db); try s2.update(db) } }
        case .down:
            guard idx < sorted.count - 1 else { return }
            var other = sorted[idx + 1]
            swap(&todo.position, &other.position)
            todo.updatedAt  = Date()
            other.updatedAt = Date()
            let s1 = todo, s2 = other
            Task { try? await db.pool.write { db in try s1.update(db); try s2.update(db) } }
        }
    }

    func collapseToggle(id: UUID) {
        guard var t = todos.first(where: { $0.id == id }) else { return }
        t.isCollapsed.toggle()
        t.updatedAt = Date()
        let snap = t
        Task { try? await db.pool.write { db in try snap.update(db) } }
    }

    func updateText(id: UUID, text: String) {
        guard var t = todos.first(where: { $0.id == id }) else { return }
        t.text = text
        t.updatedAt = Date()
        let snap = t
        Task { try? await db.pool.write { db in try snap.update(db) } }
    }

    // MARK: - Bulk delete

    /// Delete all todos in `ids`, adjusting selection and clearing multi-select anchor.
    func bulkDelete(ids: Set<UUID>) {
        selectedId = TodoLogic.selectionAfterBulkDelete(deletingIds: ids, in: flatTodos)
        anchorId = nil
        for id in ids { deleteTodo(id: id) }
    }

    // MARK: - Tags

    /// Persist `rawTags` (space-separated, optional #-prefix) for the given todo, pushing an undo action.
    func setTags(id: UUID, rawTags: String) {
        guard var t = todos.first(where: { $0.id == id }) else { return }
        undoStack.append(.setTags(id: id, previousTags: t.tags))
        t.tags      = TodoLogic.formatTags(TodoLogic.parseTags(rawTags))
        t.updatedAt = Date()
        let snap = t
        Task { try? await db.pool.write { db in try snap.update(db) } }
    }

    var tagsSheetTodo: Todo? {
        guard let id = tagsSheetId else { return nil }
        return todos.first(where: { $0.id == id })
    }

    // MARK: - Workspace rename / delete

    func renameWorkspace(id: UUID, name: String) {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        guard var ws = workspaces.first(where: { $0.id == id }) else { return }
        ws.name = name
        ws.updatedAt = Date()
        let snap = ws
        Task {
            try? await db.pool.write { db in try snap.update(db) }
            let updated = (try? await db.pool.read { db in
                try Workspace.filter(Column("deleted_at") == nil)
                    .order(Column("position")).fetchAll(db)
            }) ?? []
            await MainActor.run { self.workspaces = updated }
        }
    }

    func deleteWorkspace(id: UUID) {
        guard workspaces.count > 1 else { return }   // keep at least one
        guard var ws = workspaces.first(where: { $0.id == id }) else { return }
        ws.deletedAt = Date()
        ws.updatedAt = Date()
        let snap = ws
        Task {
            try? await db.pool.write { db in try snap.update(db) }
            let updated = (try? await db.pool.read { db in
                try Workspace.filter(Column("deleted_at") == nil)
                    .order(Column("position")).fetchAll(db)
            }) ?? []
            await MainActor.run {
                self.workspaces = updated
                self.currentWorkspaceIndex = max(0, min(self.currentWorkspaceIndex, updated.count - 1))
                self.observeTodos()
            }
        }
    }

    // MARK: - Priority

    /// Cycle the priority of a todo (none → low → medium → high → none), pushing an undo action.
    func cyclePriority(id: UUID) {
        guard var t = todos.first(where: { $0.id == id }) else { return }
        undoStack.append(.setPriority(id: id, previousPriority: t.priority))
        t.priority  = TodoLogic.nextPriority(t.priority)
        t.updatedAt = Date()
        let snap = t
        Task { try? await db.pool.write { db in try snap.update(db) } }
    }

    // MARK: - Due date

    /// Set or clear the due date for a todo, pushing an undo action.
    func setDueDate(id: UUID, date: Date?) {
        guard var t = todos.first(where: { $0.id == id }) else { return }
        undoStack.append(.setDueDate(id: id, previousDueDate: t.dueDate))
        t.dueDate   = date
        t.updatedAt = Date()
        let snap = t
        Task { try? await db.pool.write { db in try snap.update(db) } }
    }

    // MARK: - Undo

    /// Pop and reverse the last action on the undo stack.
    func undo() {
        guard let action = undoStack.popLast() else { return }
        switch action {
        case .create(let id):
            guard var t = todos.first(where: { $0.id == id }) else { return }
            selectedId = TodoLogic.selectionAfterDelete(deletingId: id, in: flatTodos)
            t.deletedAt = Date()
            t.updatedAt = Date()
            let snap = t
            Task { try? await db.pool.write { db in try snap.update(db) } }
        case .delete(let snapshot):
            var t = snapshot
            t.deletedAt = nil
            t.updatedAt = Date()
            let snap = t
            Task {
                try? await db.pool.write { db in try snap.upsert(db) }
                await MainActor.run { self.selectedId = snap.id }
            }
        case .setDone(let id, let prev):
            guard var t = todos.first(where: { $0.id == id }) else { return }
            t.isDone    = prev
            t.updatedAt = Date()
            let snap = t
            Task { try? await db.pool.write { db in try snap.update(db) } }
        case .setText(let id, let prev):
            updateText(id: id, text: prev)
        case .setPriority(let id, let prev):
            guard var t = todos.first(where: { $0.id == id }) else { return }
            t.priority  = prev
            t.updatedAt = Date()
            let snap = t
            Task { try? await db.pool.write { db in try snap.update(db) } }
        case .setDueDate(let id, let prev):
            guard var t = todos.first(where: { $0.id == id }) else { return }
            t.dueDate   = prev
            t.updatedAt = Date()
            let snap = t
            Task { try? await db.pool.write { db in try snap.update(db) } }
        case .setTags(let id, let prev):
            guard var t = todos.first(where: { $0.id == id }) else { return }
            t.tags      = prev
            t.updatedAt = Date()
            let snap = t
            Task { try? await db.pool.write { db in try snap.update(db) } }
        }
    }

    // Current due date for the picker view
    var dueDatePickerTodo: Todo? {
        guard let id = dueDatePickerId else { return nil }
        return todos.first(where: { $0.id == id })
    }
}
