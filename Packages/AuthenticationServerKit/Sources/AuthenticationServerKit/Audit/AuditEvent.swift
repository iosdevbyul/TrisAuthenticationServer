import Vapor

// Persist raw strings, not a PostgreSQL enum, so new event types need no schema change.
public enum AuditEventType: String, Codable, Sendable {
    case signUpSucceeded, loginSucceeded, loginFailed, refreshSucceeded, refreshRejected
    case logout, logoutOtherSessions, logoutAll, sessionRevoked
    case passwordChanged, passwordResetRequested, passwordResetSucceeded
    case emailVerificationSucceeded, emailVerificationResendRequested
    case emailChangeRequested, emailChangeSucceeded, accountWithdrawn
    case loginRateLimited, emailRateLimited

    var isNoisy: Bool {
        switch self {
        case .loginFailed, .refreshRejected, .loginRateLimited, .emailRateLimited,
             .passwordResetRequested, .emailVerificationResendRequested: true
        default: false
        }
    }
}

struct AuditRecorderKey: StorageKey { typealias Value = AuditLogService }

extension Request {
    public func auditEmail(_ email: String) {
        guard email.utf8.count <= 254 else { return }
        auditContext.emailHash = storage[AuditRecorderKey.self]?.identifierHash(email, kind: .email)
    }


}
