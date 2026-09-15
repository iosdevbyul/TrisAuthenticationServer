# AuthenticationServerKit extraction: Phase C

Phase C moves the HTTP layer and completes explicit package integration. The
server's 18 operations (17 auth operations plus host-owned `/hello`), JSON/error
contract, schema and migration history baseline remain unchanged. Authentication
implementation has one production source in the package. There is no package
source/test import or reference to WakTrainerServer or the iOS AuthenticationKit.

## HTTP registration and host integration

`AuthController.swift` and `SessionController.swift` now live under package
`Sources/AuthenticationServerKit/Controllers`. The latter remains an extension of
AuthController, matching its original structure. Both are internal. Handler order,
body decoding/authentication/validation order and transaction bodies were retained.
The original host dependency lookups are supplied through an explicit lazy provider.

The single registration API is:

```swift
AuthenticationRoutes(
    dependencies: @escaping @Sendable (Request) -> AuthenticationDependencies<Request>,
    auditHashKey: String?,
    emailRateLimitPolicy: EmailRateLimitPolicy = .init()
)
```

It is a public RouteCollection; the host calls `register(collection:)`. Registration
adds exactly the existing 17 `/auth` routes, with the original individual audit
middleware attachments. It installs no global middleware, DB, JWT keys or migrations.
A host may register it on a grouped RoutesBuilder for an outer prefix such as `/v1`.

WakTrainerServer `routes.swift` retains `/hello` and registers AuthenticationRoutes
with its request-time Application dependency provider and registration-time audit
key. No credentials or configuration are evaluated earlier than before extraction.

APIErrorMiddleware normalization/encoding is generic and moved to the package.
Its constructor/respond method are public. The host retains only `install(on:)`,
including the exact original reset of default middleware and installation order.
The original JSONEncoder, error code/status/message/detail mapping, safe header
handling and fallback JSON body are unchanged. Registering package routes does not
silently change the middleware stack.

Host production responsibilities retained:

- AuthenticationHostDependencies: environment/URL/key lookup, existing direct-login
  versus Railway-trusted email/audit IP policy, and Application dependency storage.
- Branded AuthenticationEmail templates, sender and Resend transport. The transport
  now accepts AuthenticationEmail directly; it needs no internal package protocol.
- Database/JWT/password setup, audit pool configuration and middleware installation.
- MaintenanceCommand and host retention environment validation.
- Eleven historical migration identity wrappers and their existing ordered registry.

Phase B runtime service-convenience adapters have been removed from host production.
Only equivalent test-fixture overloads remain in AuthenticationTestAdapters.swift.
The host no longer implements authentication controllers, session/token helpers,
rate-limit SQL, email lifecycle, audit persistence or maintenance deletion logic.

## Public API before and after

Top-level public named types/aliases decreased from **48 to 31**. Nineteen became
internal and two integration types were added (AuthenticationRoutes and
APIErrorMiddleware). DTO/configuration/error/policy/maintenance/migration APIs
retained their existing contracts.

| Before Phase C | After Phase C |
| --- | --- |
| AuthSession and all its public hash/randomToken/lockUser/payload/validate/cleanupExpired/rotate/issue helpers | Internal; rotation-specific issuance remains private |
| AccessTokenPayload | Internal, including JWT claim access and construction |
| User, RefreshToken, PasswordResetToken, EmailChangeToken | Internal; previously internal EmailVerificationToken/AuditLog remain internal |
| AuthenticationValidation and LoginRateLimiter | Internal |
| EmailRateLimitService, EmailService, EmailSending, EmailMessage, EmailVerificationService, EmailChangeService | Internal |
| AuditContext, AuditEventType, AuditMetadata, AuditLogService, AuditLogMiddleware and request audit helpers | Internal |
| No public auth registrar; host error middleware implementation | Public AuthenticationRoutes and APIErrorMiddleware |

The final public surface is:

