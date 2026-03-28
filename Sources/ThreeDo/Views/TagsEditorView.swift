import SwiftUI
import ThreeDoCore

struct TagsEditorView: View {
    @EnvironmentObject var state: AppState
    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Tags")
                    .font(Theme.font)
                    .foregroundColor(Theme.text)
                Spacer()
                Text("space-separated, e.g. work home")
                    .font(Theme.smallFont)
                    .foregroundColor(Theme.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Theme.sidebarBg)
            .overlay(Rectangle().frame(height: 1).foregroundColor(Theme.border), alignment: .bottom)

            VStack(alignment: .leading, spacing: 12) {
                TextField("#tag1 #tag2 …", text: $text)
                    .font(Theme.font)
                    .textFieldStyle(.plain)
                    .focused($focused)
                    .padding(6)
                    .background(Theme.rowBg)
                    .overlay(Rectangle().stroke(Theme.border, lineWidth: 1))
                    .onSubmit { commit() }

                // Live preview
                let parsed = TodoLogic.parseTags(text)
                if !parsed.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(parsed, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(Theme.monoFont)
                                .foregroundColor(Theme.textSecondary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Theme.sidebarBg)
                                .overlay(Rectangle().stroke(Theme.border, lineWidth: 1))
                        }
                    }
                }

                HStack {
                    Button("Clear Tags") {
                        if let id = state.tagsSheetId { state.setTags(id: id, rawTags: "") }
                        state.tagsSheetId = nil
                    }
                    .buttonStyle(.plain)
                    .font(Theme.font)
                    .foregroundColor(Theme.textSecondary)

                    Spacer()

                    Button("Cancel") { state.tagsSheetId = nil }
                        .buttonStyle(.plain)
                        .font(Theme.font)
                        .foregroundColor(Theme.textSecondary)

                    Button("Save") { commit() }
                        .buttonStyle(.plain)
                        .font(Theme.font)
                        .foregroundColor(Theme.text)
                }
            }
            .padding(16)
        }
        .background(Theme.windowBg)
        .frame(width: 360)
        .onAppear {
            if let existing = state.tagsSheetTodo?.tags, !existing.isEmpty {
                text = existing
            }
            focused = true
        }
    }

    private func commit() {
        if let id = state.tagsSheetId { state.setTags(id: id, rawTags: text) }
        state.tagsSheetId = nil
    }
}
