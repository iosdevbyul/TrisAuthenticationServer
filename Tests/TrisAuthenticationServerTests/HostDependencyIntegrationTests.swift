@testable import TrisAuthenticationServer
@testable import AuthenticationServerKit
import Fluent
import SQLKit
import Testing
import VaporTesting
import Foundation

extension AuthIntegrationTests {
    /// Uses the existing serialized disposable DB lifecycle. No test is moved.
    func verifyHostDependencies(_ app: Application) async throws {
        let previous = app.authenticationDependencies
        defer { app.authenticationDependencies = previous }
        let mail = MockEmailService()
        var dependencies = AuthenticationHostDependencies.live()
        dependencies.configuration = .init(urls: {
            .init(passwordReset: "https://injected.invalid/reset",
                  emailVerification: "https://injected.invalid/verify",
                  emailChange: "https://injected.invalid/change")
        }, auditHashKey: { nil })
        dependencies.sendEmail = { message, request in
            #expect(message.html.hasSuffix("<!-- injected -->"))
            try await mail.send(message, on: request)
        }
        // Preserve the branded template body while proving the renderer is used.
        let originalRenderer = dependencies.renderEmail
        dependencies.renderEmail = { purpose, recipient, link in
            let message = originalRenderer(purpose, recipient, link)
            return .init(recipient: message.recipient, subject: message.subject, html: message.html + "<!-- injected -->")
        }
        dependencies.resolveIP = { _, purpose in purpose == .login ? "phase-a-login" : "phase-a-email" }
        app.authenticationDependencies = dependencies
        // Existing tests explicitly inject controller mail/URLs. This separate
        // test-only group exercises the Application dependency fallback instead.
        try app.grouped("host-di").register(collection: AuthController(auditLog: .init(hashKey: nil)))
        let sql = try #require(app.db as? any SQLDatabase)
        try await sql.raw("DELETE FROM email_rate_limits").run()
        try await sql.raw("DELETE FROM login_rate_limits").run()
        let email = UUID().uuidString + "@example.invalid"
        let password = String(AuthSession.randomToken().prefix(16))
        let signup = try await app.sendRequest(.POST, "/host-di/auth/signup", beforeRequest: { req in
            try req.content.encode(AuthRequestDTO(email: email, password: password))
        })
        try #require(signup.status == .ok)
        let session = try signup.content.decode(SessionResponseDTO.self)
        #expect(mail.sentVerificationURL?.hasPrefix("https://injected.invalid/verify?token=") == true)
        #expect(mail.sentCount == 1)
        let forgot = try await app.sendRequest(.POST, "/host-di/auth/forgot-password", beforeRequest: { req in
            try req.content.encode(ForgotPasswordRequestDTO(email: email))
        })
        #expect(forgot.status == .ok)
        #expect(mail.sentResetURL?.hasPrefix("https://injected.invalid/reset?token=") == true)
        let change = try await app.sendRequest(.POST, "/host-di/auth/request-email-change", beforeRequest: { req in
            req.headers.bearerAuthorization = .init(token: session.accessToken)
            try req.content.encode(RequestEmailChangeRequestDTO(currentPassword: password, newEmail: UUID().uuidString + "@example.invalid"))
        })
        #expect(change.status == .ok)
        #expect(mail.sentEmailChangeURL?.hasPrefix("https://injected.invalid/change?token=") == true)
        // Invalid email fails after consuming the login IP quota, without bcrypt.
        let login = try await app.sendRequest(.POST, "/host-di/auth/login", beforeRequest: { req in
            try req.content.encode(AuthRequestDTO(email: "invalid", password: password))
        })
        #expect(login.status == .badRequest)
        let loginBucket = "ip:" + AuthSession.hash("phase-a-login")
        let emailBucket = "ip:" + AuthSession.hash("phase-a-email")
        #expect(try await sql.raw("SELECT bucket_key FROM login_rate_limits WHERE bucket_key = \(bind: loginBucket)").first() != nil)
        #expect(try await sql.raw("SELECT bucket_key FROM email_rate_limits WHERE bucket_key = \(bind: emailBucket)").first() != nil)
        let withdraw = try await app.sendRequest(.DELETE, "/host-di/auth/withdraw", beforeRequest: { req in
            req.headers.bearerAuthorization = .init(token: session.accessToken)
        })
        #expect(withdraw.status == .ok)
    }
}
