import Fluent
import Vapor

public final class RefreshToken: Model, @unchecked Sendable {
    public static let schema = "refresh_tokens"

    @ID(key: .id) public var id: UUID?
    @Parent(key: "user_id") public var user: User
    @Field(key: "token_hash") var tokenHash: String
    @Field(key: "expires_at") public var expiresAt: Date
    @Timestamp(key: "created_at", on: .create) public var createdAt: Date?

    // Management identity survives rotation; id remains the JWT sid for this row.
    @OptionalField(key: "management_id") public var managementID: UUID?
    @OptionalField(key: "started_at") public var startedAt: Date?
    @OptionalField(key: "last_refreshed_at") public var lastRefreshedAt: Date?
    @OptionalField(key: "device_name") public var deviceName: String?

    public func managementIdentifier() throws -> UUID { try managementID ?? requireID() }

    public init() {}

    init(id: UUID, userID: UUID, tokenHash: String, expiresAt: Date) {
        self.id = id
        self.$user.id = userID
        self.tokenHash = tokenHash
        self.expiresAt = expiresAt
    }
}
