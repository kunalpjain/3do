# 3do

A keyboard-driven, hierarchical todo app for macOS with a retro macOS Classic aesthetic.

## Features

- **Unlimited nesting** — indent/unindent todos into a tree; collapse branches to focus
- **Keyboard-first** — every action reachable without a mouse (vim-style navigation)
- **Multiple workspaces** — isolated todo trees, switch instantly with Cmd+1–9
- **Priority & tags** — badge todos with L/M/H priority and free-form tags
- **Due dates** — quick entry (`3/15` or `3/15/26`) plus a graphical calendar picker
- **Undo** — in-memory undo stack for all mutations (Cmd+Z)
- **Fast search** — live filter with Cmd+F
- **Offline, local-only** — all data lives in `~/Library/Application Support/ThreeDo/data.db`

## Keyboard Shortcuts

### Navigation
| Key | Action |
|-----|--------|
| `j` / `↓` | Select next |
| `k` / `↑` | Select previous |
| `h` / `←` | Collapse (or unindent) |
| `l` / `→` | Expand (or indent) |
| `Shift+j/k` | Extend selection (multi-select) |

### Editing
| Key | Action |
|-----|--------|
| `Enter` / `i` | Edit selected todo |
| `n` | New todo below selected |
| `Esc` | Commit edit / close |
| `Tab` | Indent |
| `Shift+Tab` | Unindent |

### Actions
| Key | Action |
|-----|--------|
| `Space` | Toggle done |
| `p` | Cycle priority (L → M → H → none) |
| `d` | Set due date |
| `t` | Edit tags |
| `Backspace` | Delete todo |
| `Cmd+Z` | Undo |

### View
| Key | Action |
|-----|--------|
| `Cmd+F` | Search |
| `Cmd+↑` / `↓` | Move todo up / down |
| `Cmd+1–9` | Switch workspace |
| `?` | Show keyboard shortcuts |

## Building & Running

Requires **macOS 14+** and the **Xcode Command Line Tools** (`xcode-select --install`).

```bash
# Run in development
make run

# Run tests
make test

# Build a release .app bundle (opens automatically)
make app

# Build release binary only
make build

# Clean build artifacts
make clean
```

## Architecture

The project is a Swift Package with three targets:

```
ThreeDoCore/   Pure business logic — no UI, no database. Fully unit-tested.
               Models.swift     Workspace, Todo, Priority, FlatTodo, UndoAction
               TodoLogic.swift  Stateless tree manipulation, date parsing, tag parsing
               EditSession.swift Value type for in-progress edit state

ThreeDo/       macOS app — SwiftUI views + GRDB SQLite layer.
               AppState.swift   @MainActor reactive state, keyboard event routing
               Data/            DatabasePool setup, schema migrations, GRDB conformances
               Views/           ContentView, TodoListView, TodoRowView, sheets, Theme

ThreeDoTests/  Standalone executable test runner (no XCTest dependency).
               TodoLogicTests.swift  176 tests across 14 suites
```

### Data storage

SQLite via [GRDB.swift](https://github.com/groue/GRDB.swift), stored at:

```
~/Library/Application Support/ThreeDo/data.db
```

The schema uses UUID primary keys, soft deletes (`deleted_at`), and fractional `position` values for ordering — designed to support future sync without a migration.

### Privacy

- No network requests, no analytics, no telemetry
- All data stays on device; nothing is sent anywhere
- Single dependency: GRDB.swift (SQLite wrapper)

## License

MIT
