import Foundation
import GRDB
import ThreeDoCore

// MARK: - Workspace GRDB

extension Workspace: FetchableRecord, PersistableRecord {
    public static var databaseTableName: String { "workspaces" }
}

// MARK: - Priority GRDB

extension Priority: DatabaseValueConvertible {
    public var databaseValue: DatabaseValue { rawValue.databaseValue }
    public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> Priority? {
        String.fromDatabaseValue(dbValue).flatMap(Priority.init(rawValue:))
    }
}

// MARK: - Todo GRDB

extension Todo: FetchableRecord, PersistableRecord {
    public static var databaseTableName: String { "todos" }
}
