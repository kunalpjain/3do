import Foundation

/// Pure value type capturing the mutable state of a single in-progress edit.
/// Lives in ThreeDoCore so it can be unit-tested without AppKit or GRDB.
public struct EditSession {
    public var editingId: UUID? = nil
    public var editText: String = ""

    public init() {}

    /// Begin editing `todo`. `initialChar` replaces the existing text (typed-to-start behaviour).
    public mutating func start(todo: Todo, initialChar: String? = nil) {
        editText   = initialChar ?? todo.text
        editingId  = todo.id
    }

    /// Commit and clear. Returns the (id, text) pair to persist, or nil if nothing was being edited.
    @discardableResult
    public mutating func commit() -> (id: UUID, text: String)? {
        guard let id = editingId else { return nil }
        let result = (id: id, text: editText)
        editingId  = nil
        return result
    }

    public var isActive: Bool { editingId != nil }
}
