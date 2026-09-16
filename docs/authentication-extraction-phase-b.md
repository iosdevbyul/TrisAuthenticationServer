# AuthenticationServerKit extraction: Phase B

Phase B extracts implementation; `AuthController`, `SessionController`, route
registration, application setup and production tooling remain in TrisAuthenticationServer.
The dependency remains `TrisAuthenticationServer -> AuthenticationServerKit`. Neither the
server nor the iOS AuthenticationKit is imported/referenced by package sources.
No API contract, schema, historical migration identity or registration order is
changed. No commit, push, production database access or external email delivery
is part of this work.

## Stages and ownership

| Stage | Package implementation | Host boundary retained |
| --- | --- | --- |
| B1 | All four DTO files, APIError/code/details, validation, email rate-limit policy, six existing models, eleven migration implementations | Controller decoding/response construction; APIErrorMiddleware and installation; named migration wrappers and registration |
| B2 | JWT payload, AuthSession issuance/validation/rotation/metadata/cleanup, login and email rate-limit SQL | Controller handlers; direct/trusted-proxy IP resolution via injected closures |
| B3 | Email verification/change, generic quota/prepare/dispatch gateway, audit context/events/HMAC/dedup/persistence/middleware, maintenance policy and batched cleanup | Resend, templates/sender, environment/URL/key configuration, audit middleware attachment, MaintenanceCommand and scheduling |

The refresh handler still decodes `RefreshRequestDTO` in the host and delegates
to `AuthSession.rotate`. The original length check, lookup, transaction, user lock,
re-read, expiry check, deletion and issuance remain in the same order. Controllers
have not been moved or re-registered. Other controller workflows remain intact.

The repository has no separate Fluent `LoginRateLimit` or `EmailRateLimit` model
types: their existing SQL-backed storage and migrations are moved as-is. No model
abstraction or alternative database support is introduced.

## Dependencies and public surface

The package adds only the implementation's existing dependency families:

| Dependency | Purpose |
| --- | --- |
| Vapor | Request/Content/error/async middleware, existing crypto exports |
| Fluent | Existing models, migrations and database transaction APIs |
| SQLKit | Existing PostgreSQL SQL, atomic upserts and locking |
| JWT | Vapor JWT request signing/verification integration |
| JWTKit | JWTPayload/claims/algorithm; existing exact 5.6.0 compiler compatibility pin |

`VaporTesting` is a test-only product of Vapor. The package adds no Postgres driver:
the host installs/configures the existing PostgreSQL driver. Root Package.resolved
is unchanged; the package has its own resolution file for independent builds.

Public API is limited to host composition needs:

- Phase A configuration/dependency values and lazy providers are unchanged.
- All request/response DTOs, `APIError`, `APIErrorCode`, `APIValidationDetail`,
  associated error variants, and `AuthenticationValidation` are used by host handlers
  and APIErrorMiddleware. Codable keys, optionality and error values are unchanged.
- `User`, `RefreshToken`, `PasswordResetToken`, `EmailChangeToken` remain visible for
  the host's existing Fluent queries and transactions. `EmailVerificationToken`
  and `AuditLog` are internal. Unneeded token constructors/fields are internal.
- `AuthenticationMigrations.Step` and `make(_:)` return one implementation for
  wrapper delegation. Implementation types are internal and register nothing.
- `AccessTokenPayload` exposes verified subject/session identity; construction and
  expiry storage are internal. `AuthSession` exposes payload/validate/issue/rotate,
  lockUser/cleanupExpired, hash/randomToken. The latter helpers are temporarily
  public because host signup/password/session handlers still use them; moving
  those workflows belongs to Phase C. Rotation-specific issuance is private.
- `LoginRateLimiter.checkIP/checkEmail`, `EmailRateLimitService.allow`,
  `EmailAction` and `EmailRateLimitPolicy`/Window support existing host composition.
  The low-level bucket consumption/query helpers are internal/private.
- `EmailService.withRequest`, `EmailSending`/`EmailMessage`,
  `EmailVerificationService.send/verify`, `EmailChangeService.request/confirm`
  expose only the calls and initializers needed by host controllers.
- `AuditLogService` construction, `AuditLogMiddleware`, `AuditEventType`,
  `AuditMetadata.Endpoint`, and request audit helpers support existing attachment
  and handler identity recording. Metadata fields/reasons/actions, HMAC helper,
  deduplication and database recording remain internal/private. `DatabaseID.audit`
  is public because the host configures the separate audit connection.
