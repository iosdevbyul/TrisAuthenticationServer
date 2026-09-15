import Vapor

// No request bodies, credential-bearing models, raw identifiers, URLs or error strings.
struct AuditContext: Sendable {
    var userID: UUID?
    var sessionManagementID: UUID?
    var emailHash: String?
    var emailRateLimited: AuditMetadata.Action?
}

private struct AuditContextKey: StorageKey { typealias Value = AuditContext }
extension Request {
    var auditContext: AuditContext {
        get { storage[AuditContextKey.self] ?? .init() }
        set { storage[AuditContextKey.self] = newValue }
    }

    func auditIdentity(_ userID: UUID, session: RefreshToken? = nil) {
        auditContext.userID = userID
        if let session { auditContext.sessionManagementID = session.managementID ?? session.id }
    }
}
