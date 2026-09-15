@testable import AuthenticationServerKit
import Testing
import Vapor

@Suite("Extracted contract policies")
struct ContractPolicyTests {
    @Test func validationPreservesOrderAndUnicodeRules() throws {
        do {
            try AuthenticationValidation.validate(email: "invalid", password: "")
            Issue.record("Expected validation failure")
        } catch let error as APIError {
            #expect(error.details?.first?.field == .email)
        }
        // Swift Character limits are not byte or Unicode-scalar limits.
        try AuthenticationValidation.validate(password: String(repeating: "é", count: 7))
        #expect(throws: APIError.self) { try AuthenticationValidation.validate(password: String(repeating: "👨‍👩‍👧‍👦", count: 7)) }
        #expect(throws: APIError.self) { try AuthenticationValidation.validate(password: "123456") }
        try AuthenticationValidation.validate(email: " A@B.C ", password: "1234567")
    }

    @Test func errorDetailsAndRetryHeadersRemainClosed() {
        let rate = APIError(.rateLimited, retryAfter: 0)
        #expect(rate.status == .tooManyRequests)
        #expect(rate.headers.first(name: "Retry-After") == "1")
        #expect(APIError(.rateLimited).headers.first(name: "Retry-After") == nil)
        #expect(APIError(.validationFailed, variant: .password).details == nil)
        #expect(APIError(.validationFailed, variant: .sameEmail).details?.first?.code == .mustDiffer)
        #expect(APIErrorCode.allCases.count == 21)
    }
}