- `MaintenancePolicy`, `DatabaseMaintenanceService.run` and `Result.succeeded`
  support the host command; targets, result details and deleteBatch stay internal.

Tests use `@testable import AuthenticationServerKit`; access was not widened for
integration-test helpers. The public model/helper surface can shrink only after
Phase C removes its host production call sites.

## Host injection and compatibility adapters

`Configuration/AuthenticationServiceAdapters.swift` supplies short host-only
initializer/checkIP overloads. Email services receive a lazy
`(Request) -> AuthenticationDependencies<Request>` provider; email/login/audit
receive purpose-specific IP resolvers. Explicit test transport and URL overrides
retain precedence. The audit key is still captured when the host constructs the
service. Environment lookup, Railway trust decisions, template branding, sender
and Resend transport remain host-owned. Maintenance retention environment parsing
also remains here. These adapters contain no duplicate authentication SQL.

The temporary convenience overloads can be removed when Phase C explicitly
composes package services. Environment parsing/IP trust configuration must remain
host-owned even after those overloads are removed.

All eleven host migration wrappers retain explicit `TrisAuthenticationServer.<Name>`
identities and delegate prepare/revert to the package. The existing
`AuthenticationMigrationBaseline.migrations()` list and configure registration are
unchanged. These identity wrappers must not be removed or double-registered as
part of Phase C without a separate migration compatibility strategy.

## Migration and concurrency preservation

`Tests/Baselines/pre-extraction-schema.sql` captures the original Phase A schema
and eleven Fluent migration bookkeeping records from a disposable local database,
before moving implementations. It contains no accounts, credentials or token data.
`MigrationCompatibilityTests.originalHistoryAndCleanInstallation` restores this
fixture only into the explicitly named `waktrainer_test_auth` database and checks:

1. Existing history: no pending migration; **zero prepare calls**; unchanged
   migration rows, table/index OIDs and schema signature.
2. Clean install: **eleven prepare calls**; original column order/types/defaults/
   nullability, constraints/FKs and indexes reproduced exactly.

Fluent still performs its own existing bookkeeping-table `CREATE TABLE IF NOT
EXISTS` setup; zero prepare calls means extraction introduces no new auth DDL on
an already migrated database. No production migration history is queried.

Source comparison confirmed all eleven migration implementation bodies are
unchanged apart from their internal type-name suffix. All 31 SQL `.raw` literals
across production source before/after extraction are identical. Review also
preserved transaction closures, user lock order, refresh re-read, CURRENT_TIMESTAMP
versus Date usage, `FOR UPDATE`/`SKIP LOCKED`, fixed windows, audit fallback and
maintenance cutoff/batch control flow. Runtime regression tests remain essential;
text comparison alone is not proof of all concurrency interleavings.

The server lifecycle still invokes password reset, email verification/change,
session management/races, both rate limiters, error contracts, audit (including
nested deduplication), maintenance and host injection checks. No invocation or
existing server test was removed.

## OpenAPI baseline

Only generator source discovery changed: DTO/error sources can be found in the
package, public declarations are recognized, and duplicate DTO definitions fail.
Server route/handler discovery and actual server route/DTO contract tests remain.
No schema, component, operation ID, response or expected output was changed.

| File | Unchanged SHA-256 |
| --- | --- |
| docs/openapi/openapi.json | `6cd827d29d80446fa69e39c421c0825272faf52ce45fe13b3be854c9d99cc12b` |
| docs/openapi/operations.json | `003cf32972dd8669b70f9a57d63db84f72d13c91dd9c72600fdfe79089ca9f48` |

OpenAPI 3.0.3 validation, reference resolution and generated-current-output check
cover the existing 18 operations. The frozen Phase A JSON fixture is unchanged.

## Validation commands

```sh
swift build
swift test --no-parallel
swift build --package-path Packages/AuthenticationServerKit
swift test --package-path Packages/AuthenticationServerKit
python scripts/openapi.py --check
python -m unittest discover -s scripts -p test_openapi.py
git diff --check
```

Use the Python environment in `docs/openapi/README.md`. The server suite requires
TEST_DATABASE_* settings for disposable PostgreSQL `waktrainer_test_auth`;
never run concurrent suites against that database. The migration compatibility
test restores/reverts its schema. Email integration uses mocks, not Resend.
Use the separate default build directories for server and independent package
validation. Do not point both package roots at the same scratch directory: SwiftPM
can reuse the wrong test build plan and report success without running server tests.

