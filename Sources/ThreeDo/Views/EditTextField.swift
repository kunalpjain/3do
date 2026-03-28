import AppKit
import SwiftUI

/// A plain, borderless NSTextField that reliably claims first responder and
/// positions the cursor at the end of text — bypassing SwiftUI's @FocusState,
/// which fires during the layout pass and is silently ignored by the focus engine.
struct EditTextField: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont
    var onSubmit: () -> Void

    func makeNSView(context: Context) -> NSTextField {
        let tf = NSTextField()
        tf.isBordered      = false
        tf.drawsBackground = false
        tf.focusRingType   = .none
        tf.font            = font
        tf.cell?.sendsActionOnEndEditing = false
        tf.delegate = context.coordinator
        return tf
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        context.coordinator.parent = self

        // Sync text from state → view, but don't clobber an active edit.
        if nsView.stringValue != text {
            nsView.stringValue = text
        }

        // On the first update after the view enters the hierarchy, claim
        // first responder and place the cursor at the end (not a full selection,
        // which is NSTextField's default and causes "types erases everything").
        if !context.coordinator.hasFocused {
            context.coordinator.hasFocused = true
            DispatchQueue.main.async {
                guard let window = nsView.window else { return }
                window.makeFirstResponder(nsView)
                nsView.currentEditor()?.moveToEndOfDocument(nil)
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: EditTextField
        var hasFocused = false

        init(_ parent: EditTextField) { self.parent = parent }

        // Sync typed text → state binding.
        func controlTextDidChange(_ notification: Notification) {
            guard let tf = notification.object as? NSTextField else { return }
            parent.text = tf.stringValue
        }

        // Route Return key to onSubmit; let everything else fall through.
        func control(_ control: NSControl, textView: NSTextView,
                     doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit()
                return true
            }
            return false
        }
    }
}
