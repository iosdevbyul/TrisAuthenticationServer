@testable import AuthenticationServerKit
import Fluent
import Foundation
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
        try await client.clearLimits()
    }
}
