import SwiftUI
import AppKit
import ThreeDoCore

enum Theme {
    // macOS Classic palette — flat grey, no gradients
    static let windowBg        = Color(NSColor.windowBackgroundColor)
    static let sidebarBg       = Color(NSColor.controlBackgroundColor)
    static let rowBg           = Color(NSColor.controlBackgroundColor)
    // Light selection: tinted background, dark text — readable in both modes
    static let selectedBg      = Color(NSColor.selectedTextBackgroundColor)
    static let border          = Color(NSColor.separatorColor)
    static let text            = Color(NSColor.labelColor)
    static let textSelected    = Color(NSColor.labelColor)   // same as text on light bg
    static let textDone        = Color(NSColor.tertiaryLabelColor)
    static let textSecondary   = Color(NSColor.secondaryLabelColor)

    static let priorityHigh    = Color(red: 0.8, green: 0.0, blue: 0.0)
    static let priorityMedium  = Color(red: 0.7, green: 0.4, blue: 0.0)
    static let priorityLow     = Color(red: 0.0, green: 0.0, blue: 0.7)

    static let fontSize: CGFloat       = 13
    static let smallSize: CGFloat      = 11
    static let rowHeight: CGFloat      = 22
    static let statusBarHeight: CGFloat = 22
    static let indentWidth: CGFloat    = 18
    static let sidebarWidth: CGFloat   = 160

    static var font: Font { .system(size: fontSize) }
    static var smallFont: Font { .system(size: smallSize) }
    static var monoFont: Font { .system(size: smallSize, design: .monospaced) }

    static func priorityColor(_ p: Priority) -> Color {
        switch p {
        case .low:    return priorityLow
        case .medium: return priorityMedium
        case .high:   return priorityHigh
        }
    }
}
