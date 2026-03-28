import SwiftUI

struct ContentView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            TodoListView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            StatusBarView()
        }
        .background(Theme.windowBg)
        .frame(minWidth: 600, minHeight: 400)
        .sheet(isPresented: $state.isShowingHelp) {
            HelpOverlayView()
        }
        .sheet(isPresented: Binding(
            get: { state.dueDatePickerId != nil },
            set: { if !$0 { state.dueDatePickerId = nil } }
        )) {
            DueDatePickerView()
        }
        .sheet(isPresented: Binding(
            get: { state.tagsSheetId != nil },
            set: { if !$0 { state.tagsSheetId = nil } }
        )) {
            TagsEditorView()
        }
        .sheet(isPresented: Binding(
            get: { state.renamingWorkspaceId != nil },
            set: { if !$0 { state.renamingWorkspaceId = nil } }
        )) {
            RenameWorkspaceView()
        }
    }
}
