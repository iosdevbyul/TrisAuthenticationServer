import Fluent

/// Migration implementations only. The host controls registration, order and identity.
public enum AuthenticationMigrations {
    public enum Step: Sendable {
        case addEmailChangeMigration
        case addEmailVerificationMigration
        case addSessionMetadataMigration
        case createAuditLogMigration
        case createEmailRateLimitMigration
        case createLoginRateLimitMigration
        case createPasswordResetTokenMigration
        case createRefreshTokenMigration
        case createUserMigration
        case indexMaintenanceExpiryMigration
        case indexSessionUserExpiryMigration
    }

    public static func make(_ step: Step) -> any AsyncMigration {
        switch step {
        case .addEmailChangeMigration: return AddEmailChangeMigrationImplementation()
        case .addEmailVerificationMigration: return AddEmailVerificationMigrationImplementation()
        case .addSessionMetadataMigration: return AddSessionMetadataMigrationImplementation()
        case .createAuditLogMigration: return CreateAuditLogMigrationImplementation()
        case .createEmailRateLimitMigration: return CreateEmailRateLimitMigrationImplementation()
        case .createLoginRateLimitMigration: return CreateLoginRateLimitMigrationImplementation()
        case .createPasswordResetTokenMigration: return CreatePasswordResetTokenMigrationImplementation()
        case .createRefreshTokenMigration: return CreateRefreshTokenMigrationImplementation()
        case .createUserMigration: return CreateUserMigrationImplementation()
        case .indexMaintenanceExpiryMigration: return IndexMaintenanceExpiryMigrationImplementation()
        case .indexSessionUserExpiryMigration: return IndexSessionUserExpiryMigrationImplementation()
        }
    }
}