Final local validation (Swift 6.3, disposable PostgreSQL, mock email):

| Checkpoint | Server | Package |
| --- | --- | --- |
| Phase A baseline | 10 tests / 9 suites | 3 tests / 1 suite |
| B1 | build passed; 11 tests / 10 suites passed | build passed; 5 tests / 2 suites passed |
| B2 | build passed; 11 tests / 10 suites passed | build passed; 7 tests / 4 suites passed |
| B3 final | build passed; 11 tests / 10 suites passed (52.263s) | build passed; 10 tests / 5 suites passed (0.021s) |

The server gained one migration compatibility test; all original tests remain.
The package gained two policy tests, retained copies of the JWT and metadata tests,
and three service-boundary tests (URL construction, keyed/domain-separated audit
identifiers, unavailable audit storage preserving successful responses).
Server JWT/metadata tests were not deleted. Package-only tests use no database.

OpenAPI standard/reference/current-output validation passed for 18 operations;
all three Python generator tests passed. Frozen document hashes, eleven migration
names/order, original-history zero-prepare compatibility and clean-schema checks
passed. `git diff --check` and forbidden host/iOS/environment-reference checks
passed. Root dependency lockfile, routes/configure, Dockerfile and CI are unchanged.
Production services were not used.

## Explicitly retained / Phase C

- AuthController, SessionController, route registration, /hello and top-level
  APIErrorMiddleware remain host-owned. Signup/login/password reset/change and
  session-revocation orchestration embedded in those controllers stays there;
  only validation and refresh-core delegation were introduced in this phase.
- Provider adapter, sender/subjects/HTML, environment/Railway parsing, database/JWT
  setup and MaintenanceCommand remain host responsibilities, not missing reusable
  implementations to copy into the package.
- OpenAPI baseline ownership, whole server integration suite, Docker/CI handling,
  deployment and minimal standalone-host validation remain deferred to Phase C.
  The pre-existing local-package Docker COPY limitation documented in Phase A
  remains; this change is not a production deployment validation.
- No separate repository, release/tag, commit or push was performed.

## Changed-file inventory

Paths are relative to the repository root. `D` denotes the original implementation
removed from the host; its package source is listed as `A`. Migration files marked
`M` remain identity-preserving wrappers. No staging or commit is implied.