- AuthenticationURLs, AuthenticationConfiguration, AuthenticationDependencies,
  AuthenticationEmail, AuthenticationEmailPurpose, AuthenticationIPPurpose:
  host-owned lazy configuration, rendering, delivery and IP resolution.
- AuthenticationRoutes and APIErrorMiddleware: explicit HTTP composition.
- Auth/password/email/session request/response DTOs, APIErrorResponseDTO,
  APIValidationDetail, APIError, APIErrorCode: consuming hosts/clients can use the
  standardized wire contract without exposing persistence models.
- EmailAction and EmailRateLimitPolicy/Window: policy configuration accepted by
  AuthenticationRoutes; they do not expose bucket SQL or consumption helpers.
- AuthenticationMigrations.Step/make: host wrapper delegation and explicit
  new-host registration; implementation migration types remain internal.
- MaintenancePolicy and DatabaseMaintenanceService.run/Result.succeeded: host
  command/scheduling. Batch deletion/targets/result implementation details remain internal.
- DatabaseID.audit: the host still configures the dedicated audit connection.

No temporary AuthSession/model/email/audit helper remains public. Tests that need
internals use @testable rather than widening production access.

## Test ownership and independent reuse

The package now has three test targets:

1. AuthenticationServerKitTests: dependency/policy/JWT/metadata/service tests and
   the moved APIErrorMiddleware contract/redaction unit test.
2. AuthenticationIntegrationTests: reusable PostgreSQL lifecycle and password,
   email verification/change, session management/races, both rate limiters, error,
   audit/dedup/fallback, maintenance and schema-upgrade checks. It registers the
   public AuthenticationRoutes using generic mock rendering/delivery, explicit
   DB/JWT configuration and package migrations. No branded template or host import
   is needed. The PostgreSQL driver dependency is test-only.
3. StandaloneHostTests: normal public imports only (no @testable). A minimal Vapor
   application configures JWT/dependencies/error middleware and runs requests for
   both `/auth` and `/v1/auth`. It verifies 17 routes, error responses and absence
   of `/hello`. It does not need a DB, deployable example or second server product.

Server JWT/metadata duplicate unit files and the error-middleware unit file were
removed only after equivalent package tests passed. The full existing server
lifecycle remains as host/template/end-to-end protection, including all twelve
helper calls and the nested audit checks. Its Railway/proxy and host dependency
checks remain there; those host-specific checks are deliberately not copied into
the generic package integration target. Reusable integration assertions are
retained in both package and host contexts intentionally; production implementation
is not duplicated.

The server also retains OpenAPI route/DTO/error contract checks, historical
migration baseline/compatibility, retention environment validation, `/hello`, and
host audit-key/lazy URL injection checks. The client implementation/assertions remain unchanged. The existing E2E runner
was corrected to use the actual AuthenticationKitDemo-Local scheme, Debug and an
explicit localhost API_BASE_URL; its old AuthenticationKitDemo scheme no longer
exists in the current client repository.

| Checkpoint | Server tests | Package tests |
| --- | --- | --- |
| Before C | 11 / 10 suites | 10 / 5 suites |
| C1 | 11 / 10 suites passed | 10 / 5 suites passed |
| C2 | 11 / 10 suites passed | Covered again by final package run |
| Final C3 | 8 / 7 suites passed (54.907s) | 13 / 8 suites passed (51.729s) |

Both package and server builds passed. Full suites were run serially against the
local disposable `waktrainer_test_auth` PostgreSQL database, never production.

## Contract, migration and concurrency checks

OpenAPI source discovery now reads the two controller files from the package.
No other generator behavior or expected output was changed. OpenAPI 3.0.3 validity,
reference resolution, generated-current-output check and all three Python tests
pass: 18 operations, 17 schemas and 21 error codes. Actual host routes/response
DTO types and real Vapor DTO encodings continue to be compared with the document.

