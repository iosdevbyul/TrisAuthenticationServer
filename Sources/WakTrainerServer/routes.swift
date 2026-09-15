import AuthenticationServerKit
import Vapor

func routes(_ app: Application) throws {
    app.get("hello") { req async in
        "Hello, world!"
    }

    // AuthController 라우트 등록
    try app.register(collection: AuthController(auditLog: .init(hashKey: app.authenticationDependencies.configuration.auditHashKey())))
}
