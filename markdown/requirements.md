# 3do — Requirements

**Tagline:** Your 10x to-dos.
**Platform:** macOS (v1). Web + iOS planned for later.

---

## Core Principles

- Speed above all else — no perceived lag, no animations, no transitions
- Keyboard-first: every action reachable without a mouse
- Minimal, retro aesthetic — macOS Classic style (flat, square, no rounded corners)

---

## Functional Requirements

### Workspaces (Spaces)

- User can create named workspaces (e.g. Personal, Work)
- Each workspace is fully isolated — its own todo tree
- `Cmd+1` through `Cmd+9` switches between workspaces instantly
- Workspace list visible in a sidebar or tab bar

### Todo Hierarchy

- Todos support unlimited parent/child nesting
- Children are indented under their parent
- Collapsing/expanding a parent hides/shows its subtree
- Rearranging: move todos up/down, indent/unindent via keyboard

### Todo Fields


| Field    | Required | Notes                              |
| -------- | -------- | ---------------------------------- |
| Text     | Yes      | Plain text only, no markdown       |
| Done     | Yes      | Toggle complete/incomplete         |
| Due date | No       | Optional date picker               |
| Priority | No       | e.g. Low / Medium / High           |
| Tags     | No       | Free-form labels, multiple allowed |


### Navigation & Keyboard Shortcuts

Inspired by [h-m-m](https://github.com/nadrad/h-m-m).


| Action                   | Shortcut                               |
| ------------------------ | -------------------------------------- |
| Move cursor up/down      | `↑` / `↓` or `k` / `j`                 |
| Move cursor left/right   | `←` / `→` or `h` / `l`                 |
| Switch workspace         | `Cmd+1` … `Cmd+9`                      |
| New todo (sibling below) | `Enter`                                |
| New child todo           | `Tab` on new line                      |
| Indent todo              | `Tab`                                  |
| Unindent todo            | `Shift+Tab`                            |
| Toggle done              | `Space` or `Cmd+D`                     |
| Delete todo              | `Backspace` (on empty) or `Cmd+Delete` |
| Move todo up             | `Cmd+↑`                                |
| Move todo down           | `Cmd+↓`                                |
| Collapse/expand subtree  | `→` / `←` (on parent)                  |
| Edit selected todo       | `F2` or just start typing              |
| Search                   | `Cmd+F`                                |
| Escape / cancel          | `Esc`                                  |


### Search

- `Cmd+F` opens an inline search bar
- Searches across all todos in the current workspace
- Highlights matches, arrow keys navigate between results
- `Esc` dismisses

### Appearance

- **Style:** macOS Classic — flat grey, square borders, square icons, no gradients, no shadows
- **Themes:** Light mode and dark mode
- **Density:** Compact — show as many todos as possible without scrolling
- No animations, no transitions anywhere

---

## Non-Functional Requirements

- Launch time: < 1 second cold start
- All UI interactions: < 16ms response (60fps input handling)
- Local data read/write: imperceptible (< 5ms for typical dataset)
- Works fully offline; sync is additive, not required

---

## Out of Scope for v1

- Account creation / login / sync (infra designed for it, not implemented)
- Images in todos
- Reminders / alerts / notifications
- Shopping list mode
- Web and iOS apps

