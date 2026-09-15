import AuthenticationServerKit
import Vapor

// The host owns replacement of the default middleware and installation order.
extension APIErrorMiddleware {
    static func install(on app: Application) {
        // Replace the default handler rather than letting it consume errors before us.
        app.middleware = .init()
        app.middleware.use(APIErrorMiddleware())
    }

}
