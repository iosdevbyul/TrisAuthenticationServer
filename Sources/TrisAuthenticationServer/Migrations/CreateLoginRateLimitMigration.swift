import AuthenticationServerKit
import Fluent

/// Host migration identity compatibility wrapper; retained through Phase C.
struct CreateLoginRateLimitMigration: AsyncMigration {
    var name: String { "TrisAuthenticationServer.CreateLoginRateLimitMigration" }
    func prepare(on database: any Database) async throws {
        try await AuthenticationMigrations.make(.createLoginRateLimitMigration).prepare(on: database)
    }
    func revert(on database: any Database) async throws {
        try await AuthenticationMigrations.make(.createLoginRateLimitMigration).revert(on: database)
    }
}
