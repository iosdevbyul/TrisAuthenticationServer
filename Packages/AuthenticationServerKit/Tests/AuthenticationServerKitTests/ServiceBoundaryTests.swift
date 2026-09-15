@testable import AuthenticationServerKit
import Foundation
import Testing
import VaporTesting

@Suite("Extracted service boundaries")
struct ServiceBoundaryTests {
    @Test func ownershipLinksPreserveQueriesAndRejectUnsafeBases() throws {
        let token = UUID().uuidString
        let link = try EmailVerificationService.verificationURL(
            base: "https://example.invalid/verify?source=app&token=obsolete&token=duplicate#complete",
            token: token, setting: "test-only")
        let components = try #require(URLComponents(string: link))
        #expect(components.fragment == "complete")
        #expect(components.queryItems?.filter { $0.name == "source" }.first?.value == "app")
        #expect(components.queryItems?.filter { $0.name == "token" }.map(\.value) == [token])
        for base: String? in [nil, "http://example.invalid/verify", "https://user@example.invalid/verify", "/verify"] {
            #expect(throws: APIError.self) {
                try EmailVerificationService.verificationURL(base: base, token: token, setting: "test-only")
            }
        }
    }

    @Test func auditIdentifiersRemainKeyedAndDomainSeparated() {
        let key = UUID().uuidString
        let service = AuditLogService(hashKey: key, resolveIP: { _ in "unknown" })
        let sameKey = AuditLogService(hashKey: key, resolveIP: { _ in "unknown" })
        let otherKey = AuditLogService(hashKey: UUID().uuidString, resolveIP: { _ in "unknown" })
        let email = service.identifierHash(" A@EXAMPLE.INVALID ", kind: .email)
        #expect(email == sameKey.identifierHash("a@example.invalid", kind: .email))
        #expect(email?.count == 64)
        #expect(email != otherKey.identifierHash("a@example.invalid", kind: .email))
        #expect(service.identifierHash("same", kind: .email) != service.identifierHash("same", kind: .client))
        #expect(AuditLogService(hashKey: nil, resolveIP: { _ in "unknown" }).identifierHash("a", kind: .email) == nil)
        #expect(AuditLogService(hashKey: "", resolveIP: { _ in "unknown" }).identifierHash("a", kind: .email) == nil)
    }

    @Test func unavailableAuditStoragePreservesHandlerResult() async throws {
        try await withApp(configure: { _ in }) { app in
            let service = AuditLogService(hashKey: nil, resolveIP: { _ in "unknown" })
            let middleware = AuditLogMiddleware(service: service, event: .logout, endpoint: .logout)
            let request = Request(application: app, on: app.eventLoopGroup.next())
            let response = try await middleware.respond(to: request, chainingTo: SuccessfulHandler())
            #expect(response.status == .ok)
            #expect(response.body.string == "completed")
            // The fallback's suppression/backoff must also preserve the next request.
            let repeated = try await middleware.respond(to: request, chainingTo: SuccessfulHandler())
            #expect(repeated.status == .ok)
        }
    }
}

private struct SuccessfulHandler: AsyncResponder {
    func respond(to request: Request) async throws -> Response {
        Response(status: .ok, body: .init(string: "completed"))
    }
}
