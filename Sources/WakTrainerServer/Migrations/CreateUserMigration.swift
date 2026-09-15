import AuthenticationServerKit
import Fluent

/// Host migration identity compatibility wrapper; retained through Phase C.
struct CreateUserMigration: AsyncMigration {
    var name: String { "WakTrainerServer.CreateUserMigration" }
    func prepare(on database: any Database) async throws {
        try await AuthenticationMigrations.make(.createUserMigration).prepare(on: database)
    }
    func revert(on database: any Database) async throws {
        try await AuthenticationMigrations.make(.createUserMigration).revert(on: database)
    }
}
