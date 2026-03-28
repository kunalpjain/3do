# 3do — Architecture & Technical Decisions

---

## Language & Framework

**Decision: Swift + SwiftUI**

- Native macOS performance, Apple-optimized rendering pipeline
- SwiftUI gives direct access to AppKit primitives when needed
- Fastest path to a real Mac app (menu bar, keyboard shortcuts, system theme)
- Easiest bridge to future iOS app (shared Swift code, shared data layer)

---

## Data Storage

**Decision: SQLite via GRDB.swift**

- SQLite is the fastest embedded database for random-access reads/writes
- GRDB.swift is a well-maintained Swift wrapper with type-safe queries
- Keeps the data file portable — a single `.db` file the user can back up
- Schema designed from day one for sync (UUIDs as primary keys, `updated_at` timestamps, soft deletes via `deleted_at`)

### Schema Design Principles (sync-ready)
- Every record has a `uuid` (primary key, globally unique)
- Every record has `created_at`, `updated_at`, `deleted_at` (soft delete)
- No auto-increment integer IDs used as foreign keys — UUID refs only
- Conflict resolution strategy: last-write-wins on `updated_at` (can upgrade later)

### Tables (rough)
```
workspaces    (uuid, name, position, created_at, updated_at, deleted_at)
todos         (uuid, workspace_uuid, parent_uuid nullable, text, done, due_date,
               priority, position, created_at, updated_at, deleted_at)
tags          (uuid, workspace_uuid, name, created_at, updated_at, deleted_at)
todo_tags     (todo_uuid, tag_uuid)
```

---

## Sync Infrastructure (designed now, implemented later)

- Data model is UUID-keyed and timestamped — ready for a sync backend
- Planned sync approach: custom backend (REST or WebSocket) with a simple
  change-log / vector-clock model, or CloudKit (to be decided)
- Local DB is always the source of truth; sync is eventual and non-blocking
- When sync is implemented, it runs in a background Swift actor — never blocks UI

---

## App Architecture

```
3do/
├── App/
│   ├── ThreeDOApp.swift          # App entry point
│   └── AppState.swift            # Top-level observable state
├── Features/
│   ├── Workspaces/               # Workspace switcher, CRUD
│   ├── Todos/                    # Todo list, tree, editing
│   ├── Search/                   # Cmd+F search
│   └── Settings/                 # Themes, shortcuts reference
├── Data/
│   ├── DB.swift                  # GRDB setup, migrations
│   ├── Models/                   # Workspace, Todo, Tag structs
│   └── Repositories/             # WorkspaceRepo, TodoRepo, TagRepo
├── UI/
│   ├── Theme/                    # Colors, fonts, macOS Classic style
│   └── Components/               # Reusable views (rows, buttons, inputs)
└── Utilities/
    └── KeyboardHandler.swift     # Global key event routing
```

---

## UI / Rendering

- **No animations:** `.animation(.none)` set globally; all transitions instant
- **Custom key handling:** NSEvent monitoring for vim keys + all custom shortcuts
- **Theme:** Custom `Theme` struct with flat grey palette, 1px square borders,
  system monospace or Chicago-style font, no corner radii
- **Density:** Row height fixed at ~22px (compact), no padding waste

---

## Decisions Log

| # | Decision | Rationale |
|---|----------|-----------|
| 1 | Swift + SwiftUI | Native Mac perf, reuse on iOS later |
| 2 | SQLite via GRDB | Fastest embedded I/O, portable file |
| 3 | UUID PKs everywhere | Required for future sync without refactor |
| 4 | Soft deletes | Sync needs tombstones; no data loss |
| 5 | No animations anywhere | User requirement; also improves perf |
| 6 | macOS Classic aesthetic | User requirement; flat, square, dense |
| 7 | Sync infra deferred | Design now, implement when going multi-device |
