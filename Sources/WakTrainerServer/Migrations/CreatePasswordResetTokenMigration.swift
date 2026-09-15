import AuthenticationServerKit
import Fluent

/// Host migration identity compatibility wrapper; retained through Phase C.
struct CreatePasswordResetTokenMigration: AsyncMigration {
    var name: String { "WakTrainerServer.CreatePasswordResetTokenMigration" }
    func prepare(on database: any Database) async throws {
        try await AuthenticationMigrations.make(.createPasswordResetTokenMigration).prepare(on: database)
    }
    func revert(on database: any Database) async throws {
        try await AuthenticationMigrations.make(.createPasswordResetTokenMigration).revert(on: database)
    }
}
