/// Host-owned URL values. Validation and link construction remain in the existing
/// handlers during Phase A, including their original failure timing.
public struct AuthenticationURLs: Sendable, Equatable {
    public var passwordReset: String?
    public var emailVerification: String?
    public var emailChange: String?

    public init(passwordReset: String? = nil, emailVerification: String? = nil, emailChange: String? = nil) {
        self.passwordReset = passwordReset
        self.emailVerification = emailVerification
        self.emailChange = emailChange
    }
}

/// Providers preserve lazy host configuration lookup. They must be thread-safe.
/// No environment access, validation, logging or secret defaults occur here.
public struct AuthenticationConfiguration: Sendable {
    public var urls: @Sendable () -> AuthenticationURLs
    public var auditHashKey: @Sendable () -> String?

    public init(urls: @escaping @Sendable () -> AuthenticationURLs,
                auditHashKey: @escaping @Sendable () -> String?) {
        self.urls = urls
        self.auditHashKey = auditHashKey
    }
}
