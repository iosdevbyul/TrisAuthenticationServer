import Vapor

/// Explicit authentication registration. Adds the existing 17 routes under /auth.
/// Register on a grouped RoutesBuilder to add a host-owned outer prefix.
/// Database/JWT setup and error middleware installation remain host responsibilities.
public struct AuthenticationRoutes: RouteCollection {
    private let controller: AuthController

    public init(dependencies: @escaping @Sendable (Request) -> AuthenticationDependencies<Request>,
                auditHashKey: String?, emailRateLimitPolicy: EmailRateLimitPolicy = .init()) {
        let limiter = EmailRateLimitService(policy: emailRateLimitPolicy,
            resolveIP: { dependencies($0).resolveIP($0, .email) })
        let email = EmailService(limiter: limiter, dependencies: dependencies)
        let audit = AuditLogService(hashKey: auditHashKey,
            resolveIP: { dependencies($0).resolveIP($0, .audit) })
        controller = AuthController(emailService: email, auditLog: audit, dependencies: dependencies)
    }

    public func boot(routes: any RoutesBuilder) throws {
        try controller.boot(routes: routes)
    }
}
