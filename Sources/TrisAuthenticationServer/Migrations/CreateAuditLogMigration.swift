import AuthenticationServerKit
import Fluent

/// Host migration identity compatibility wrapper; retained through Phase C.
struct CreateAuditLogMigration: AsyncMigration {
    var name: String { "TrisAuthenticationServer.CreateAuditLogMigration" }
    func prepare(on database: any Database) async throws {
        try await AuthenticationMigrations.make(.createAuditLogMigration).prepare(on: database)
    }
    func revert(on database: any Database) async throws {
        try await AuthenticationMigrations.make(.createAuditLogMigration).revert(on: database)
    }
}
