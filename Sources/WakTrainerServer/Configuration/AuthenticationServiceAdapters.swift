import AuthenticationServerKit
import Vapor

// Environment validation remains a host responsibility.
extension MaintenancePolicy {
    static func configured(retentionDays value: String? = Environment.get("AUDIT_RETENTION_DAYS")) throws -> Self {
        guard let value else { return Self() }
        guard let days = Int(value), days >= minimumRetentionDays, days <= 365_000 else {
            throw Abort(.internalServerError, reason: "AUDIT_RETENTION_DAYS must be between 90 and 365000.")
        }
        return Self(auditRetentionDays: days)
    }
}
