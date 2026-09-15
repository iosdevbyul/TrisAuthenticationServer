/// A delivery value, not an HTTP API DTO. The host owns branding and rendering.
public struct AuthenticationEmail: Sendable, Equatable {
    public let recipient: String
    public let subject: String
    public let html: String

    public init(recipient: String, subject: String, html: String) {
        self.recipient = recipient
        self.subject = subject
        self.html = html
    }
}

public enum AuthenticationEmailPurpose: Sendable {
    case passwordReset, emailVerification, emailChange
}

/// Kept separate because login must not inherit email/audit proxy trust policy.
public enum AuthenticationIPPurpose: Sendable {
    case login, email, audit
}

/// Context is supplied by the host (currently Vapor.Request). This boundary does
/// not require the package to import the host or select an HTTP framework.
/// Closures must not log credentials, rendered links or configuration secrets.
public struct AuthenticationDependencies<Context: Sendable>: Sendable {
    public var configuration: AuthenticationConfiguration
    public var renderEmail: @Sendable (AuthenticationEmailPurpose, String, String) -> AuthenticationEmail
    public var sendEmail: @Sendable (AuthenticationEmail, Context) async throws -> Void
    public var resolveIP: @Sendable (Context, AuthenticationIPPurpose) -> String

    public init(
        configuration: AuthenticationConfiguration,
        renderEmail: @escaping @Sendable (AuthenticationEmailPurpose, String, String) -> AuthenticationEmail,
        sendEmail: @escaping @Sendable (AuthenticationEmail, Context) async throws -> Void,
        resolveIP: @escaping @Sendable (Context, AuthenticationIPPurpose) -> String
    ) {
        self.configuration = configuration
        self.renderEmail = renderEmail
        self.sendEmail = sendEmail
        self.resolveIP = resolveIP
    }
}
