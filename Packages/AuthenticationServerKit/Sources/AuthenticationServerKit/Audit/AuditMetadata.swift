import Foundation

struct AuditMetadata: Codable, Sendable {
    enum Reason: String, Codable, Sendable { case invalidCredentials, invalidRefresh, rateLimited }
    enum Endpoint: String, Codable, Sendable {
        case signup, login, refresh, logout, logoutOtherSessions, logoutAll, sessionRevoke
        case changePassword, forgotPassword, resetPassword, verifyEmail, resendVerificationEmail
        case requestEmailChange, confirmEmailChange, withdraw
    }
    enum Action: String, Codable, Sendable { case passwordReset, signUpVerification, emailChangeVerification }
    var reasonCode: Reason?
    var endpoint: Endpoint
    var statusCode: UInt
    var action: Action?

    init(reasonCode: Reason? = nil, endpoint: Endpoint, statusCode: UInt, action: Action? = nil) {
        self.reasonCode = reasonCode
        self.endpoint = endpoint
        self.statusCode = statusCode
        self.action = action
    }
}

