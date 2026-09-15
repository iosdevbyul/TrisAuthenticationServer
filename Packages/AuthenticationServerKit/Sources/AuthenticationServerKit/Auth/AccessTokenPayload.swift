//
//  AccessTokenPayload.swift
//  AuthenticationServerKit
//
//  Created by COMATOKI on 2026-09-08.
//

import JWTKit
import Foundation

public struct AccessTokenPayload: JWTPayload {
    enum CodingKeys: String, CodingKey {
        case subject = "sub"
        case expiration = "exp"
        case sessionID = "sid"
    }

    public var subject: SubjectClaim
    var expiration: ExpirationClaim
    public var sessionID: UUID?

    init(
        userID: UUID,
        expirationDate: Date,
        sessionID: UUID? = nil
    ) {
        self.subject = SubjectClaim(value: userID.uuidString)
        self.expiration = ExpirationClaim(value: expirationDate)
        self.sessionID = sessionID
    }

    public func verify(using algorithm: some JWTAlgorithm) async throws {
        try expiration.verifyNotExpired()
    }
}
