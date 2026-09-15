import Vapor

public struct APIValidationDetail: Codable, Sendable {
    public enum Field: String, Codable, Sendable { case email, newEmail, sessionID }
    public enum Code: String, Codable, Sendable { case invalidFormat = "INVALID_FORMAT", mustDiffer = "MUST_DIFFER" }
    public let field: Field
    public let code: Code

    public init(field: Field, code: Code) { self.field = field; self.code = code }
}

public struct APIErrorResponseDTO: Content {
    public let error: Bool
    public let status: Int
    public let code: APIErrorCode
    public let message: String
    public let reason: String
    public let details: [APIValidationDetail]?

    // Only the middleware constructs the payload from its selected HTTP status.
    public init(status: HTTPResponseStatus, code: APIErrorCode, message: String, details: [APIValidationDetail]?) {
        self.error = true
        self.status = Int(status.code)
        self.code = code
        self.message = message
        self.reason = message
        self.details = details
    }
}
