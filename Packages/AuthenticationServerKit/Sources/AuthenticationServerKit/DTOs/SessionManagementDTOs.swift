import Vapor

public struct SessionListResponseDTO: Content {
    public let sessions: [ManagedSessionResponseDTO]
    public init(sessions: [ManagedSessionResponseDTO]) {
        self.sessions = sessions
    }
}

/// Dates are distinct: current row creation, login start, and latest successful refresh.
/// Optional timestamps/metadata may be absent for legacy sessions.
public struct ManagedSessionResponseDTO: Content {
    public let id: String // Stable management ID, not the rotating JWT sid.
    public let createdAt: Date?
    public let startedAt: Date?
    public let expiresAt: Date
    public let lastRefreshedAt: Date?
    public let isCurrent: Bool
    public let deviceName: String?
    public init(id: String, createdAt: Date?, startedAt: Date?, expiresAt: Date, lastRefreshedAt: Date?, isCurrent: Bool, deviceName: String?) {
        self.id = id
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.expiresAt = expiresAt
        self.lastRefreshedAt = lastRefreshedAt
        self.isCurrent = isCurrent
        self.deviceName = deviceName
    }
}
