import Fluent
import SQLKit
import Testing
import VaporTesting

/// Fluent invokes transaction closures through an EventLoopFuture callback, which does not
/// inherit Swift Testing's task locals. Run assertions/requests in a task created by the
/// test, while Fluent still owns BEGIN/COMMIT/ROLLBACK and the borrowed connection.
/// Always join that task, including when acquiring the connection or BEGIN fails.
func withTestTransaction<T: Sendable>(
    on database: any Database,
    _ body: @escaping @Sendable (any Database) async throws -> T
) async throws -> T {
    let connection = TestHandoff<any Database>()
    let operation = Task {
        let transaction = try await connection.get()
        try #require(Test.current != nil, "Transaction fixture must retain Swift Testing context")
        return try await body(transaction)
    }
    do {
        return try await database.transaction { transaction in
            await connection.resolve(.success(transaction))
            return try await operation.value
        }
    } catch {
        await connection.resolve(.failure(error))
        _ = try? await operation.value
        throw error
    }
}

/// A one-shot handoff. Resolving a failure also releases a waiter if setup failed.
actor TestHandoff<Value: Sendable> {
    private var result: Result<Value, any Error>?
    private var waiter: CheckedContinuation<Value, any Error>?

    func get() async throws -> Value {
        if let result { return try result.get() }
        return try await withCheckedThrowingContinuation { waiter = $0 }
    }

    func resolve(_ result: Result<Value, any Error>) {
        guard self.result == nil else { return }
        self.result = result
        waiter?.resume(with: result)
        waiter = nil
    }
}

/// Revert even when configuration or the test throws, before withApp shuts down pools.
/// Tests must finish all request tasks before returning to this scope.
func withAuthenticationTestApp(
    configure: (Application) async throws -> Void,
    _ test: (Application) async throws -> Void
) async throws {
    try await withApp { app in
        do {
            try await configure(app)
            try await test(app)
        } catch {
            if !app.databases.ids().isEmpty {
                do { try await app.autoRevert() }
                catch { Issue.record(error, Comment(rawValue: "Authentication fixture cleanup failed")) }
            }
            throw error
        }
        try await app.autoRevert()
    }
}

/// Failure-path regression: the body keeps test context, ROLLBACK completes, and a
/// subsequent query can use the pool before the Application is shut down.
func verifyTransactionFixtureRollback(_ app: Application) async throws {
    enum FixtureFailure: Error { case expected }
    let key = "fixture-rollback-" + UUID().uuidString
    do {
        try await withTestTransaction(on: app.db) { db -> Void in
            let sql = try #require(db as? any SQLDatabase)
            try await sql.raw("INSERT INTO login_rate_limits VALUES (\(bind: key), 1, CURRENT_TIMESTAMP)").run()
            throw FixtureFailure.expected
        }
        Issue.record("Transaction fixture should propagate the body's error")
    } catch FixtureFailure.expected {
        let sql = try #require(app.db as? any SQLDatabase)
        #expect(try await sql.raw("SELECT bucket_key FROM login_rate_limits WHERE bucket_key = \(bind: key)").first() == nil)
    }
}

extension AuthIntegrationTests {
    @Test func configurationFailureShutsDownApplication() async throws {
        enum FixtureFailure: Error { case expected }
        var application: Application?
        do {
            try await withAuthenticationTestApp(configure: { app in
                application = app
                throw FixtureFailure.expected
            }) { _ in
                Issue.record("Test body must not run after configuration fails")
            }
            Issue.record("Configuration failure must propagate")
        } catch FixtureFailure.expected {
            #expect(try #require(application).didShutdown)
        }
    }
}
