@testable import AuthenticationServerKit
import Vapor

// Existing integration fixtures retain explicit URL/transport overrides.
extension AuthController {
    init(emailService: EmailService = EmailService(), passwordResetURLBase: String? = nil,
         emailVerificationURLBase: String? = nil, emailChangeURLBase: String? = nil,
         auditLog: AuditLogService = .init()) {
        self.init(emailService: emailService, passwordResetURLBase: passwordResetURLBase,
                  emailVerificationURLBase: emailVerificationURLBase, emailChangeURLBase: emailChangeURLBase,
                  auditLog: auditLog, dependencies: { $0.application.testAuthenticationDependencies })
    }
}

// Test-only compatibility for pre-extraction fixtures.
extension LoginRateLimiter {
    static func checkIP(_ req: Request) async throws {
        try await checkIP(req, resolveIP: { $0.application.testAuthenticationDependencies.resolveIP($0, .login) })
    }
}

extension EmailRateLimitService {
    init(policy: EmailRateLimitPolicy = .init()) {
        self.init(policy: policy, resolveIP: { $0.application.testAuthenticationDependencies.resolveIP($0, .email) })
    }
}

extension EmailService {
    init(transport: (any EmailSending)? = nil, limiter: EmailRateLimitService = .init()) {
        self.init(transport: transport, limiter: limiter, dependencies: { $0.application.testAuthenticationDependencies })
    }
}

extension EmailVerificationService {
    init(emailService: EmailService, verificationURLBase: String? = nil) {
        self.init(emailService: emailService, verificationURLBase: verificationURLBase,
                  dependencies: { $0.application.testAuthenticationDependencies })
    }
}

extension EmailChangeService {
    init(emailService: EmailService, verificationURLBase: String? = nil) {
        self.init(emailService: emailService, verificationURLBase: verificationURLBase,
                  dependencies: { $0.application.testAuthenticationDependencies })
    }
}

extension AuditLogService {
    convenience init(hashKey: String? = TestDependencies.live().configuration.auditHashKey()) {
        self.init(hashKey: hashKey, resolveIP: { $0.application.testAuthenticationDependencies.resolveIP($0, .audit) })
    }
}


extension APIErrorMiddleware {
    static func install(on app: Application) {
        app.middleware = .init()
        app.middleware.use(APIErrorMiddleware())
    }
}

enum TestDependencies {
    static func live() -> AuthenticationDependencies<Request> {
        .init(configuration: .init(urls: { .init() }, auditHashKey: { nil }),
              renderEmail: { purpose, recipient, link in
                  let subject: String
                  switch purpose {
                  case .passwordReset: subject = "reset"
                  case .emailVerification: subject = "verify"
                  case .emailChange: subject = "change"
                  }
                  return .init(recipient: recipient, subject: subject,
                               html: "<a href=\"" + link.replacingOccurrences(of: "&", with: "&amp;") + "\">continue</a>")
              }, sendEmail: { _, _ in throw Abort(.internalServerError) },
              resolveIP: { request, _ in request.remoteAddress?.ipAddress ?? "unknown" })
    }
}

private struct TestDependenciesKey: StorageKey { typealias Value = AuthenticationDependencies<Request> }
extension Application {
    var testAuthenticationDependencies: AuthenticationDependencies<Request> {
        get { storage[TestDependenciesKey.self] ?? TestDependencies.live() }
        set { storage[TestDependenciesKey.self] = newValue }
    }
}

typealias CreatePasswordResetTokenMigration = CreatePasswordResetTokenMigrationImplementation

typealias AddEmailChangeMigration = AddEmailChangeMigrationImplementation

typealias CreateRefreshTokenMigration = CreateRefreshTokenMigrationImplementation

typealias IndexMaintenanceExpiryMigration = IndexMaintenanceExpiryMigrationImplementation

typealias AddEmailVerificationMigration = AddEmailVerificationMigrationImplementation

typealias CreateAuditLogMigration = CreateAuditLogMigrationImplementation

typealias IndexSessionUserExpiryMigration = IndexSessionUserExpiryMigrationImplementation

typealias CreateLoginRateLimitMigration = CreateLoginRateLimitMigrationImplementation

typealias CreateEmailRateLimitMigration = CreateEmailRateLimitMigrationImplementation

typealias CreateUserMigration = CreateUserMigrationImplementation

typealias AddSessionMetadataMigration = AddSessionMetadataMigrationImplementation
