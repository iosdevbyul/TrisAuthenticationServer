@testable import AuthenticationServerKit
import Fluent
import Foundation
import JWT
import Testing
import VaporTesting

extension AuthIntegrationTests {
    func verifySessionIntrospection(_ app: Application) async throws {
        let client = SessionTestClient(app: app)
        try await client.clearLimits()
        let session = try await client.signup()
        let stored = try await client.stored(session)
        let response = try await client.request(.GET, "introspect", session: session)
        try #require(response.status == .ok)
        let result = try response.content.decode(SessionIntrospectionResponseDTO.self)
        #expect(result.active)
        #expect(result.userId == session.user.id)
        #expect(result.sessionId == stored.id?.uuidString)
        #expect(result.sessionId != stored.managementID?.uuidString)
        let json = try #require(JSONSerialization.jsonObject(with: Data(response.body.readableBytesView)) as? [String: Any])
        #expect(Set(json.keys) == ["active", "userId", "sessionId"])
        try await verifyIntrospectionSessionValidation(app)
        try await verifyIntrospectionAccountInvalidation(app)
        try await client.clearLimits()
    }
}

extension AuthIntegrationTests {
    private func verifyIntrospectionSessionValidation(_ app: Application) async throws {
        let client = SessionTestClient(app: app)
        try await client.clearLimits()
        try await client.expectIntrospectionFailure(token: nil, code: .authenticationRequired)
        try await client.expectIntrospectionFailure(token: "invalid-jwt", code: .accessTokenInvalidOrExpired)

        let session = try await client.signup()
        let stored = try await client.stored(session)
        let sessionID = try stored.requireID()
        let request = Request(application: app, on: app.eventLoopGroup.next())
        let expiredAccess = try await request.jwt.sign(AccessTokenPayload(
            userID: stored.$user.id, expirationDate: Date().addingTimeInterval(-60), sessionID: sessionID))
        try await client.expectIntrospectionFailure(token: expiredAccess, code: .accessTokenInvalidOrExpired)
        // Access-token expiry alone does not remove a valid session row.
        #expect(try await RefreshToken.find(sessionID, on: app.db) != nil)
        #expect(try await client.request(.GET, "introspect", session: session).status == .ok)

        let missingSID = try await request.jwt.sign(AccessTokenPayload(
            userID: stored.$user.id, expirationDate: Date().addingTimeInterval(600)))
        try await client.expectIntrospectionFailure(token: missingSID, code: .accessTokenInvalidOrExpired)
        let unknownSID = try await request.jwt.sign(AccessTokenPayload(
            userID: stored.$user.id, expirationDate: Date().addingTimeInterval(600), sessionID: UUID()))
        try await client.expectIntrospectionFailure(token: unknownSID, code: .sessionInvalid)
        let otherUser = try await client.signup()
        let wrongOwner = try await request.jwt.sign(AccessTokenPayload(
            userID: try #require(UUID(uuidString: otherUser.user.id)),
            expirationDate: Date().addingTimeInterval(600), sessionID: sessionID))
        try await client.expectIntrospectionFailure(token: wrongOwner, code: .sessionInvalid)

        let loggedOut = try await client.login(session)
        let loggedOutID = try await client.stored(loggedOut).requireID()
        try #require(try await client.request(.POST, "logout", session: loggedOut).status == .ok)
        try await client.expectRemovedSession(loggedOut, sessionID: loggedOutID)

        let revoked = try await client.login(session)
        let revokedRow = try await client.stored(revoked)
        try #require(try await client.request(.DELETE,
            "sessions/" + revokedRow.managementIdentifier().uuidString, session: session).status == .ok)
        try await client.expectRemovedSession(revoked, sessionID: revokedRow.requireID())
        #expect(try await client.request(.GET, "introspect", session: session).status == .ok)

        // A valid JWT is also insufficient when its existing session has expired.
        stored.expiresAt = Date().addingTimeInterval(-60)
        try await stored.update(on: app.db)
        _ = try await request.jwt.verify(session.accessToken, as: AccessTokenPayload.self)
        try await client.expectIntrospectionFailure(token: session.accessToken, code: .sessionInvalid)
        #expect(try await RefreshToken.find(sessionID, on: app.db) != nil)
    }
}

extension SessionTestClient {
    func expectIntrospectionFailure(token: String?, code: APIErrorCode) async throws {
        let response = try await app.testing().sendRequest(.GET, "auth/introspect", beforeRequest: { request in
            if let token { request.headers.bearerAuthorization = .init(token: token) }
        })
        #expect(response.status == .unauthorized)
        let error = try response.content.decode(APIErrorResponseDTO.self)
        #expect(error.error)
        #expect(error.status == 401)
        #expect(error.code == code)
        let json = try #require(JSONSerialization.jsonObject(with: Data(response.body.readableBytesView)) as? [String: Any])
        #expect(Set(json.keys) == ["error", "status", "code", "message", "reason"])
        // Keep credentials out of assertion diagnostics, even if a response regresses.
        let includesCredential = token.map { response.body.string.contains($0) } ?? false
        #expect(!includesCredential)
    }

    func expectRemovedSession(_ session: SessionResponseDTO, sessionID: UUID) async throws {
        let request = Request(application: app, on: app.eventLoopGroup.next())
        let payload = try await request.jwt.verify(session.accessToken, as: AccessTokenPayload.self)
        #expect(payload.sessionID == sessionID)
        #expect(try await RefreshToken.find(sessionID, on: app.db) == nil)
        try await expectIntrospectionFailure(token: session.accessToken, code: .sessionInvalid)
    }
}
