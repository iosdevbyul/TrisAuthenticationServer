import AuthenticationServerKit
import Fluent

/// Host migration identity compatibility wrapper; retained through Phase C.
struct AddEmailVerificationMigration: AsyncMigration {
    var name: String { "TrisAuthenticationServer.AddEmailVerificationMigration" }
    func prepare(on database: any Database) async throws {
        try await AuthenticationMigrations.make(.addEmailVerificationMigration).prepare(on: database)
    }
    func revert(on database: any Database) async throws {
        try await AuthenticationMigrations.make(.addEmailVerificationMigration).revert(on: database)
    }
}
