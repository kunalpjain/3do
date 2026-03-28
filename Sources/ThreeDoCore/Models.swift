import Foundation

// MARK: - Workspace

/// A named container for a set of todos. Each workspace has its own isolated todo tree.
/// Soft-deleted workspaces (`deletedAt` non-nil) are excluded from all live queries.
public struct Workspace: Identifiable, Codable, Equatable {
    public var id: UUID
    public var name: String
    public var position: Int
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, position
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }

    public init(name: String, position: Int = 0) {
        self.id = UUID()
        self.name = name
        self.position = position
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
        self.deletedAt = nil
    }
}

// MARK: - Priority

/// Task urgency level. Displayed as a single-letter badge (L / M / H) on each todo row.
public enum Priority: String, Codable, CaseIterable, Equatable, Sendable {
    case low    = "low"
    case medium = "medium"
    case high   = "high"

    public var display: String {
        switch self {
        case .low:    return "L"
        case .medium: return "M"
        case .high:   return "H"
        }
    }

    public var label: String {
        switch self {
        case .low:    return "Low"
        case .medium: return "Medium"
        case .high:   return "High"
        }
    }
}

// MARK: - Todo

/// A single task node. Todos form a hierarchy via `parentId`; position within siblings
/// is a `Double` to allow fractional insertion without renumbering the whole list.
/// Soft-deleted todos (`deletedAt` non-nil) are excluded from all live queries.
public struct Todo: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var workspaceId: UUID
    public var parentId: UUID?
    public var text: String
    public var isDone: Bool
    public var dueDate: Date?
    public var priority: Priority?
    public var position: Double
    public var tags: String          // space-separated tag names, e.g. "work home urgent"
    public var isCollapsed: Bool
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case workspaceId  = "workspace_id"
        case parentId     = "parent_id"
        case text
        case isDone       = "is_done"
        case dueDate      = "due_date"
        case priority, position, tags
        case isCollapsed  = "is_collapsed"
        case createdAt    = "created_at"
        case updatedAt    = "updated_at"
        case deletedAt    = "deleted_at"
    }

    public init(
        workspaceId: UUID,
        parentId: UUID? = nil,
        text: String = "",
        position: Double = 0.0
    ) {
        self.id = UUID()
        self.workspaceId = workspaceId
        self.parentId = parentId
        self.text = text
        self.isDone = false
        self.dueDate = nil
        self.priority = nil
        self.tags = ""
        self.position = position
        self.isCollapsed = false
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
        self.deletedAt = nil
    }
}

// MARK: - FlatTodo (display model)

/// View-model produced by `TodoLogic.flatten`. Carries depth and child-presence flags
/// so `TodoRowView` doesn't need to recompute them on every render pass.
public struct FlatTodo: Identifiable, Equatable {
    public var id: UUID { todo.id }
    public let todo: Todo
    public let depth: Int
    public let hasChildren: Bool

    public init(todo: Todo, depth: Int, hasChildren: Bool) {
        self.todo = todo
        self.depth = depth
        self.hasChildren = hasChildren
    }
}

// MARK: - MoveDirection

/// Direction argument for `AppState.moveTodo` — reorders a todo within its siblings.
public enum MoveDirection { case up, down }

// MARK: - UndoAction

/// All reversible mutations. Stored in an in-memory undo stack; each action
/// carries enough state to restore the previous value without a DB read.
public enum UndoAction: Sendable {
    case create(id: UUID)            // undoing creates deletes the todo
    case delete(snapshot: Todo)
    case setDone(id: UUID, previousValue: Bool)
    case setText(id: UUID, previousText: String)
    case setPriority(id: UUID, previousPriority: Priority?)
    case setDueDate(id: UUID, previousDueDate: Date?)
    case setTags(id: UUID, previousTags: String)
}

// MARK: - Array safe subscript

extension Array {
    /// Returns the element at `i`, or `nil` if `i` is out of bounds.
    public subscript(safe i: Int) -> Element? {
        indices.contains(i) ? self[i] : nil
    }
}
