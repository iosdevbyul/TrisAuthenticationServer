# AuthenticationServerKit — Phase B

Reusable Swift 6.3 authentication implementation for Vapor and PostgreSQL. The
package has no WakTrainerServer/iOS AuthenticationKit dependency, environment
lookup, provider adapter, branded template, controller or route registration.
It is not yet a standalone authentication application; host composition is
intentionally retained until Phase C.

Dependencies are Vapor, Fluent, SQLKit, JWT and JWTKit. JWTKit retains the host's
5.6.0 compiler compatibility pin. PostgreSQL driver installation and connection
configuration belong to the host. No additional database backend is supported.

Integration surface:

- Phase A `AuthenticationURLs`, `AuthenticationConfiguration`,
  `AuthenticationEmail`, email/IP purposes and `AuthenticationDependencies<Context>`.
- Request/response DTOs, `APIError`, its closed code/validation contract, and
  `AuthenticationValidation`.
- Models required by the still-host-owned controller queries: `User`,
  `RefreshToken`, `PasswordResetToken`, `EmailChangeToken`.
- `AuthenticationMigrations.make(_:)` delegates one schema step at a time. It
  never registers migrations. Existing hosts must retain historical migration
  names/order and must not additionally register new package migration names.
- `AccessTokenPayload`, `AuthSession`, `LoginRateLimiter`,
  `EmailRateLimitService`/policy, email services/gateway, audit middleware/service
  and maintenance service/policy.

Email services receive a request-to-dependencies provider; rate limiters and
audit receive explicit IP resolvers. The host owns URL configuration, audit key,
JWT signing setup, database connections (including the audit connection), email
rendering/transport, trusted proxy policy and maintenance scheduling. Providers
remain lazy at the existing operation boundaries. Closures must be thread-safe.
Never log rendered links, credentials or secrets. The audit key is captured when
the host constructs its audit service.

SQL helpers, audit persistence/metadata internals, token verification records and
implementation migrations are internal. Some model fields and `AuthSession`
helpers remain public because controllers still compose transactions in the
host; revisit that surface when controllers move in Phase C. Tests use
`@testable import` instead of widening production access for testing.

Build/test from the repository root:

```sh
swift build --package-path Packages/AuthenticationServerKit
swift test --package-path Packages/AuthenticationServerKit
```

Package tests exercise contracts, injected dependencies and service invariants
without a database or external email provider. The server retains the complete
PostgreSQL integration suite, route/DTO contract tests and migration-history
compatibility test. See [Phase B extraction notes](../../docs/authentication-extraction-phase-b.md).
