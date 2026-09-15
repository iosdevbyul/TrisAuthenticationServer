import Fluent
import Vapor

public final class EmailChangeToken: Model, @unchecked Sendable {
    public static let schema = "email_change_tokens"

    @ID(key: .id)
    public var id: UUID?

    @Parent(key: "user_id")
    public var user: User

    @Field(key: "pending_email")
    var pendingEmail: String

    @Field(key: "token_hash")
    var tokenHash: String

    @Field(key: "expires_at")
    var expiresAt: Date

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    public init() {}

    init(userID: UUID, pendingEmail: String, tokenHash: String, expiresAt: Date) {
        self.$user.id = userID
        self.pendingEmail = pendingEmail
        self.tokenHash = tokenHash
        self.expiresAt = expiresAt
    }
}
