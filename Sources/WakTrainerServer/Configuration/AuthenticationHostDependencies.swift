import AuthenticationServerKit
import Vapor

/// Composition belongs to the host; the package never reads Railway/environment
/// settings or chooses Resend, branded templates or a trusted forwarding header.
enum AuthenticationHostDependencies {
    static func live() -> AuthenticationDependencies<Request> {
        .init(
            configuration: .init(
                urls: {
                    .init(passwordReset: Environment.get("PASSWORD_RESET_URL_BASE"),
                          emailVerification: Environment.get("EMAIL_VERIFICATION_URL_BASE"),
                          emailChange: Environment.get("EMAIL_CHANGE_URL_BASE"))
                },
                auditHashKey: { Environment.get("AUDIT_HASH_KEY") }
            ),
            renderEmail: { purpose, recipient, url in
                switch purpose {
                case .passwordReset: return .passwordReset(to: recipient, resetURL: url)
                case .emailVerification: return .signUpVerification(to: recipient, verificationURL: url)
                case .emailChange: return .emailChangeVerification(to: recipient, verificationURL: url)
                }
            },
            sendEmail: { message, request in
                try await ResendEmailTransport().send(message, on: request)
            },
            resolveIP: { request, purpose in
                switch purpose {
                case .login: return request.remoteAddress?.ipAddress ?? "unknown"
                case .email, .audit:
                    return EmailRateLimitService.clientIP(request,
                        trustRailway: Environment.get("EMAIL_TRUST_RAILWAY_PROXY") == "true")
                }
            }
        )
    }
}

private struct AuthenticationDependenciesKey: StorageKey {
    typealias Value = AuthenticationDependencies<Request>
}

extension Application {
    /// Configure before registering routes. The fallback also supports existing
    /// tests/tools that register AuthController without calling configure(_:).
    var authenticationDependencies: AuthenticationDependencies<Request> {
        get { storage[AuthenticationDependenciesKey.self] ?? AuthenticationHostDependencies.live() }
        set { storage[AuthenticationDependenciesKey.self] = newValue }
    }
}
