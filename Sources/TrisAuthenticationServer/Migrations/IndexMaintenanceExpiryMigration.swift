import AuthenticationServerKit
import Fluent

/// Host migration identity compatibility wrapper; retained through Phase C.
struct IndexMaintenanceExpiryMigration: AsyncMigration {
    var name: String { "TrisAuthenticationServer.IndexMaintenanceExpiryMigration" }
    func prepare(on database: any Database) async throws {
        try await AuthenticationMigrations.make(.indexMaintenanceExpiryMigration).prepare(on: database)
    }
    func revert(on database: any Database) async throws {
        try await AuthenticationMigrations.make(.indexMaintenanceExpiryMigration).revert(on: database)
    }
}