| Frozen file | Unchanged SHA-256 |
| --- | --- |
| docs/openapi/openapi.json | `232af101692ad6bbf9d07bc52d6b6886edb9a915a7a750516b5496d974d75a3d` |
| docs/openapi/operations.json | `003cf32972dd8669b70f9a57d63db84f72d13c91dd9c72600fdfe79089ca9f48` |

The frozen extraction fixture, eleven host migration wrappers/registration order,
all package migration implementations and original schema fixture are unchanged.
Existing-history compatibility passes with **zero auth prepare calls**, unchanged
schema/history/table/index OIDs. A clean DB produces the same schema via eleven
prepare calls. No duplicate package + wrapper registration was introduced.
Fluent's existing bookkeeping setup still runs; it is not a new auth migration.

All 31 production SQL literals match the pre-C source inventory. SessionController
handler bodies and error responder body are unchanged; AuthController changes only
composition and the equivalent dependency-provider lookups. Existing transaction
boundaries, lock/re-read ordering, database/application time choices and SQL are
preserved and exercised by both integration contexts. Passing tests are not a
proof of every possible concurrency interleaving; no concurrency redesign was made.

## Docker and CI

Dockerfile now copies Packages/AuthenticationServerKit **before** `swift package
resolve --force-resolved-versions`. Root manifests/local package form the resolve
cache layer; changes to unrelated host sources still reuse it. The existing release
build/static Swift/jemalloc/resource staging and minimal Ubuntu runtime remain.
`.dockerignore` excludes nested Swift build caches, Git and environment files.
No environment file or secret was added to the image.

Actual local `docker build --progress=plain -t waktrainer-phase-c:local .` passed,
including local-package resolution and Linux release compilation. The runtime
image retains the executable name, vapor user, ENTRYPOINT and production serve CMD.
With networking disabled, runtime validation checked executable/shared-library
availability, absence of Sources/Packages/.env files, `/hello` 200, `/auth/me` 401,
and `migrate --env testing --help`. No runtime migration was executed.

The existing OpenAPI CI job and workflow triggers are unchanged. One Swift 6.3
job adds a disposable PostgreSQL service and sequential package/server build/tests.
The service uses test-only trust authentication, not production secrets. YAML
validation passes. GitHub-hosted execution requires the future push/PR; no workflow
was dispatched from this task. Existing dependency revisions are unchanged;
package resolution adds only the PostgreSQL driver's test dependency graph.

## iOS E2E and pre-extraction comparison

The current Demo build succeeds with the corrected Local scheme, Debug and a
verified built Info.plist API_BASE_URL of `http://127.0.0.1:8080`. No client code or
assertion was changed. Resend credentials were explicitly empty during the run.

- HTTP E2E: **2 passed, 0 failed** (authentication lifecycle and PostgreSQL password
  reset fixture; covers signup/login/me/refresh/password/logout/withdraw/storage).
- UI smoke: **1 failed** at AuthenticationKitDemoUITests.swift:11, before signup:
  the test tries to tap `Sign Up`, while the current authentication screen exposes
  the Korean sign-up control. Later UI flow assertions were not reached.
- The **same compiled UI test binary** was run against an isolated pre-C Phase B
  server snapshot from commit `610b3df`. It failed at the exact same line/selector
  (14.135s versus Phase C 14.142s). This is a deterministic existing client-test
  mismatch, not an extraction regression or a timing assertion relaxed to pass.
- Two earlier harness setup failures were diagnosed separately: empty test password
  versus the existing configure guard, and the removed old Demo scheme name. The
  local trust DB received an ephemeral nonempty test value; runner scheme selection
  was corrected without changing server behavior or any assertion.

The runner's `finally` stops its owned server, reverts the disposable migrations
and deletes its private credential-bearing xctestrun copy. The baseline comparison
also stops/reverts its owned server. The client working tree remained unchanged.
The unchanged UI smoke is not green; updating it to the current client navigation
is a separate client-test maintenance task, and was not hidden by skipping it.

