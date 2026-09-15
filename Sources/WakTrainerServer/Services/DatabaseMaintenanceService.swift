import AuthenticationServerKit
import Vapor
import Fluent
import SQLKit

struct MaintenanceCommand: AsyncCommand {
    struct Signature: CommandSignature { init() {} }
    var help: String { "Delete expired data in bounded PostgreSQL batches." }

    func run(using context: CommandContext, signature: Signature) async throws {
        let cutoff = Date()
        do {
            let policy = try MaintenancePolicy.configured()
            let quiet = Logger(label: "maintenance.database", factory: { _ in SwiftLogNoOpLogHandler() })
            guard let db = context.application.databases.database(.maintenance, logger: quiet,
                on: context.application.eventLoopGroup.next(), withTracing: false) else {
                throw MaintenanceCommandFailure.failed
            }
            let result = await DatabaseMaintenanceService(policy: policy).run(
                on: db, cutoff: cutoff, logger: context.application.logger)
            guard result.succeeded else { throw MaintenanceCommandFailure.failed }
        } catch {
            // A dedicated error lets the entrypoint shut down and exit 1 without a crash backtrace.
            throw MaintenanceCommandFailure.failed
        }
    }
}

extension DatabaseID { static let maintenance = DatabaseID(string: "maintenance") }

enum MaintenanceCommandFailure: Error { case failed }
