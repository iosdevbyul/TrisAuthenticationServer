import AuthenticationServerKit
import Vapor
import NIOCore

// Phase B host-only dependency adapters. Remove these overloads when controllers
// receive package composition directly in Phase C; there is no duplicated SQL.
extension LoginRateLimiter {
    static func checkIP(_ req: Request) async throws {
        try await checkIP(req, resolveIP: { $0.application.authenticationDependencies.resolveIP($0, .login) })
    }
}

extension EmailRateLimitService {
    init(policy: EmailRateLimitPolicy = .init()) {
        self.init(policy: policy, resolveIP: { $0.application.authenticationDependencies.resolveIP($0, .email) })
    }

    static func clientIP(_ req: Request, trustRailway: Bool) -> String {
        // Enable only when ingress is restricted to Railway's trusted edge.
        // Never guess a trusted hop from arbitrary X-Forwarded-For input.
        if trustRailway, req.headers["X-Real-IP"].count == 1,
           let value = req.headers.first(name: "X-Real-IP"),
           let address = try? SocketAddress(ipAddress: value, port: 0),
           let ip = address.ipAddress {
            return ip
        }
        return req.remoteAddress?.ipAddress ?? "unknown"
    }

}

extension EmailService {
    init(transport: (any EmailSending)? = nil, limiter: EmailRateLimitService = .init()) {
        self.init(transport: transport, limiter: limiter, dependencies: { $0.application.authenticationDependencies })
    }
}

extension EmailVerificationService {
    init(emailService: EmailService, verificationURLBase: String? = nil) {
        self.init(emailService: emailService, verificationURLBase: verificationURLBase,
                  dependencies: { $0.application.authenticationDependencies })
    }
}

extension EmailChangeService {
    init(emailService: EmailService, verificationURLBase: String? = nil) {
        self.init(emailService: emailService, verificationURLBase: verificationURLBase,
                  dependencies: { $0.application.authenticationDependencies })
    }
}

extension AuditLogService {
    convenience init(hashKey: String? = AuthenticationHostDependencies.live().configuration.auditHashKey()) {
        self.init(hashKey: hashKey, resolveIP: { $0.application.authenticationDependencies.resolveIP($0, .audit) })
    }
}

extension MaintenancePolicy {
    static func configured(retentionDays value: String? = Environment.get("AUDIT_RETENTION_DAYS")) throws -> Self {
        guard let value else { return Self() }
        guard let days = Int(value), days >= minimumRetentionDays, days <= 365_000 else {
            throw Abort(.internalServerError, reason: "AUDIT_RETENTION_DAYS must be between 90 and 365000.")
        }
        return Self(auditRetentionDays: days)
    }
}