## Remaining scope and safety

- Historical host migration identity wrappers are intentional compatibility, not
  duplicate schema implementations. Removing them requires a separate compatibility
  strategy; they were not removed merely because controllers moved.
- Host provider/branding/env/proxy/command/DB/JWT assembly remains intentional.
- Real inbox/provider delivery and Railway deployment are not tested or performed.
- No separate package repository, version tag, release, commit, push or deployment
  was performed. Production DB/services were not accessed.
- GitHub-hosted CI execution and production deployment remain outside this local task.
- The existing iOS Demo has no email-verification/change or session-management UI
  E2E cases. Those contracts are exercised by both package/server HTTP integration
  suites, including token lifecycle, session revocation and concurrency; no new
  client feature or weakened assertion was introduced.

## Final assessment and architecture

The AuthenticationServerKit extraction implementation is complete: HTTP/core
ownership, public surface reduction, explicit host integration, standalone reuse,
OpenAPI/migration preservation and container build/runtime checks are verified.
**The complete validation matrix is not all green:** the existing iOS UI smoke
fails on both Phase B and Phase C at the same stale selector. UI smoke success is
not claimed; no assertion was weakened. All final package/server tests and the
two iOS HTTP E2E tests pass. No extraction-scoped production implementation is left
unmoved; the existing client UI test maintenance and remote CI/deployment are not
performed in this task.

| WakTrainerServer owns | AuthenticationServerKit owns |
| --- | --- |
| /hello and explicit app composition | 17 auth routes and controllers |
| Provider, templates, environment, IP trust, URLs/key providers | Auth/password/email/session implementation and wire contracts |
| DB/JWT setup, middleware installation/order | Error middleware implementation, rate limiting, audit and maintenance core |
| Historical migration wrappers/order and MaintenanceCommand | Schema implementations and explicit migration/service entry points |
| OpenAPI baseline, host/E2E/migration compatibility checks | Reusable unit/integration tests and independent public-host fixture |

## Changed-file inventory

Paths are relative to the repository root. D/A pairs identify moved code; M is
a modified file. No staging or commit is implied.

