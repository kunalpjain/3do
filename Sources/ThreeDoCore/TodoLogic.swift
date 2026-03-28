import Foundation

/// Stateless, pure functions for todo tree manipulation.
/// All functions are free of side effects — safe to call from tests or previews.
public enum TodoLogic {

    // MARK: - Flatten

    /// Depth-first flatten of a todo tree into a display-ordered list.
    /// Respects `isCollapsed` — children of collapsed parents are omitted.
    /// Input `todos` need not be sorted; sorting is done internally.
    public static func flatten(_ todos: [Todo]) -> [FlatTodo] {
        var childrenMap: [UUID?: [Todo]] = [:]
        for t in todos {
            childrenMap[t.parentId, default: []].append(t)
        }
        for key in childrenMap.keys {
            childrenMap[key]?.sort { $0.position < $1.position }
        }

        var result: [FlatTodo] = []

        func visit(parentId: UUID?, depth: Int) {
            guard let children = childrenMap[parentId] else { return }
            for t in children {
                let hasChildren = (childrenMap[t.id]?.isEmpty == false)
                result.append(FlatTodo(todo: t, depth: depth, hasChildren: hasChildren))
                if !t.isCollapsed {
                    visit(parentId: t.id, depth: depth + 1)
                }
            }
        }

        visit(parentId: nil, depth: 0)
        return result
    }

    // MARK: - Position helpers

    /// Position for inserting a new item after the todo with `afterId` among `siblings`.
    /// Pass `afterId: nil` to insert at the end.
    /// Siblings should be the todos at the same parent level (unfiltered for deleted is fine here).
    public static func insertPosition(afterId: UUID?, among siblings: [Todo]) -> Double {
        let sorted = siblings.sorted { $0.position < $1.position }
        guard let aid = afterId,
              let idx = sorted.firstIndex(where: { $0.id == aid }) else {
            // nil afterId → end of list
            return (sorted.last?.position ?? 0.0) + 1.0
        }
        let afterPos = sorted[idx].position
        if idx + 1 < sorted.count {
            return (afterPos + sorted[idx + 1].position) / 2.0
        }
        return afterPos + 1.0
    }

    // MARK: - Indent

    /// Make `todo` the last child of its previous sibling.
    /// Returns the updated todo, or `nil` if `todo` is already first among siblings
    /// (nothing to indent into).
    ///
    /// - Parameters:
    ///   - todo: the todo to indent
    ///   - siblings: all todos at the same level (same parentId), including `todo` itself
    ///   - existingChildren: current children of the new parent (the previous sibling)
    public static func applyIndent(
        to todo: Todo,
        siblings: [Todo],
        existingChildren: [Todo]
    ) -> Todo? {
        let sorted = siblings.sorted { $0.position < $1.position }
        guard let idx = sorted.firstIndex(where: { $0.id == todo.id }),
              idx > 0 else { return nil }

        let newParent = sorted[idx - 1]
        let newPosition = (existingChildren.max(by: { $0.position < $1.position })?.position ?? 0.0) + 1.0

        var updated = todo
        updated.parentId = newParent.id
        updated.position = newPosition
        return updated
    }

    // MARK: - Unindent

    /// Move `todo` out one level — place it after its parent among the grandparent's children.
    /// Returns the updated todo, or `nil` if `todo` is already at root level.
    ///
    /// - Parameters:
    ///   - todo: the todo to unindent
    ///   - parent: the todo's current parent (nil safe — will return nil if already root)
    ///   - grandparentSiblings: todos at the grandparent level (parent's siblings), sorted or not
    public static func applyUnindent(
        to todo: Todo,
        parent: Todo?,
        grandparentSiblings: [Todo]
    ) -> Todo? {
        guard todo.parentId != nil, let parent else { return nil }

        let sorted = grandparentSiblings.sorted { $0.position < $1.position }
        guard let parentIdx = sorted.firstIndex(where: { $0.id == parent.id }) else {
            return nil
        }

        let afterPos = sorted[parentIdx].position
        let newPosition: Double
        if parentIdx + 1 < sorted.count {
            newPosition = (afterPos + sorted[parentIdx + 1].position) / 2.0
        } else {
            newPosition = afterPos + 1.0
        }

        var updated = todo
        updated.parentId = parent.parentId
        updated.position = newPosition
        return updated
    }

    // MARK: - Tags

    /// Parse raw stored string ("work home") → ["work", "home"].
    /// Strips leading `#`, lowercases, deduplicates, ignores empty tokens.
    public static func parseTags(_ raw: String) -> [String] {
        let tokens = raw.split(whereSeparator: { $0.isWhitespace || $0 == "," })
        var seen = Set<String>()
        return tokens.compactMap { token -> String? in
            let t = token.hasPrefix("#") ? String(token.dropFirst()) : String(token)
            let key = t.lowercased()
            guard !key.isEmpty, seen.insert(key).inserted else { return nil }
            return key
        }
    }

    /// Canonical storage string for a tag list.
    public static func formatTags(_ tags: [String]) -> String {
        tags.joined(separator: " ")
    }

