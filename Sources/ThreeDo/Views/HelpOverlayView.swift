import SwiftUI

struct HelpOverlayView: View {

    private struct Row: Identifiable {
        let id = UUID()
        let key: String
        let description: String
    }

    private let sections: [(title: String, rows: [Row])] = [
        ("Navigation", [
            Row(key: "j / ↓",        description: "Select next"),
            Row(key: "k / ↑",        description: "Select previous"),
            Row(key: "h / ←",        description: "Collapse (or unindent)"),
            Row(key: "l / →",        description: "Expand (or indent)"),
        ]),
        ("Editing", [
            Row(key: "Enter / i",    description: "Edit selected todo"),
            Row(key: "n",            description: "New todo below selected"),
            Row(key: "Esc",          description: "Commit edit / close"),
            Row(key: "Tab",          description: "Indent"),
            Row(key: "Shift+Tab",    description: "Unindent"),
        ]),
        ("Actions", [
            Row(key: "Space",        description: "Toggle done"),
            Row(key: "p",            description: "Cycle priority (L → M → H → none)"),
            Row(key: "d",            description: "Set due date"),
            Row(key: "Backspace",    description: "Delete todo"),
            Row(key: "Cmd+Z",        description: "Undo"),
        ]),
        ("View", [
            Row(key: "Cmd+F",        description: "Search"),
            Row(key: "Cmd+↑ / ↓",   description: "Move todo up / down"),
            Row(key: "Cmd+1–9",      description: "Switch workspace"),
            Row(key: "?",            description: "Show this help"),
        ]),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title bar
            HStack {
                Text("Keyboard Shortcuts")
                    .font(Theme.font)
                    .foregroundColor(Theme.text)
                Spacer()
                Text("Press ? or Esc to close")
                    .font(Theme.smallFont)
                    .foregroundColor(Theme.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Theme.sidebarBg)
            .overlay(Rectangle().frame(height: 1).foregroundColor(Theme.border), alignment: .bottom)

            // Shortcut table
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(sections, id: \.title) { section in
                        Text(section.title.uppercased())
                            .font(Theme.smallFont)
                            .foregroundColor(Theme.textSecondary)
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .padding(.bottom, 4)

                        ForEach(section.rows) { row in
                            HStack(spacing: 0) {
                                Text(row.key)
                                    .font(Theme.monoFont)
                                    .foregroundColor(Theme.text)
                                    .frame(width: 140, alignment: .leading)
                                Text(row.description)
                                    .font(Theme.font)
                                    .foregroundColor(Theme.textSecondary)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .frame(height: Theme.rowHeight)
                            .overlay(
                                Rectangle().frame(height: 1).foregroundColor(Theme.border.opacity(0.3)),
                                alignment: .bottom
                            )
                        }
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .background(Theme.windowBg)
        .frame(width: 420, height: 480)
    }
}
