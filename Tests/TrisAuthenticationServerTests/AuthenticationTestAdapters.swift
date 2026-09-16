@testable import AuthenticationServerKit
@testable import TrisAuthenticationServer
import Vapor

// Existing integration fixtures retain explicit URL/transport overrides.
extension AuthController {
    init(emailService: EmailService = EmailService(), passwordResetURLBase: String? = nil,
         emailVerificationURLBase: String? = nil, emailChangeURLBase: String? = nil,
         auditLog: AuditLogService = .init()) {
        self.init(emailService: emailService, passwordResetURLBase: passwordResetURLBase,
                  emailVerificationURLBase: emailVerificationURLBase, emailChangeURLBase: emailChangeURLBase,
                  auditLog: auditLog, dependencies: { $0.application.authenticationDependencies })
    }
}

// Test-only compatibility for pre-extraction fixtures.
extension LoginRateLimiter {
    static func checkIP(_ req: Request) async throws {
        try await checkIP(req, resolveIP: { $0.application.authenticationDependencies.resolveIP($0, .login) })
    }
}

extension EmailRateLimitService {
    init(policy: EmailRateLimitPolicy = .init()) {
        self.init(policy: policy, resolveIP: { $0.application.authenticationDependencies.resolveIP($0, .email) })
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