    // MARK: - Bulk delete

    /// Which item should be selected after `deletingIds` are all removed?
    /// Finds the first item below the selection, or the last item above it.
    public static func selectionAfterBulkDelete(deletingIds: Set<UUID>, in flatTodos: [FlatTodo]) -> UUID? {
        let remaining = flatTodos.filter { !deletingIds.contains($0.id) }
        guard !remaining.isEmpty else { return nil }
        // Find the lowest index among deleted items, then pick the next remaining item after it
        let deletedIndices = flatTodos.indices.filter { deletingIds.contains(flatTodos[$0].id) }
        guard let maxDeletedIndex = deletedIndices.max() else { return remaining.first?.id }
        // First remaining item after the deleted block
        if let next = remaining.first(where: { r in
            flatTodos.firstIndex(where: { $0.id == r.id }).map { $0 > maxDeletedIndex } ?? false
        }) { return next.id }
        // Fall back to the last remaining item before the deleted block
        return remaining.last?.id
    }

    // MARK: - Priority

    /// Cycles nil → low → medium → high → nil.
    public static func nextPriority(_ current: Priority?) -> Priority? {
        switch current {
        case nil:     return .low
        case .low:    return .medium
        case .medium: return .high
        case .high:   return nil
        }
    }

    // MARK: - Delete

    /// Which item should be selected after `deletingId` is removed from `flatTodos`?
    /// Prefers the item below; falls back to the item above; returns nil for an empty list.
    public static func selectionAfterDelete(deletingId: UUID, in flatTodos: [FlatTodo]) -> UUID? {
        guard let idx = flatTodos.firstIndex(where: { $0.id == deletingId }) else { return nil }
        if idx + 1 < flatTodos.count { return flatTodos[idx + 1].id }
        if idx > 0                   { return flatTodos[idx - 1].id }
        return nil
    }

    // MARK: - Modal sheet guard

    /// Returns true when a modal sheet that needs its own keyboard input is open.
    /// The global key monitor must return `false` (pass the event through) in this state
    /// so arrow keys, jkli, and other keys reach the sheet instead of the todo list.
    public static func isModalSheetOpen(
        dueDatePickerId: UUID?,
        tagsSheetId: UUID?,
        renamingWorkspaceId: UUID?
    ) -> Bool {
        dueDatePickerId != nil || tagsSheetId != nil || renamingWorkspaceId != nil
    }

    // MARK: - Date formatting (for display in text fields)

    /// Format a `Date` as `m/d/yy` for display in the due-date text field.
    /// This is the inverse of `parseDateInput`.
    public static func formatDateForInput(_ date: Date) -> String {
        let cal = Calendar.current
        let m  = cal.component(.month,  from: date)
        let d  = cal.component(.day,    from: date)
        let yy = cal.component(.year,   from: date) % 100
        return String(format: "%d/%d/%02d", m, d, yy)
    }

    // MARK: - Date input parsing

    /// Parse a user-typed date string into a `Date`.
    ///
    /// Accepted formats (leading zeros optional):
    /// - `mm/dd`      → day/month in `referenceYear`, or next year if the date has already passed
    /// - `mm/dd/yy`   → 2-digit year is interpreted as 2000+yy
    /// - `mm/dd/yyyy` → 4-digit year
    ///
    /// Returns `nil` for invalid or unparseable input.
    public static func parseDateInput(_ input: String, relativeTo now: Date = Date()) -> Date? {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        let parts = trimmed.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 2 || parts.count == 3 else { return nil }

        guard let month = Int(parts[0]), let day = Int(parts[1]) else { return nil }
        guard month >= 1, month <= 12, day >= 1, day <= 31 else { return nil }

        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: now)

        let year: Int
        if parts.count == 3 {
            guard !parts[2].isEmpty, let y = Int(parts[2]) else { return nil }
            year = y < 100 ? 2000 + y : y
        } else {
            // mm/dd only — use current year; bump to next year if date has already passed
            var comps = DateComponents()
            comps.year = currentYear; comps.month = month; comps.day = day
            if let candidate = calendar.date(from: comps), candidate < now {
                year = currentYear + 1
            } else {
                year = currentYear
            }
        }

        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day
        return calendar.date(from: comps)
    }

    // MARK: - Move up / down within siblings

    /// Returns the new position for moving `todo` up one slot, or `nil` if already first.
    public static func positionForMoveUp(todo: Todo, among siblings: [Todo]) -> Double? {
        let sorted = siblings.sorted { $0.position < $1.position }
        guard let idx = sorted.firstIndex(where: { $0.id == todo.id }),
              idx > 0 else { return nil }
        return sorted[idx - 1].position
    }

    /// Returns the new position for moving `todo` down one slot, or `nil` if already last.
    public static func positionForMoveDown(todo: Todo, among siblings: [Todo]) -> Double? {
        let sorted = siblings.sorted { $0.position < $1.position }
        guard let idx = sorted.firstIndex(where: { $0.id == todo.id }),
              idx < sorted.count - 1 else { return nil }
        return sorted[idx + 1].position
    }
}
