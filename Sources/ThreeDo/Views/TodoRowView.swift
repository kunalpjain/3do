import SwiftUI
import ThreeDoCore

struct TodoRowView: View {
    let flatTodo: FlatTodo
    let isSelected: Bool
    let isEditing: Bool
    @Binding var editText: String
    let onToggleDone: () -> Void
    let onToggleCollapse: () -> Void
    let onCommitEdit: () -> Void

    // Foreground colour cascades to all children; buttons with .buttonStyle(.plain) inherit it.
    var fg: Color { isSelected ? Theme.textSelected : Theme.text }
    var fgDim: Color { isSelected ? Theme.textSelected.opacity(0.6) : Theme.textSecondary }

    var body: some View {
        HStack(spacing: 0) {
            // Indent spacer
            if flatTodo.depth > 0 {
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: CGFloat(flatTodo.depth) * Theme.indentWidth)
            }

            // Expand/collapse triangle
            Button(action: onToggleCollapse) {
                Text(flatTodo.hasChildren
                     ? (flatTodo.todo.isCollapsed ? "▶" : "▼")
                     : " ")
                    .font(.system(size: 9))
            }
            .buttonStyle(.plain)
            .frame(width: 14)

            // Checkbox
            Button(action: onToggleDone) {
                Text(flatTodo.todo.isDone ? "☑" : "☐")
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)
            .frame(width: 18)

            // Text or EditTextField
            if isEditing {
                EditTextField(
                    text:     $editText,
                    font:     .systemFont(ofSize: Theme.fontSize),
                    onSubmit: onCommitEdit
                )
                .foregroundColor(Theme.text)
                .padding(.leading, 3)
            } else {
                Text(flatTodo.todo.text.isEmpty ? " " : flatTodo.todo.text)
                    .font(Theme.font)
                    .strikethrough(flatTodo.todo.isDone && !isSelected)
                    .opacity(flatTodo.todo.isDone && !isSelected ? 0.5 : 1)
                    .lineLimit(1)
                    .padding(.leading, 3)
            }

            Spacer()

            // Priority badge
            if let p = flatTodo.todo.priority {
                Text(p.display)
                    .font(Theme.monoFont)
                    .foregroundColor(isSelected ? Theme.textSelected : Theme.priorityColor(p))
                    .padding(.horizontal, 4)
            }

            // Tags
            let tags = TodoLogic.parseTags(flatTodo.todo.tags)
            if !tags.isEmpty {
                Text(tags.map { "#\($0)" }.joined(separator: " "))
                    .font(Theme.monoFont)
                    .foregroundColor(isSelected ? fgDim : Theme.textSecondary)
                    .padding(.trailing, 4)
            }

            // Due date
            if let due = flatTodo.todo.dueDate {
                Text(due, style: .date)
                    .font(.system(size: 10))
                    .opacity(0.8)
                    .padding(.trailing, 4)
            }
        }
        .foregroundColor(fg)  // ← single source of truth for all non-editing text
        .frame(height: Theme.rowHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? Theme.selectedBg : Color.clear)
        .contentShape(Rectangle())
    }
}
