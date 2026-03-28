import SwiftUI

struct RenameWorkspaceView: View {
    @EnvironmentObject var state: AppState
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Rename Workspace")
                .font(Theme.font)
                .foregroundColor(Theme.text)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Theme.sidebarBg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(Rectangle().frame(height: 1).foregroundColor(Theme.border), alignment: .bottom)

            VStack(spacing: 12) {
                TextField("Name", text: $state.renameWorkspaceText)
                    .font(Theme.font)
                    .textFieldStyle(.plain)
                    .focused($focused)
                    .padding(6)
                    .background(Theme.rowBg)
                    .overlay(Rectangle().stroke(Theme.border, lineWidth: 1))
                    .onSubmit { commit() }

                HStack {
                    Button("Cancel") { state.renamingWorkspaceId = nil }
                        .buttonStyle(.plain)
                        .font(Theme.font)
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                    Button("Rename") { commit() }
                        .buttonStyle(.plain)
                        .font(Theme.font)
                        .foregroundColor(Theme.text)
                }
            }
            .padding(16)
        }
        .background(Theme.windowBg)
        .frame(width: 280)
        .onAppear { focused = true }
    }

    private func commit() {
        if let id = state.renamingWorkspaceId {
            state.renameWorkspace(id: id, name: state.renameWorkspaceText)
        }
        state.renamingWorkspaceId = nil
    }
}
