@testable import AuthenticationServerKit
@testable import TrisAuthenticationServer
import Fluent
import FluentPostgresDriver
import SQLKit
import Testing
import VaporTesting
import Foundation

@Suite("Extraction migration compatibility")
struct MigrationCompatibilityTests {
    @Test func originalHistoryAndCleanInstallation() async throws {
        let ledger = MigrationLedger()
        try await withApp(configure: { app in
            let name = try #require(Environment.get("TEST_DATABASE_NAME"))
            try #require(name == "waktrainer_test_auth")
            app.databases.use(.postgres(configuration: .init(
                hostname: Environment.get("TEST_DATABASE_HOST") ?? "127.0.0.1",
                port: Environment.get("TEST_DATABASE_PORT").flatMap(Int.init) ?? 5432,
                username: Environment.get("TEST_DATABASE_USERNAME") ?? "vapor",
                password: Environment.get("TEST_DATABASE_PASSWORD"), database: name, tls: .disable
            )), as: .psql)
            app.migrations.add(AuthenticationMigrationBaseline.migrations().map { MigrationProbe(base: $0, ledger: ledger) })
        }) { app in
            let sql = try #require(app.db as? any SQLDatabase)
            // This database is explicitly disposable. Clean any prior test/capture state.
            try await app.autoRevert()
            try await sql.raw("DROP TABLE IF EXISTS _fluent_migrations").run()
            let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
                .deletingLastPathComponent().deletingLastPathComponent()
            let fixture = try String(contentsOf: root.appendingPathComponent("Tests/Baselines/pre-extraction-schema.sql"), encoding: .utf8)
            let sqlText = fixture.split(separator: "\n").filter { !$0.hasPrefix("--") }.joined(separator: "\n")
            // Trusted, committed pg_dump fixture, not user input. It contains no functions
            // or semicolons in literals; statement splitting is intentional and bounded.
            for statement in sqlText.split(separator: ";") {
                let text = statement.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty { try await sql.raw(SQLQueryString(stringLiteral: text)).run() }
            }
            let original = try await schemaSignature(sql)
            let originalIDs = try await objectIDs(sql)
            let originalHistory = try await history(sql)
            #expect(originalHistory.count == 11)
            #expect(try await app.migrator.previewPrepareBatch().get().isEmpty)
            await ledger.reset()
            try await app.autoMigrate()
            #expect(await ledger.prepared == 0)
            #expect(try await objectIDs(sql) == originalIDs)
            #expect(try await schemaSignature(sql) == original)
            #expect(try await history(sql) == originalHistory)

            // Fresh installation must produce the exact original columns/defaults,
            // nullability, constraints/FKs and index definitions.
            try await app.autoRevert()
            await ledger.reset()
            try await app.autoMigrate()
            #expect(await ledger.prepared == 11)
            #expect(try await schemaSignature(sql) == original)
            #expect(try await app.migrator.previewPrepareBatch().get().isEmpty)
            try await app.autoRevert()
        }
    }

    private func strings(_ sql: any SQLDatabase, _ query: SQLQueryString) async throws -> [String] {
        try await sql.raw(query).all().map { try $0.decode(column: "value", as: String.self) }.sorted()
    }

    private func history(_ sql: any SQLDatabase) async throws -> [String] {
        try await strings(sql, "SELECT id::text || ':' || name || ':' || batch::text AS value FROM _fluent_migrations")
    }

    private func objectIDs(_ sql: any SQLDatabase) async throws -> [String] {
        try await strings(sql, "SELECT c.oid::text || ':' || c.relname AS value FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE n.nspname = 'public' AND c.relkind IN ('r','i')")
    }

    private func schemaSignature(_ sql: any SQLDatabase) async throws -> [String] {
        try await strings(sql, """
            SELECT 'column:' || table_name || ':' || column_name || ':' || ordinal_position::text || ':' ||
                   data_type || ':' || udt_name || ':' || is_nullable || ':' || COALESCE(column_default,'') || ':' ||
                   COALESCE(character_maximum_length::text,'') AS value
            FROM information_schema.columns WHERE table_schema = 'public' AND table_name <> '_fluent_migrations'
            UNION ALL
            SELECT 'constraint:' || r.relname || ':' || c.conname || ':' || pg_get_constraintdef(c.oid)
            FROM pg_constraint c JOIN pg_class r ON r.oid = c.conrelid JOIN pg_namespace n ON n.oid = r.relnamespace
            WHERE n.nspname = 'public' AND r.relname <> '_fluent_migrations'
            UNION ALL
            SELECT 'index:' || tablename || ':' || indexname || ':' || indexdef FROM pg_indexes
            WHERE schemaname = 'public' AND tablename <> '_fluent_migrations'
            """)
    }
}

private actor MigrationLedger {
    var prepared = 0
    func record() { prepared += 1 }
    func reset() { prepared = 0 }
}

private struct MigrationProbe: AsyncMigration {
    let base: any Migration
    let ledger: MigrationLedger
    var name: String { base.name }
    func prepare(on database: any Database) async throws {
        await ledger.record()
        try await base.prepare(on: database).get()
    }
    func revert(on database: any Database) async throws {
        try await base.revert(on: database).get()
    }
}
