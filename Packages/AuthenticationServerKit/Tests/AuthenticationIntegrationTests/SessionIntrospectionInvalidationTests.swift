@testable import AuthenticationServerKit
import Fluent
import Foundation
import Testing
import VaporTesting

extension AuthIntegrationTests {
    func verifyIntrospectionAccountInvalidation(_ app: Application) async throws {
        let client = SessionTestClient(app: app)
        let emailService = MockEmailService()
        let originalDependencies = app.testAuthenticationDependencies
        defer { app.testAuthenticationDependencies = originalDependencies }
        var dependencies = originalDependencies
        dependencies.sendEmail = { message, request in try await emailService.send(message, on: request) }
        app.testAuthenticationDependencies = dependencies

        for action in ["change-password", "reset-password", "withdraw"] {
            try await client.clearLimits()
            let first = try await client.signup()
            let second = try await client.login(first)
            let unaffected = try await client.signup()
            let firstID = try await client.stored(first).requireID()
            let secondID = try await client.stored(second).requireID()
            for session in [first, second] {
                try #require(try await client.request(.GET, "introspect", session: session).status == .ok)
            }

            let response: TestingHTTPResponse
            switch action {
            case "change-password":
                response = try await client.request(.POST, action, session: first, body: [
                    "currentPassword": "Example123!", "newPassword": "Different123!"
                ])
            case "reset-password":
                let forgot = try await client.request(.POST, "forgot-password", body: ["email": first.user.email])
                try #require(forgot.status == .ok)
                let url = try #require(emailService.sentResetURL)
                let token = try #require(URLComponents(string: url)?.queryItems?.first { $0.name == "token" }?.value)
                response = try await client.request(.POST, action, body: [
                    "token": token, "newPassword": "Different123!"
                ])
            default:
                response = try await client.request(.DELETE, action, session: first)
            }
            try #require(response.status == .ok, "Account action must succeed: \(action)")

            // Exercise the real account flows; never delete session rows in these tests.
            try await client.expectRemovedSession(first, sessionID: firstID)
            try await client.expectRemovedSession(second, sessionID: secondID)
            #expect(try await client.request(.GET, "introspect", session: unaffected).status == .ok)
            let userID = try #require(UUID(uuidString: first.user.id))
            #expect(try await RefreshToken.query(on: app.db).filter(\.$user.$id == userID).count() == 0)
            if action == "withdraw" {
                #expect(try await User.find(userID, on: app.db) == nil)
            } else {
                #expect(try await User.find(userID, on: app.db) != nil)
                let login = try await client.request(.POST, "login", body: [
                    "email": first.user.email, "password": "Different123!"
                ])
                try #require(login.status == .ok)
                let replacement = try login.content.decode(SessionResponseDTO.self)
                #expect(try await client.request(.GET, "introspect", session: replacement).status == .ok)
            }
        }
        try await client.clearLimits()
    }
}