```text
M	.dockerignore
M	.github/workflows/openapi.yml
M	Dockerfile
M	Packages/AuthenticationServerKit/Package.resolved
M	Packages/AuthenticationServerKit/Package.swift
M	Packages/AuthenticationServerKit/README.md
M	Packages/AuthenticationServerKit/Sources/AuthenticationServerKit/Audit/AuditContext.swift
M	Packages/AuthenticationServerKit/Sources/AuthenticationServerKit/Audit/AuditEvent.swift
M	Packages/AuthenticationServerKit/Sources/AuthenticationServerKit/Audit/AuditLogMiddleware.swift
M	Packages/AuthenticationServerKit/Sources/AuthenticationServerKit/Audit/AuditLogService.swift
M	Packages/AuthenticationServerKit/Sources/AuthenticationServerKit/Audit/AuditMetadata.swift
M	Packages/AuthenticationServerKit/Sources/AuthenticationServerKit/Auth/AccessTokenPayload.swift
M	Packages/AuthenticationServerKit/Sources/AuthenticationServerKit/Auth/AuthSession.swift
M	Packages/AuthenticationServerKit/Sources/AuthenticationServerKit/Auth/LoginRateLimiter.swift
A	Packages/AuthenticationServerKit/Sources/AuthenticationServerKit/AuthenticationRoutes.swift
A	Packages/AuthenticationServerKit/Sources/AuthenticationServerKit/Controllers/AuthController.swift
A	Packages/AuthenticationServerKit/Sources/AuthenticationServerKit/Controllers/SessionController.swift
A	Packages/AuthenticationServerKit/Sources/AuthenticationServerKit/Middleware/APIErrorMiddleware.swift
M	Packages/AuthenticationServerKit/Sources/AuthenticationServerKit/Models/EmailChangeToken.swift
M	Packages/AuthenticationServerKit/Sources/AuthenticationServerKit/Models/PasswordResetToken.swift
M	Packages/AuthenticationServerKit/Sources/AuthenticationServerKit/Models/RefreshToken.swift
M	Packages/AuthenticationServerKit/Sources/AuthenticationServerKit/Models/User.swift
M	Packages/AuthenticationServerKit/Sources/AuthenticationServerKit/Policies/AuthenticationValidation.swift
M	Packages/AuthenticationServerKit/Sources/AuthenticationServerKit/Services/EmailChangeService.swift
M	Packages/AuthenticationServerKit/Sources/AuthenticationServerKit/Services/EmailRateLimitService.swift
M	Packages/AuthenticationServerKit/Sources/AuthenticationServerKit/Services/EmailService.swift
M	Packages/AuthenticationServerKit/Sources/AuthenticationServerKit/Services/EmailVerificationService.swift
A	Packages/AuthenticationServerKit/Tests/AuthenticationIntegrationTests/APIErrorIntegrationTests.swift
A	Packages/AuthenticationServerKit/Tests/AuthenticationIntegrationTests/AuditDeduplicationTests.swift
A	Packages/AuthenticationServerKit/Tests/AuthenticationIntegrationTests/AuditIntegrationTests.swift
A	Packages/AuthenticationServerKit/Tests/AuthenticationIntegrationTests/AuthIntegrationTests.swift
A	Packages/AuthenticationServerKit/Tests/AuthenticationIntegrationTests/EmailChangeIntegrationTests.swift
A	Packages/AuthenticationServerKit/Tests/AuthenticationIntegrationTests/EmailVerificationIntegrationTests.swift
A	Packages/AuthenticationServerKit/Tests/AuthenticationIntegrationTests/MaintenanceIntegrationTests.swift
A	Packages/AuthenticationServerKit/Tests/AuthenticationIntegrationTests/MockEmailService.swift
A	Packages/AuthenticationServerKit/Tests/AuthenticationIntegrationTests/SessionConcurrencyTests.swift
A	Packages/AuthenticationServerKit/Tests/AuthenticationIntegrationTests/SessionManagementIntegrationTests.swift
A	Packages/AuthenticationServerKit/Tests/AuthenticationIntegrationTests/SessionMigrationTests.swift
A	Packages/AuthenticationServerKit/Tests/AuthenticationIntegrationTests/TestComposition.swift
A	Packages/AuthenticationServerKit/Tests/AuthenticationServerKitTests/APIErrorMiddlewareTests.swift
A	Packages/AuthenticationServerKit/Tests/StandaloneHostTests/StandaloneHostTests.swift
M	README.ko.md
M	README.md
M	Sources/WakTrainerServer/Configuration/AuthenticationHostDependencies.swift
M	Sources/WakTrainerServer/Configuration/AuthenticationServiceAdapters.swift
D	Sources/WakTrainerServer/Controllers/AuthController.swift
D	Sources/WakTrainerServer/Controllers/SessionController.swift
M	Sources/WakTrainerServer/Middleware/APIErrorMiddleware.swift
M	Sources/WakTrainerServer/Services/EmailService.swift
M	Sources/WakTrainerServer/routes.swift
D	Tests/WakTrainerServerTests/APIErrorMiddlewareTests.swift
D	Tests/WakTrainerServerTests/AccessTokenTests.swift
M	Tests/WakTrainerServerTests/AuthIntegrationTests.swift
A	Tests/WakTrainerServerTests/AuthenticationTestAdapters.swift
D	Tests/WakTrainerServerTests/SessionMetadataTests.swift
M	docs/authentication-e2e.md
A	docs/authentication-extraction-phase-c.md
M	scripts/openapi.py
M	scripts/run-authentication-e2e.py
```
