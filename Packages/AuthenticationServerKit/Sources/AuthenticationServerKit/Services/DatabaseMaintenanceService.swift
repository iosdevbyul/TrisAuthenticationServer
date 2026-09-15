import Vapor
import Fluent
import SQLKit

public struct MaintenancePolicy: Sendable {
    public static let minimumRetentionDays = 90
    public var auditRetentionDays = minimumRetentionDays
    public var batchSize = 500
    public var maxBatches = 20

    public init(auditRetentionDays: Int = minimumRetentionDays, batchSize: Int = 500, maxBatches: Int = 20) {
        self.auditRetentionDays = auditRetentionDays
        self.batchSize = batchSize
        self.maxBatches = maxBatches
    }
}

public struct DatabaseMaintenanceService: Sendable {
    enum Target: String, CaseIterable, Sendable {
        case sessions = "refresh_tokens"
        case passwordReset = "password_reset_tokens"
        case emailVerification = "email_verification_tokens"
        case emailChange = "email_change_tokens"
        case loginRateLimits = "login_rate_limits"
        case emailRateLimits = "email_rate_limits"
        case auditLogs = "audit_logs"

        var key: String { self == .loginRateLimits || self == .emailRateLimits ? "bucket_key" : "id" }
        var expiry: String { self == .auditLogs ? "occurred_at" : "expires_at" }
    }

    public struct Result: Sendable {
        var deleted: [Target: Int] = [:]
        var failed: Set<Target> = []
        var capped: Set<Target> = []
        public var succeeded: Bool { failed.isEmpty }
    }

    var policy: MaintenancePolicy

    public init(policy: MaintenancePolicy = .init()) { self.policy = policy }

    // The caller supplies one immutable cutoff for the entire run, including all batches.
    public func run(on database: any Database, cutoff: Date, logger: Logger) async -> Result {
        var result = Result()
        for target in Target.allCases {
            let start = ContinuousClock.now
            var count = 0
            do {
                for batch in 0..<policy.maxBatches {
                    let deleted = try await deleteBatch(target, on: database, cutoff: cutoff)
                    count += deleted
                    if deleted < policy.batchSize { break }
                    if batch == policy.maxBatches - 1 { result.capped.insert(target) }
                }
            } catch {
                // Never log database errors or SQL bindings; continue with independent targets.
                result.failed.insert(target)
            }
            result.deleted[target] = count
            logger.info("Database maintenance target completed", metadata: [
                "target": .string(target.rawValue), "deleted": .string(String(count)),
                "duration": .string(String(describing: start.duration(to: .now))),
                "status": .string(result.failed.contains(target) ? "failed" : "succeeded"),
                "capped": .string(String(result.capped.contains(target)))
            ])
        }
        return result
    }

    func deleteBatch(_ target: Target, on database: any Database, cutoff: Date) async throws -> Int {
        guard policy.auditRetentionDays >= MaintenancePolicy.minimumRetentionDays,
              policy.auditRetentionDays <= 365_000, policy.batchSize > 0, policy.maxBatches > 0 else {
            throw Abort(.internalServerError, reason: "Invalid maintenance policy.")
        }
        let expiry = target == .auditLogs
            ? cutoff.addingTimeInterval(-Double(policy.auditRetentionDays) * 86_400) : cutoff
        return try await database.transaction { transaction in
            guard let sql = transaction as? any SQLDatabase else { throw Abort(.internalServerError) }
            try await sql.raw("SET LOCAL statement_timeout = '2s'").run()
            try await sql.raw("SET LOCAL lock_timeout = '100ms'").run()
            // Identifiers and operator come exclusively from the closed target enum.
            // Candidate locks remain held through DELETE, including against rate-limit upserts.
            let rows = try await sql.raw("""
                WITH candidates AS (
                    SELECT \(ident: target.key) FROM \(ident: target.rawValue)
                    WHERE \(ident: target.expiry) \(unsafeRaw: target == .auditLogs ? "<" : "<=") \(bind: expiry)
                    ORDER BY \(ident: target.expiry), \(ident: target.key)
                    LIMIT \(bind: policy.batchSize) FOR UPDATE SKIP LOCKED
                ), deleted AS (
                    DELETE FROM \(ident: target.rawValue) AS target USING candidates
                    WHERE target.\(ident: target.key) = candidates.\(ident: target.key)
                    RETURNING 1
                ) SELECT COUNT(*)::int AS count FROM deleted
                """).all()
            guard let row = rows.first else { throw Abort(.internalServerError) }
            return try row.decode(column: "count", as: Int.self)
        }
    }
}

