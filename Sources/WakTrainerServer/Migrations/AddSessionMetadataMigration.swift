import AuthenticationServerKit
import Fluent

/// Host migration identity compatibility wrapper; retained through Phase C.
struct AddSessionMetadataMigration: AsyncMigration {
    var name: String { "WakTrainerServer.AddSessionMetadataMigration" }
    func prepare(on database: any Database) async throws {
        try await AuthenticationMigrations.make(.addSessionMetadataMigration).prepare(on: database)
    }
    func revert(on database: any Database) async throws {
        try await AuthenticationMigrations.make(.addSessionMetadataMigration).revert(on: database)
    }
}
