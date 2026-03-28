import Foundation
import GRDB
import ThreeDoCore

final class AppDatabase {
    let pool: DatabasePool

    /// Default init — opens (or creates) the database in ~/Library/Application Support/ThreeDo/
    convenience init() throws {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("ThreeDo", isDirectory: true)
        try FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        try self.init(path: appDir.appendingPathComponent("data.db").path)
    }

    /// Designated init — useful for testing with a custom or temp path.
    init(path: String) throws {
        pool = try DatabasePool(path: path)
        try migrate()
    }

    private func migrate() throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1_initial") { db in
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS workspaces (
                    id TEXT NOT NULL PRIMARY KEY,
                    name TEXT NOT NULL,
                    position INTEGER NOT NULL DEFAULT 0,
                    created_at DATETIME NOT NULL,
                    updated_at DATETIME NOT NULL,
                    deleted_at DATETIME
                )
                """)
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS todos (
                    id TEXT NOT NULL PRIMARY KEY,
                    workspace_id TEXT NOT NULL,
                    parent_id TEXT,
                    text TEXT NOT NULL DEFAULT '',
                    is_done BOOLEAN NOT NULL DEFAULT 0,
                    due_date DATETIME,
                    priority TEXT,
                    position REAL NOT NULL DEFAULT 0,
                    is_collapsed BOOLEAN NOT NULL DEFAULT 0,
                    created_at DATETIME NOT NULL,
                    updated_at DATETIME NOT NULL,
                    deleted_at DATETIME
                )
                """)
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS tags (
                    id TEXT NOT NULL PRIMARY KEY,
                    workspace_id TEXT NOT NULL,
                    name TEXT NOT NULL,
                    created_at DATETIME NOT NULL,
                    updated_at DATETIME NOT NULL,
                    deleted_at DATETIME
                )
                """)
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS todo_tags (
                    todo_id TEXT NOT NULL,
                    tag_id TEXT NOT NULL,
                    PRIMARY KEY (todo_id, tag_id)
                )
                """)
        }
        migrator.registerMigration("v2_tags_column") { db in
            try db.execute(sql: "ALTER TABLE todos ADD COLUMN tags TEXT NOT NULL DEFAULT ''")
        }
        try migrator.migrate(pool)
    }
}
