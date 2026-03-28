import SwiftUI
import ThreeDoCore

struct DueDatePickerView: View {
    @EnvironmentObject var state: AppState
    @State private var selectedDate: Date = Date()
    @State private var dateInput: String = ""
    @State private var inputIsValid: Bool = true
    @FocusState private var textFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title bar
            HStack {
                Text("Set Due Date")
                    .font(Theme.font)
                    .foregroundColor(Theme.text)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Theme.sidebarBg)
            .overlay(Rectangle().frame(height: 1).foregroundColor(Theme.border), alignment: .bottom)

            VStack(alignment: .leading, spacing: 12) {
                // Quick text entry — focused on open; parses mm/dd or mm/dd/yy live
                HStack(spacing: 6) {
                    TextField("mm/dd or mm/dd/yy", text: $dateInput)
                        .textFieldStyle(.roundedBorder)
                        .font(Theme.font)
                        .focused($textFocused)
                        .onChange(of: dateInput) { _, newValue in
                            if let parsed = TodoLogic.parseDateInput(newValue) {
                                selectedDate = parsed
                                inputIsValid = true
                            } else {
                                inputIsValid = newValue.isEmpty
                            }
                        }
                        .onSubmit { confirmDate() }

                    if !inputIsValid {
                        Text("?")
                            .font(Theme.monoFont)
                            .foregroundColor(.red)
                    }
                }

                // Graphical calendar — arrow-key navigable once focused (Tab from text field)
                DatePicker("", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()

                HStack(spacing: 8) {
                    Button("Clear Date") {
                        if let id = state.dueDatePickerId {
                            state.setDueDate(id: id, date: nil)
                        }
                        state.dueDatePickerId = nil
                    }
                    .buttonStyle(.plain)
                    .font(Theme.font)
                    .foregroundColor(Theme.textSecondary)

                    Spacer()

                    Button("Cancel") {
                        state.dueDatePickerId = nil
                    }
                    .buttonStyle(.plain)
                    .font(Theme.font)
                    .foregroundColor(Theme.textSecondary)

                    Button("Set Date") { confirmDate() }
                        .buttonStyle(.plain)
                        .font(Theme.font)
                        .foregroundColor(Theme.text)
                        .keyboardShortcut(.defaultAction)  // Return/Enter confirms from anywhere in the sheet
                }
                .padding(.horizontal, 4)
            }
            .padding(16)
        }
        .background(Theme.windowBg)
        .frame(width: 320)
        .onAppear {
            if let existing = state.dueDatePickerTodo?.dueDate {
                selectedDate = existing
                dateInput = TodoLogic.formatDateForInput(existing)
            }
            DispatchQueue.main.async { textFocused = true }
        }
    }

    private func confirmDate() {
        if let id = state.dueDatePickerId {
            state.setDueDate(id: id, date: selectedDate)
        }
        state.dueDatePickerId = nil
    }
}