```text
A	Packages/AuthenticationServerKit/Package.resolved
M	Packages/AuthenticationServerKit/Package.swift
M	Packages/AuthenticationServerKit/README.md
A	Packages/AuthenticationServerKit/Sources/AuthenticationServerKit/Audit/AuditContext.swift
A	Packages/AuthenticationServerKit/Sources/AuthenticationServerKit/Audit/AuditEvent.swift
A	Packages/AuthenticationServerKit/Sources/AuthenticationServerKit/Audit/AuditLogMiddleware.swift
A	Packages/AuthenticationServerKit/Sources/AuthenticationServerKit/Audit/AuditLogService.swift
A	Packages/AuthenticationServerKit/Sources/AuthenticationServerKit/Audit/AuditMetadata.swift
A	Packages/AuthenticationServerKit/Sources/AuthenticationServerKit/Auth/AccessTokenPayload.swift
A	Packages/AuthenticationServerKit/Sources/AuthenticationServerKit/Auth/AuthSession.swift
A	Packages/AuthenticationServerKit/Sources/AuthenticationServerKit/Auth/LoginRateLimiter.swift
A	Packages/AuthenticationServerKit/Sources/AuthenticationServerKit/DTOs/APIErrorResponseDTO.swift
A	Packages/AuthenticationServerKit/Sources/AuthenticationServerKit/DTOs/AuthDTOs.swift
A	Packages/AuthenticationServerKit/Sources/AuthenticationServerKit/DTOs/ResetPasswordRequestDTO.swift
A	Packages/AuthenticationServerKit/Sources/AuthenticationServerKit/DTOs/SessionManagementDTOs.swift
A	Packages/AuthenticationServerKit/Sources/AuthenticationServerKit/Errors/APIError.swift
A	Packages/AuthenticationServerKit/Sources/AuthenticationServerKit/Migrations/AddEmailChangeMigration.swift
A	Packages/AuthenticationServerKit/Sources/AuthenticationServerKit/Migrations/AddEmailVerificationMigration.swift
A	Packages/AuthenticationServerKit/Sources/AuthenticationServerKit/Migrations/AddSessionMetadataMigration.swift
A	Packages/AuthenticationServerKit/Sources/AuthenticationServerKit/Migrations/AuthenticationMigrations.swift
A	Packages/AuthenticationServerKit/Sources/AuthenticationServerKit/Migrations/CreateAuditLogMigration.swift
A	Packages/AuthenticationServerKit/Sources/AuthenticationServerKit/Migrations/CreateEmailRateLimitMigration.swift
A	Packages/AuthenticationServerKit/Sources/AuthenticationServerKit/Migrations/CreateLoginRateLimitMigration.swift
A	Packages/AuthenticationServerKit/Sources/AuthenticationServerKit/Migrations/CreatePasswordResetTokenMigration.swift
A	Packages/AuthenticationServerKit/Sources/AuthenticationServerKit/Migrations/CreateRefreshTokenMigration.swift
A	Packages/AuthenticationServerKit/Sources/AuthenticationServerKit/Migrations/CreateUserMigration.swift
A	Packages/AuthenticationServerKit/Sources/AuthenticationServerKit/Migrations/IndexMaintenanceExpiryMigration.swift
A	Packages/AuthenticationServerKit/Sources/AuthenticationServerKit/Migrations/IndexSessionUserExpiryMigration.swift
A	Packages/AuthenticationServerKit/Sources/AuthenticationServerKit/Models/AuditLog.swift
A	Packages/AuthenticationServerKit/Sources/AuthenticationServerKit/Models/EmailChangeToken.swift
A	Packages/AuthenticationServerKit/Sources/AuthenticationServerKit/Models/EmailVerificationToken.swift
A	Packages/AuthenticationServerKit/Sources/AuthenticationServerKit/Models/PasswordResetToken.swift
A	Packages/AuthenticationServerKit/Sources/AuthenticationServerKit/Models/RefreshToken.swift
A	Packages/AuthenticationServerKit/Sources/AuthenticationServerKit/Models/User.swift
A	Packages/AuthenticationServerKit/Sources/AuthenticationServerKit/Policies/AuthenticationValidation.swift
A	Packages/AuthenticationServerKit/Sources/AuthenticationServerKit/Policies/EmailRateLimitPolicy.swift
A	Packages/AuthenticationServerKit/Sources/AuthenticationServerKit/Services/DatabaseMaintenanceService.swift
A	Packages/AuthenticationServerKit/Sources/AuthenticationServerKit/Services/EmailChangeService.swift
A	Packages/AuthenticationServerKit/Sources/AuthenticationServerKit/Services/EmailRateLimitService.swift
A	Packages/AuthenticationServerKit/Sources/AuthenticationServerKit/Services/EmailService.swift
A	Packages/AuthenticationServerKit/Sources/AuthenticationServerKit/Services/EmailVerificationService.swift
A	Packages/AuthenticationServerKit/Tests/AuthenticationServerKitTests/AccessTokenTests.swift
A	Packages/AuthenticationServerKit/Tests/AuthenticationServerKitTests/ContractPolicyTests.swift
A	Packages/AuthenticationServerKit/Tests/AuthenticationServerKitTests/ServiceBoundaryTests.swift
A	Packages/AuthenticationServerKit/Tests/AuthenticationServerKitTests/SessionMetadataTests.swift
M	README.ko.md
M	README.md
D	Sources/TrisAuthenticationServer/Audit/AuditEvent.swift
D	Sources/TrisAuthenticationServer/Audit/AuditLogMiddleware.swift
D	Sources/TrisAuthenticationServer/Audit/AuditLogService.swift
D	Sources/TrisAuthenticationServer/Auth/AccessTokenPayload.swift
D	Sources/TrisAuthenticationServer/Auth/AuthSession.swift
D	Sources/TrisAuthenticationServer/Auth/LoginRateLimiter.swift
A	Sources/TrisAuthenticationServer/Configuration/AuthenticationServiceAdapters.swift
M	Sources/TrisAuthenticationServer/Controllers/AuthController.swift
M	Sources/TrisAuthenticationServer/Controllers/SessionController.swift
D	Sources/TrisAuthenticationServer/DTOs/APIErrorResponseDTO.swift
D	Sources/TrisAuthenticationServer/DTOs/AuthDTOs.swift
D	Sources/TrisAuthenticationServer/DTOs/ResetPasswordRequestDTO.swift
D	Sources/TrisAuthenticationServer/DTOs/SessionManagementDTOs.swift
D	Sources/TrisAuthenticationServer/Errors/APIError.swift
M	Sources/TrisAuthenticationServer/Middleware/APIErrorMiddleware.swift
M	Sources/TrisAuthenticationServer/Migrations/AddEmailChangeMigration.swift
M	Sources/TrisAuthenticationServer/Migrations/AddEmailVerificationMigration.swift
M	Sources/TrisAuthenticationServer/Migrations/AddSessionMetadataMigration.swift
M	Sources/TrisAuthenticationServer/Migrations/CreateAuditLogMigration.swift
M	Sources/TrisAuthenticationServer/Migrations/CreateEmailRateLimitMigration.swift
M	Sources/TrisAuthenticationServer/Migrations/CreateLoginRateLimitMigration.swift
M	Sources/TrisAuthenticationServer/Migrations/CreatePasswordResetTokenMigration.swift
M	Sources/TrisAuthenticationServer/Migrations/CreateRefreshTokenMigration.swift
M	Sources/TrisAuthenticationServer/Migrations/CreateUserMigration.swift
M	Sources/TrisAuthenticationServer/Migrations/IndexMaintenanceExpiryMigration.swift
M	Sources/TrisAuthenticationServer/Migrations/IndexSessionUserExpiryMigration.swift
D	Sources/TrisAuthenticationServer/Models/AuditLog.swift
D	Sources/TrisAuthenticationServer/Models/EmailChangeToken.swift
D	Sources/TrisAuthenticationServer/Models/EmailVerificationToken.swift
D	Sources/TrisAuthenticationServer/Models/PasswordResetToken.swift
D	Sources/TrisAuthenticationServer/Models/RefreshToken.swift
D	Sources/TrisAuthenticationServer/Models/User.swift
M	Sources/TrisAuthenticationServer/Services/DatabaseMaintenanceService.swift
D	Sources/TrisAuthenticationServer/Services/EmailChangeService.swift
D	Sources/TrisAuthenticationServer/Services/EmailRateLimitService.swift
M	Sources/TrisAuthenticationServer/Services/EmailService.swift
D	Sources/TrisAuthenticationServer/Services/EmailVerificationService.swift
A	Tests/Baselines/pre-extraction-schema.sql
M	Tests/TrisAuthenticationServerTests/APIErrorIntegrationTests.swift
M	Tests/TrisAuthenticationServerTests/APIErrorMiddlewareTests.swift
M	Tests/TrisAuthenticationServerTests/AccessTokenTests.swift
M	Tests/TrisAuthenticationServerTests/AuditDeduplicationTests.swift
M	Tests/TrisAuthenticationServerTests/AuditIntegrationTests.swift
M	Tests/TrisAuthenticationServerTests/AuthIntegrationTests.swift
M	Tests/TrisAuthenticationServerTests/EmailChangeIntegrationTests.swift
M	Tests/TrisAuthenticationServerTests/EmailVerificationIntegrationTests.swift
M	Tests/TrisAuthenticationServerTests/ExtractionBaselineTests.swift
M	Tests/TrisAuthenticationServerTests/HostDependencyBoundaryTests.swift
M	Tests/TrisAuthenticationServerTests/HostDependencyIntegrationTests.swift
M	Tests/TrisAuthenticationServerTests/MaintenanceIntegrationTests.swift
M	Tests/TrisAuthenticationServerTests/MaintenancePolicyTests.swift
A	Tests/TrisAuthenticationServerTests/MigrationCompatibilityTests.swift
M	Tests/TrisAuthenticationServerTests/MockEmailService.swift
M	Tests/TrisAuthenticationServerTests/OpenAPIContractTests.swift
M	Tests/TrisAuthenticationServerTests/SessionConcurrencyTests.swift
M	Tests/TrisAuthenticationServerTests/SessionManagementIntegrationTests.swift
M	Tests/TrisAuthenticationServerTests/SessionMetadataTests.swift
M	Tests/TrisAuthenticationServerTests/SessionMigrationTests.swift
M	Tests/TrisAuthenticationServerTests/TrisAuthenticationServerTests.swift
A	docs/authentication-extraction-phase-b.md
M	scripts/openapi.py
```
