import SwiftUI

/// Bottom status bar — workspace tabs on the right, item count on the left.
struct StatusBarView: View {
    @EnvironmentObject var state: AppState

    var pendingCount: Int {
        state.flatTodos.filter { !$0.todo.isDone }.count
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left: pending item count
            Text("\(pendingCount) item\(pendingCount == 1 ? "" : "s")")
                .font(Theme.monoFont)
                .foregroundColor(Theme.textSecondary)
                .padding(.leading, 8)

            Spacer()

            // Right: workspace tabs
            HStack(spacing: 0) {
                ForEach(Array(state.workspaces.enumerated()), id: \.element.id) { i, ws in
                    Rectangle()
                        .fill(Theme.border)
                        .frame(width: 1, height: 14)

                    Button(action: { state.switchWorkspace(to: i) }) {
                        HStack(spacing: 3) {
                            Text("\(i + 1)")
                                .font(Theme.monoFont)
                            Text(ws.name)
                                .font(Theme.smallFont)
                        }
                        .foregroundColor(i == state.currentWorkspaceIndex
                            ? Theme.textSelected : Theme.text)
                        .padding(.horizontal, 8)
                        .frame(height: Theme.statusBarHeight)
                        .background(i == state.currentWorkspaceIndex
                            ? Theme.selectedBg : Color.clear)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Rename") {
                            state.renameWorkspaceText = ws.name
                            state.renamingWorkspaceId = ws.id
                        }
                        Divider()
                        Button("Delete", role: .destructive) {
                            state.deleteWorkspace(id: ws.id)
                        }
                        .disabled(state.workspaces.count <= 1)
                    }
                }

                Rectangle()
                    .fill(Theme.border)
                    .frame(width: 1, height: 14)

                Button("+") { state.createWorkspace(name: "New Space") }
                    .buttonStyle(.plain)
                    .font(Theme.font)
                    .foregroundColor(Theme.textSecondary)
                    .frame(width: 26, height: Theme.statusBarHeight)
            }
        }
        .frame(height: Theme.statusBarHeight)
        .background(Theme.windowBg)
        .overlay(
            Rectangle().frame(height: 1).foregroundColor(Theme.border),
            alignment: .top
        )
    }
}
