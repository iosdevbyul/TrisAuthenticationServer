import AuthenticationServerKit
import Vapor

func routes(_ app: Application) throws {
    app.get("hello") { req async in
        "Hello, world!"
    }

    // Host configuration is resolved at the original request/registration boundaries.
    try app.register(collection: AuthenticationRoutes(
        dependencies: { $0.application.authenticationDependencies },
        auditHashKey: app.authenticationDependencies.configuration.auditHashKey()))
}
