import Vapor
import Fluent
import SQLKit

struct EmailRateLimitService: Sendable {
    var policy: EmailRateLimitPolicy
    private let resolveIP: @Sendable (Request) -> String

    init(policy: EmailRateLimitPolicy = .init(), resolveIP: @escaping @Sendable (Request) -> String) {
        self.policy = policy
        self.resolveIP = resolveIP
    }

    func allow(to email: String, action: EmailAction, on req: Request) async throws -> Bool {
        let clientValues = req.headers["X-Client-ID"]
        let client = clientValues.count == 1 ? clientValues.first : nil
        return try await allow(
            to: email, clientID: client,
            ip: resolveIP(req),
            action: action, on: req.db
        )
    }

    func allow(to email: String, clientID: String?, ip: String,
               action: EmailAction, on db: any Database) async throws -> Bool {
        let recipient = AuthSession.hash(email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
        var buckets: [(String, EmailRateLimitPolicy.Window)] = [
            ("global", policy.global),
            ("action:" + AuthSession.hash(action.rawValue), policy.action),
            ("ip:" + AuthSession.hash(ip), policy.ip),
            ("recipient:" + recipient, policy.recipient)
        ]
        // Optional, untrusted abuse signal. Invalid/missing IDs retain all other limits.
        if let client = clientID?.trimmingCharacters(in: .whitespacesAndNewlines),
           !client.isEmpty, client.utf8.count <= 128 {
            buckets.append(("client:" + AuthSession.hash(client), policy.client))
        }
        if let window = policy.sensitiveRecipients[action] {
            buckets.append(("sensitive:" + AuthSession.hash(action.rawValue) + ":" + recipient, window))
        }
        guard let sql = db as? any SQLDatabase else { throw Abort(.internalServerError) }
        try await sql.raw("""
            DELETE FROM email_rate_limits WHERE bucket_key IN (
                SELECT bucket_key FROM email_rate_limits
                WHERE expires_at <= CURRENT_TIMESTAMP ORDER BY expires_at
                LIMIT 100 FOR UPDATE SKIP LOCKED
            )
            """).run()
        // Stable lock ordering across instances. Return false rather than throwing inside
        // the transaction: rejected requests must still consume their abuse quotas.
        let ordered = buckets.sorted { $0.0 < $1.0 }
        return try await db.transaction { transaction in
            guard let sql = transaction as? any SQLDatabase else { throw Abort(.internalServerError) }
            var allowed = true
            for (key, window) in ordered {
                guard let row = try await sql.raw("""
                    INSERT INTO email_rate_limits (bucket_key, attempts, expires_at)
                    VALUES (\(bind: key), 1, CURRENT_TIMESTAMP + \(bind: window.seconds) * INTERVAL '1 second')
                    ON CONFLICT (bucket_key) DO UPDATE SET
                        attempts = CASE WHEN email_rate_limits.expires_at <= CURRENT_TIMESTAMP THEN 1
                            ELSE LEAST(email_rate_limits.attempts + 1, \(bind: window.limit + 1)) END,
                        expires_at = CASE WHEN email_rate_limits.expires_at <= CURRENT_TIMESTAMP
                            THEN EXCLUDED.expires_at ELSE email_rate_limits.expires_at END
                    RETURNING attempts
                    """).first() else { throw Abort(.internalServerError) }
                if try row.decode(column: "attempts", as: Int.self) > window.limit { allowed = false }
            }
            return allowed
        }
    }
}
