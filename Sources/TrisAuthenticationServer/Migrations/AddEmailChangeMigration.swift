import AuthenticationServerKit
import Fluent

/// Host migration identity compatibility wrapper; retained through Phase C.
struct AddEmailChangeMigration: AsyncMigration {
    var name: String { "WakTrainerServer.AddEmailChangeMigration" }
    func prepare(on database: any Database) async throws {
        try await AuthenticationMigrations.make(.addEmailChangeMigration).prepare(on: database)
    }
    func revert(on database: any Database) async throws {
        try await AuthenticationMigrations.make(.addEmailChangeMigration).revert(on: database)
    }
}
