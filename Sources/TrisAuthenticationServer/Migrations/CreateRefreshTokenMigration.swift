import AuthenticationServerKit
import Fluent

/// Host migration identity compatibility wrapper; retained through Phase C.
struct CreateRefreshTokenMigration: AsyncMigration {
    var name: String { "TrisAuthenticationServer.CreateRefreshTokenMigration" }
    func prepare(on database: any Database) async throws {
        try await AuthenticationMigrations.make(.createRefreshTokenMigration).prepare(on: database)
    }
    func revert(on database: any Database) async throws {
        try await AuthenticationMigrations.make(.createRefreshTokenMigration).revert(on: database)
    }
}
