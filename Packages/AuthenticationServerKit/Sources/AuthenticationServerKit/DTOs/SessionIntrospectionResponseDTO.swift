import Vapor

public struct SessionIntrospectionResponseDTO: Content {
    public let active: Bool
    public let userId: String
    public let sessionId: String

    public init(active: Bool, userId: String, sessionId: String) {
        self.active = active
        self.userId = userId
        self.sessionId = sessionId
    }
}
