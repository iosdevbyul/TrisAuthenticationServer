import AuthenticationServerKit
import Vapor
import NIOCore

/// Composition belongs to the host; the package never reads Railway/environment
/// settings or chooses Resend, branded templates or a trusted forwarding header.
enum AuthenticationHostDependencies {
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
                    return Self.clientIP(request,
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
    /// tests/tools that register authentication routes without calling configure(_:).
    var authenticationDependencies: AuthenticationDependencies<Request> {
        get { storage[AuthenticationDependenciesKey.self] ?? AuthenticationHostDependencies.live() }
        set { storage[AuthenticationDependenciesKey.self] = newValue }
    }
}
