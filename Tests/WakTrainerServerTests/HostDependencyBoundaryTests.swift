@testable import WakTrainerServer
import AuthenticationServerKit
import Foundation
import Testing
import VaporTesting

@Suite("Host dependency wiring")
struct HostDependencyBoundaryTests {
    @Test func registeredRoutesUseInjectedAuditKeyWithoutEagerURLLookup() async throws {
        let key = UUID().uuidString
        try await withApp(configure: { app in
            var dependencies = AuthenticationHostDependencies.live()
            dependencies.configuration = .init(urls: {
                Issue.record("Invalid signup must not resolve email URLs")
                return .init()
            }, auditHashKey: { key })
            dependencies.sendEmail = { _, _ in Issue.record("Invalid signup must not send mail") }
            app.authenticationDependencies = dependencies
            APIErrorMiddleware.install(on: app)
            try routes(app)
        }) { app in
            let request = Request(application: app, method: .POST, url: "/auth/signup", on: app.eventLoopGroup.next())
            try request.content.encode(AuthRequestDTO(email: "invalid", password: "invalid"))
            let response = try await app.responder.respond(to: request).get()
            #expect(response.status == .badRequest)
            #expect(request.auditContext.emailHash == AuditLogService(hashKey: key).identifierHash("invalid", kind: .email))
            #expect(request.auditContext.emailHash != nil)
        }
    }
}
