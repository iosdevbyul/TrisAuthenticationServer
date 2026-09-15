# AuthenticationServerKit

Reusable Swift 6.3 authentication for Vapor and PostgreSQL. The package owns the
17 `/auth` routes, request/response/error contracts, controllers and authentication
implementation. It imports neither a consuming server nor the iOS client package.

## Host integration

Configure the host's PostgreSQL connections, JWT signing keys and dependency
providers before registering routes. The package does not read environment
variables, choose a mail provider, trust forwarding headers or install middleware.

```swift
import AuthenticationServerKit
import Vapor

// `dependencies` is supplied by the host, with thread-safe providers/closures.
let authentication = AuthenticationRoutes(
    dependencies: { _ in dependencies },
    auditHashKey: dependencies.configuration.auditHashKey()
)
app.middleware.use(APIErrorMiddleware()) // host chooses the installation order
try app.register(collection: authentication) // 17 routes under /auth
// Alternatively register on app.grouped("v1") for /v1/auth/... .
```

`AuthenticationRoutes` takes a request-to-dependencies provider, the audit key
captured at registration, and an optional `EmailRateLimitPolicy`. The provider is
called lazily at the original operation boundaries. Request-specific hosts may
resolve dependencies from their own Application storage. A host replacing Vapor's
default error middleware must do so explicitly before installing APIErrorMiddleware;
registering the routes does not alter the middleware stack.

The host supplies URL configuration, rendering/delivery, login/email/audit IP
resolution, DB/JWT/password-hasher setup and the separate `DatabaseID.audit`
connection. Direct IP versus trusted-proxy policy is entirely host-owned.
Never log credentials, rendered links or configuration secrets.

## Public API

- Configuration/dependency values: `AuthenticationURLs`,
  `AuthenticationConfiguration`, `AuthenticationDependencies`,
  `AuthenticationEmail` and email/IP purposes.
- `AuthenticationRoutes` and `APIErrorMiddleware` for explicit HTTP integration.
- All request/response DTOs and the existing APIError/code/validation-detail contract.
- `EmailRateLimitPolicy`, its Window values and EmailAction policy keys.
- `AuthenticationMigrations.Step`/`make(_:)` for explicit host migration registration.
- `MaintenancePolicy`, `DatabaseMaintenanceService.run` and `Result.succeeded` for
  host-owned scheduling/commands; `DatabaseID.audit` for audit pool configuration.

Controllers, models, AuthSession/JWT payload, hash/token/SQL helpers, validation,
email gateway/services and audit implementation are internal/private. They are not
part of the consuming host's API. Package tests use `@testable`; the standalone
host test target deliberately uses only normal public imports.

## Migrations

The package does not automatically register or run migrations. Existing consumers
must retain their recorded migration identities/order. WakTrainerServer's eleven
compatibility wrappers delegate to the package and remain required. Never register
package implementation migrations in addition to those wrappers. New hosts can
explicitly select the steps in dependency order; this is not a schema redesign or
support for multiple database backends.

## Build and test

```sh
swift build --package-path Packages/AuthenticationServerKit
swift test --package-path Packages/AuthenticationServerKit --filter StandaloneHostTests
swift test --package-path Packages/AuthenticationServerKit --no-parallel
```

The full suite requires a disposable PostgreSQL database named
`waktrainer_test_auth` and TEST_DATABASE_NAME/HOST/PORT/USERNAME/PASSWORD settings
appropriate to that local database. It creates/reverts its test schema and uses
mock email. Do not run the package and server integration suites concurrently on
the same database. The standalone host test needs no database and verifies public
registration, outer prefixes, error responses and absence of `/hello`.

Vapor, Fluent, SQLKit, JWT and JWTKit are runtime dependencies. FluentPostgresDriver
is used only by the integration-test target; the consuming host installs its own
driver. Existing dependency versions and the JWTKit 5.6.0 compatibility pin remain.
