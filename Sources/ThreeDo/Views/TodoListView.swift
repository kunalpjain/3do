import SwiftUI
import AppKit
import ThreeDoCore

struct TodoListView: View {
    @EnvironmentObject var state: AppState

    var displayedTodos: [FlatTodo] {
        if state.isSearching, !state.searchText.isEmpty {
            let q = state.searchText.lowercased()
            return state.flatTodos.filter { $0.todo.text.lowercased().contains(q) }
        }
        return state.flatTodos
    }

    var body: some View {
        VStack(spacing: 0) {
            if state.isSearching { searchBar }
            todoScrollView
        }
        .onAppear {
            // Ensure the app has keyboard focus — important for swift run
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
        }
    }

    // MARK: - Search bar

    @ViewBuilder
    var searchBar: some View {
        HStack(spacing: 6) {
            Text("⌕").font(Theme.font).foregroundColor(Theme.textSecondary)
            TextField("Search...", text: $state.searchText)
                .textFieldStyle(.plain).font(Theme.font)
                .onSubmit { state.isSearching = false }
            Button("✕") { state.isSearching = false; state.searchText = "" }
                .buttonStyle(.plain).foregroundColor(Theme.textSecondary)
        }
        .padding(.horizontal, 8)
        .frame(height: Theme.rowHeight + 2)
        .background(Theme.windowBg)
        .overlay(Rectangle().frame(height: 1).foregroundColor(Theme.border), alignment: .bottom)
    }

    // MARK: - Scroll view

    var todoScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                todoRows
            }
            .background(Theme.rowBg)
            // Scroll to keep the selected row visible
            .onChange(of: state.selectedId) { _, newId in
                if let id = newId { proxy.scrollTo(id, anchor: .center) }
            }
            // When editingId is set, scroll to it
            .onChange(of: state.editingId) { _, newId in
                if let id = newId { proxy.scrollTo(id, anchor: .center) }
            }
        }
    }

    // MARK: - Row list

    var todoRows: some View {
        LazyVStack(spacing: 0) {
            if displayedTodos.isEmpty {
                Text("No todos — press n to create one.")
                    .font(Theme.font).foregroundColor(Theme.textSecondary)
                    .padding(.top, 20).padding(.horizontal, 12)
            } else {
                ForEach(displayedTodos) { ft in
                    TodoRowView(
                        flatTodo:         ft,
                        isSelected:       state.allSelectedIds.contains(ft.id),
                        isEditing:        ft.id == state.editingId,
                        editText:         $state.editText,
                        onToggleDone:     { state.toggleDone(id: ft.id) },
                        onToggleCollapse: { state.collapseToggle(id: ft.id) },
                        onCommitEdit:     { state.commitEdit() }
                    )
                    .id(ft.id)
                    .onTapGesture {
                        if state.selectedId == ft.id {
                            state.startEditing(id: ft.id)
                        } else {
                            state.selectedId = ft.id
                            state.commitEdit()
                        }
                    }
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
