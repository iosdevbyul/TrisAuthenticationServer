import AuthenticationServerKit
import Fluent

/// Host migration identity compatibility wrapper; retained through Phase C.
struct CreateEmailRateLimitMigration: AsyncMigration {
    var name: String { "WakTrainerServer.CreateEmailRateLimitMigration" }
    func prepare(on database: any Database) async throws {
        try await AuthenticationMigrations.make(.createEmailRateLimitMigration).prepare(on: database)
    }
    func revert(on database: any Database) async throws {
        try await AuthenticationMigrations.make(.createEmailRateLimitMigration).revert(on: database)
    }
}
