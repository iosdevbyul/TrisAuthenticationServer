@testable import AuthenticationServerKit
@testable import WakTrainerServer
import Fluent
import Foundation
import Vapor
import Testing

@Suite("Phase A extraction baseline")
struct ExtractionBaselineTests {
    private struct Baseline: Decodable {
        let sha256: [String: String]
        let migrations: [String]
    }

    @Test func openAPIAndMigrationIdentityRemainFrozen() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let baseline = try JSONDecoder().decode(Baseline.self, from: Data(contentsOf:
            root.appendingPathComponent("Tests/Baselines/authentication-extraction.json")))
        for (path, expected) in baseline.sha256 {
            let data = try Data(contentsOf: root.appendingPathComponent(path))
            let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            #expect(hash == expected, "Extraction must not update the API baseline: \(path)")
        }
        #expect(AuthenticationMigrationBaseline.migrations().map(\.name) == baseline.migrations)
        #expect(baseline.migrations.count == 11)
    }
}
