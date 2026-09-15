import AuthenticationServerKit
import Testing

private actor DeliveryRecorder {
    var messages: [AuthenticationEmail] = []
    func append(_ message: AuthenticationEmail) { messages.append(message) }
}

@Suite("Host dependency interfaces")
struct DependencyBoundaryTests {
    @Test func worksWithoutServerOrVapor() async throws {
        let recorder = DeliveryRecorder()
        let dependencies = AuthenticationDependencies<Int>(
            configuration: .init(urls: { .init(passwordReset: "https://example.invalid/reset") }, auditHashKey: { nil }),
            renderEmail: { _, recipient, link in .init(recipient: recipient, subject: "Host template", html: link) },
            sendEmail: { message, context in
                #expect(context == 7)
                await recorder.append(message)
            },
            resolveIP: { _, purpose in purpose == .login ? "direct-peer" : "host-resolved" }
        )
        let message = dependencies.renderEmail(.passwordReset, "test@example.invalid", "https://example.invalid/reset")
        try await dependencies.sendEmail(message, 7)
        #expect(await recorder.messages == [message])
        #expect(dependencies.resolveIP(7, .login) == "direct-peer")
        #expect(dependencies.resolveIP(7, .audit) == "host-resolved")
        #expect(dependencies.configuration.auditHashKey() == nil)
    }

    @Test func configurationDoesNotValidateOrNormalizeHostValues() {
        let urls = AuthenticationURLs(passwordReset: "", emailVerification: "not-a-url", emailChange: nil)
        let configuration = AuthenticationConfiguration(urls: { urls }, auditHashKey: { "" })
        #expect(configuration.urls() == urls)
        #expect(configuration.auditHashKey() == "")
        // Existing server consumers own validation and empty-key handling.
    }

    @Test func transportErrorsPropagateUnchanged() async {
        enum DeliveryFailure: Error { case unavailable }
        let dependencies = AuthenticationDependencies<Int>(
            configuration: .init(urls: { .init() }, auditHashKey: { nil }),
            renderEmail: { _, to, _ in .init(recipient: to, subject: "", html: "") },
            sendEmail: { _, _ in throw DeliveryFailure.unavailable },
            resolveIP: { _, _ in "unknown" }
        )
        await #expect(throws: DeliveryFailure.self) {
            try await dependencies.sendEmail(.init(recipient: "", subject: "", html: ""), 0)
        }
    }
}
