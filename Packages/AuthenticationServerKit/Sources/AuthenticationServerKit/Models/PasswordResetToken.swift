//
//  PasswordResetToken.swift
//  AuthenticationServerKit
//
//  Created by COMATOKI on 2026-09-08.
//

import Fluent
import Vapor

public final class PasswordResetToken: Model, @unchecked Sendable {
    public static let schema = "password_reset_tokens"

    @ID(key: .id)
    public var id: UUID?

    @Parent(key: "user_id")
    public var user: User

    @Field(key: "token_hash")
    public var tokenHash: String

    @Timestamp(key: "expires_at", on: .none)
    public var expiresAt: Date?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    public init() {}

    public init(
        id: UUID? = nil,
        userID: UUID,
        tokenHash: String,
        expiresAt: Date
    ) {
        self.id = id
        self.$user.id = userID
        self.tokenHash = tokenHash
        self.expiresAt = expiresAt
    }
}
