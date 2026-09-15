import AuthenticationServerKit
import Foundation
import JWT
import Testing
import VaporTesting

@Suite("Independent Vapor host")
struct StandaloneHostTests {
    @Test func publicRegistrationAndOptionalOuterPrefix() async throws {
        for prefix in ["", "v1"] {
            try await withApp(configure: { app in
                app.middleware = .init()
                app.middleware.use(APIErrorMiddleware())
                await app.jwt.keys.add(hmac: .init(from: UUID().uuidString + UUID().uuidString), digestAlgorithm: .sha256)
                let dependencies = AuthenticationDependencies<Request>(
                    configuration: .init(urls: { .init() }, auditHashKey: { nil }),
                    renderEmail: { _, recipient, _ in
                        Issue.record("Invalid input must not render mail")
                        return .init(recipient: recipient, subject: "test", html: "")
                    },
                    sendEmail: { _, _ in Issue.record("Invalid input must not deliver mail") },
                    resolveIP: { _, _ in "unknown" })
                let routes = AuthenticationRoutes(dependencies: { _ in dependencies }, auditHashKey: nil)
                if prefix.isEmpty { try app.register(collection: routes) }
                else { try app.grouped(.constant(prefix)).register(collection: routes) }
            }) { app in
                #expect(app.routes.all.count == 17)
                let base = prefix.isEmpty ? "/auth" : "/" + prefix + "/auth"
                #expect(app.routes.all.allSatisfy { ("/" + $0.path.map(\.description).joined(separator: "/")).hasPrefix(base + "/") })
                let protected = try await app.sendRequest(.GET, base + "/me")
                #expect(protected.status == .unauthorized)
                #expect(try protected.content.decode(APIErrorResponseDTO.self).code == .authenticationRequired)
                let invalid = try await app.sendRequest(.POST, base + "/signup", beforeRequest: { request in
                    try request.content.encode(AuthRequestDTO(email: "invalid", password: "invalid"))
                })
                #expect(invalid.status == .badRequest)
                #expect(try invalid.content.decode(APIErrorResponseDTO.self).code == .validationFailed)
                #expect(try await app.sendRequest(.GET, "/hello").status == .notFound)
            }
        }
    }
}
