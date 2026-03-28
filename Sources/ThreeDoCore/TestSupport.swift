import Foundation

/// Convenience factory for building `Todo` instances in tests and previews.
/// Keeping this in ThreeDoCore avoids the need to import Foundation directly
/// in test files (which conflicts with Swift Testing's overlay resolution
/// in Command Line Tools environments).
public extension Todo {
    /// Create a test todo with an auto-generated workspace id.
    static func make(
        parentId: UUID? = nil,
        text: String = "Test",
        position: Double,
        isCollapsed: Bool = false,
        isDone: Bool = false
    ) -> Todo {
        var t = Todo(workspaceId: UUID(), parentId: parentId, text: text, position: position)
        t.isCollapsed = isCollapsed
        t.isDone = isDone
        return t
    }

    /// Create a random UUID — exposed so tests don't need `import Foundation`.
    static func newId() -> UUID { UUID() }
}
