import Foundation

public struct EmailAction: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let passwordReset = Self(rawValue: "passwordReset")
    public static let signUpVerification = Self(rawValue: "signUpVerification")
    public static let emailChangeVerification = Self(rawValue: "emailChangeVerification")
}

public struct EmailRateLimitPolicy: Sendable {
    public init() {}

    public struct Window: Sendable {
        public let limit: Int
        public let seconds: Int
        public init(limit: Int, seconds: Int) { self.limit = limit; self.seconds = seconds }
    }
    public var recipient = Window(limit: 5, seconds: 600)
    public var client = Window(limit: 10, seconds: 600)
    public var ip = Window(limit: 20, seconds: 600)
    public var global = Window(limit: 1_000, seconds: 600)
    public var action = Window(limit: 500, seconds: 600)
    public var sensitiveRecipients: [EmailAction: Window] = [
        .passwordReset: Window(limit: 10, seconds: 3_600)
    ]
}

