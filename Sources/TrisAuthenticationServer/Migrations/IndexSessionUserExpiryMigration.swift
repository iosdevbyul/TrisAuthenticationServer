import AuthenticationServerKit
import Fluent

/// Host migration identity compatibility wrapper; retained through Phase C.
struct IndexSessionUserExpiryMigration: AsyncMigration {
    var name: String { "TrisAuthenticationServer.IndexSessionUserExpiryMigration" }
    func prepare(on database: any Database) async throws {
        try await AuthenticationMigrations.make(.indexSessionUserExpiryMigration).prepare(on: database)
    }
    func revert(on database: any Database) async throws {
        try await AuthenticationMigrations.make(.indexSessionUserExpiryMigration).revert(on: database)
    }
}
