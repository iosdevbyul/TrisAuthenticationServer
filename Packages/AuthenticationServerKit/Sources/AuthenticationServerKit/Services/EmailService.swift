import Vapor

/// Transport abstraction. Application code uses EmailService.withRequest so the
/// quota is consumed before account lookup or message/token preparation.
public protocol EmailSending: Sendable {
    func send(_ message: EmailMessage, on req: Request) async throws
}

public typealias EmailMessage = AuthenticationEmail

public struct EmailService: Sendable {
    private let transport: (any EmailSending)?
    private let limiter: EmailRateLimitService
    private let dependencies: @Sendable (Request) -> AuthenticationDependencies<Request>

    public init(transport: (any EmailSending)? = nil, limiter: EmailRateLimitService,
                dependencies: @escaping @Sendable (Request) -> AuthenticationDependencies<Request>) {
        self.dependencies = dependencies
        self.transport = transport
        self.limiter = limiter
    }

    /// Returns false when throttled. The preparation closure is never run then.
    /// The message recipient is bound to the quota; each request sends at most once.
    public func withRequest(to email: String, action: EmailAction, on req: Request,
                     prepare: () async throws -> EmailMessage?) async throws -> Bool {
        req.auditEmail(email)
        guard try await limiter.allow(to: email, action: action, on: req) else {
            req.auditContext.emailRateLimited = AuditMetadata.Action(rawValue: action.rawValue)
            return false
        }
        if let message = try await prepare() {
            guard message.recipient == email else { throw APIError(.internalError) }
            if let transport {
                try await transport.send(message, on: req)
            } else {
                try await dependencies(req).sendEmail(message, req)
            }
        }
        return true
    }
}

