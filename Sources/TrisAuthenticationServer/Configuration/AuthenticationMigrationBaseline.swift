import Fluent

/// Existing host migration registration order. No migration implementation moves in Phase A.
enum AuthenticationMigrationBaseline {
    static func migrations() -> [any Migration] {
        [
            CreateUserMigration(),
            CreateRefreshTokenMigration(),
            CreateLoginRateLimitMigration(),
            CreatePasswordResetTokenMigration(),
            CreateEmailRateLimitMigration(),
            AddEmailVerificationMigration(),
            AddEmailChangeMigration(),
            AddSessionMetadataMigration(),
            IndexSessionUserExpiryMigration(),
            CreateAuditLogMigration(),
            IndexMaintenanceExpiryMigration(),
        ]
    }
}
