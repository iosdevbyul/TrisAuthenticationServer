@testable import WakTrainerServer
import Foundation
import CoreFoundation
import Testing
import VaporTesting

@Suite("OpenAPI contract (no database)")
struct OpenAPIContractTests {
    private func document() throws -> [String: Any] {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        return try #require(JSONSerialization.jsonObject(with: Data(contentsOf:
            root.appendingPathComponent("docs/openapi/openapi.json"))) as? [String: Any])
    }

    @Test func registeredRoutesAndSecurity() async throws {
        let doc = try document()
        let paths = try #require(doc["paths"] as? [String: [String: [String: Any]]])
        try await withApp(configure: { app in
            APIErrorMiddleware.install(on: app)
            try routes(app)
        }) { app in
            let actual = Set(app.routes.all.map { route in
                let path = route.path.map { component in
                    let value = component.description
                    return value.hasPrefix(":") ? "{" + value.dropFirst() + "}" : value
                }.joined(separator: "/")
                return route.method.rawValue.lowercased() + " /" + path
            })
            for route in app.routes.all where route.path.first?.description == "auth" {
                let path = "/" + route.path.map { component in
                    let value = component.description
                    return value.hasPrefix(":") ? "{" + value.dropFirst() + "}" : value
                }.joined(separator: "/")
                let operation = try #require(paths[path]?[route.method.rawValue.lowercased()])
                let responses = try #require(operation["responses"] as? [String: [String: Any]])
                let content = try #require(responses["200"]?["content"] as? [String: [String: Any]])
                let schema = try #require(content["application/json"]?["schema"] as? [String: String])
                #expect(schema["$ref"] == "#/components/schemas/" + String(describing: route.responseType))
            }
            let documented = Set(paths.flatMap { path, methods in methods.keys.map { $0 + " " + path } })
            #expect(actual == documented)
            #expect(actual.count == 18)
            for (path, methods) in paths {
                for (method, operation) in methods {
                    let security = try #require(operation["security"] as? [[String: [String]]])
                    if !security.isEmpty {
                        #expect(security == [["bearerAuth": []]])
                        let response = try await app.sendRequest(HTTPMethod(rawValue: method.uppercased()),
                            path.replacingOccurrences(of: "{sessionID}", with: UUID().uuidString))
                        #expect(response.status == .unauthorized)
                        let error = try response.content.decode(APIErrorResponseDTO.self)
                        #expect(error.code == .authenticationRequired)
                        #expect(error.status == 401)
                    }
                }
            }
            for path in ["signup", "refresh", "forgot-password", "reset-password", "verify-email", "resend-verification-email"] {
                let malformed = try await app.sendRequest(.POST, "/auth/" + path, beforeRequest: { request in
                    request.headers.contentType = .json
                    request.body = .init(string: "{}")
                })
                #expect(malformed.status == .badRequest)
                #expect(try malformed.content.decode(APIErrorResponseDTO.self).code == .invalidRequest)
                let unsupported = try await app.sendRequest(.POST, "/auth/" + path)
                #expect(unsupported.status == .unsupportedMediaType)
                #expect(try unsupported.content.decode(APIErrorResponseDTO.self).code == .unsupportedMediaType)
            }
            let response = try await app.sendRequest(.GET, "/hello")
            #expect(response.status == .ok)
            #expect(response.headers.contentType == .plainText)
        }
    }

    // Validate real Vapor encodings recursively, including required fields, types,
    // enum values, arrays, UUID/date formats and optional-field omission.
    private func check(_ value: Any, schema: [String: Any], schemas: [String: [String: Any]]) throws {
        if let reference = schema["$ref"] as? String {
            try check(value, schema: #require(schemas[String(reference.split(separator: "/").last!)]), schemas: schemas)
            return
        }
        if let allowed = schema["enum"] as? [String] { #expect(allowed.contains(try #require(value as? String))) }
        switch schema["type"] as? String {
        case "object":
            let object = try #require(value as? [String: Any])
            let properties = try #require(schema["properties"] as? [String: [String: Any]])
            let required = try #require(schema["required"] as? [String])
            #expect(Set(required).isSubset(of: Set(object.keys)))
            #expect(Set(object.keys).isSubset(of: Set(properties.keys)))
            for (key, item) in object { try check(item, schema: #require(properties[key]), schemas: schemas) }
        case "array":
            for item in try #require(value as? [Any]) {
                try check(item, schema: #require(schema["items"] as? [String: Any]), schemas: schemas)
            }
        case "string":
            let string = try #require(value as? String)
            if schema["format"] as? String == "uuid" { #expect(UUID(uuidString: string) != nil) }
            if schema["format"] as? String == "date-time" { #expect(ISO8601DateFormatter().date(from: string) != nil) }
        case "boolean": #expect(CFGetTypeID(try #require(value as? NSNumber)) == CFBooleanGetTypeID())
        case "integer": #expect(value is Int)
        default: Issue.record("Unsupported schema type")
        }
    }

    private func encoded<T: Content>(_ value: T, schemas: [String: [String: Any]]) throws -> [String: Any] {
        let response = Response()
        try response.content.encode(value)
        let object = try #require(JSONSerialization.jsonObject(with: Data(response.body.string!.utf8)) as? [String: Any])
        let name = String(describing: T.self)
        try check(object, schema: #require(schemas[name]), schemas: schemas)
        return object
    }

    @Test func actualDTOEncodingsAndErrorCatalog() throws {
        let components = try #require(document()["components"] as? [String: Any])
        let schemas = try #require(components["schemas"] as? [String: [String: Any]])
        // Synthetic in-memory fixtures are never written to the public document.
        let opaque = UUID().uuidString
        let user = UserResponseDTO(id: UUID().uuidString, email: "contract@example.invalid", isEmailVerified: false)
        _ = try encoded(AuthRequestDTO(email: user.email, password: opaque), schemas: schemas)
        _ = try encoded(RefreshRequestDTO(refreshToken: opaque), schemas: schemas)
        _ = try encoded(ForgotPasswordRequestDTO(email: user.email), schemas: schemas)
        _ = try encoded(ResetPasswordRequestDTO(token: opaque, newPassword: opaque), schemas: schemas)
        _ = try encoded(ChangePasswordRequestDTO(currentPassword: opaque, newPassword: opaque), schemas: schemas)
        _ = try encoded(VerifyEmailRequestDTO(token: opaque), schemas: schemas)
        _ = try encoded(ResendVerificationEmailRequestDTO(email: user.email), schemas: schemas)
        _ = try encoded(RequestEmailChangeRequestDTO(currentPassword: opaque, newEmail: user.email), schemas: schemas)
        _ = try encoded(ConfirmEmailChangeRequestDTO(token: opaque), schemas: schemas)
        _ = try encoded(MessageResponseDTO(message: "ok"), schemas: schemas)
        _ = try encoded(user, schemas: schemas)
        _ = try encoded(SessionResponseDTO(user: user, accessToken: opaque, refreshToken: opaque), schemas: schemas)
        let optional = try encoded(SessionResponseDTO(user: user, accessToken: opaque, refreshToken: nil), schemas: schemas)
        #expect(optional["refreshToken"] == nil)
        let full = ManagedSessionResponseDTO(id: UUID().uuidString, createdAt: Date(), startedAt: Date(), expiresAt: Date(), lastRefreshedAt: Date(), isCurrent: true, deviceName: "test")
        let legacy = ManagedSessionResponseDTO(id: UUID().uuidString, createdAt: nil, startedAt: nil, expiresAt: Date(), lastRefreshedAt: nil, isCurrent: false, deviceName: nil)
        _ = try encoded(full, schemas: schemas)
        let legacyJSON = try encoded(legacy, schemas: schemas)
        #expect(Set(legacyJSON.keys) == ["id", "expiresAt", "isCurrent"])
        _ = try encoded(SessionListResponseDTO(sessions: [full, legacy]), schemas: schemas)
        let catalog = try #require(schemas["APIErrorCode"])
        #expect(Set(try #require(catalog["enum"] as? [String])) == Set(APIErrorCode.allCases.map(\.rawValue)))
        let statuses = try #require(catalog["x-default-status"] as? [String: Int])
        for code in APIErrorCode.allCases {
            #expect(statuses[code.rawValue] == Int(code.status.code))
            _ = try encoded(APIErrorResponseDTO(status: code.status, code: code, message: code.message, details: nil), schemas: schemas)
        }
        for variant in [APIError.Variant.email, .sameEmail, .sessionID] {
            let error = APIError(.validationFailed, variant: variant)
            _ = try encoded(APIErrorResponseDTO(status: error.status, code: error.code, message: error.message, details: error.details), schemas: schemas)
        }
    }
}
