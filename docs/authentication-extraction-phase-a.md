# AuthenticationServerKit extraction: Phase A

## Implemented boundary

WakTrainerServer depends on the local `Packages/AuthenticationServerKit` product.
The package declares configuration and Sendable closure interfaces only. No
controller, API DTO/error, Fluent model/migration, AuthSession, rate-limit SQL,
audit persistence or maintenance implementation moves in this phase.

`AuthenticationHostDependencies.live()` owns environment lookup, existing branded
email templates, Resend delivery and the existing IP trust policy. `configure`
accepts an optional explicit `AuthenticationDependencies<Request>` argument and
stores it on the Application before registering routes. Test/tool applications
that bypass configure retain the host live fallback. Set dependencies before
route registration; the audit service captures its key at registration time.

Consumers use the injected URL/template/delivery/IP values at their existing
call sites. Explicit controller URL and EmailService transport overrides retain
precedence for existing tests. URL validation, token generation, recipient
binding, quota consumption and delivery-failure suppression remain in the server.
URL providers preserve lazy lookup. Missing email settings therefore still fail
at the same operation stage instead of introducing startup validation.

The login resolver uses the direct connection address. Email and audit resolvers
retain validated Railway X-Real-IP handling only when the existing host setting
permits it. No client forwarding header becomes trusted by default.

Database connections, JWT keys, password hashing, rate-limit policies and
maintenance policy remain configured as before. Audit keys are supplied through
configuration; empty keys are still treated as unavailable. Package initializers
have no side effects and provide no secret values or provider-specific defaults.

## Frozen baseline

`Tests/Baselines/authentication-extraction.json` records SHA-256 digests of the
existing OpenAPI JSON and operation metadata, plus the exact 11 migration names
in registration order. `ExtractionBaselineTests` compares actual Fluent migration
names and the committed document bytes against this independent fixture.
Do not regenerate this fixture to make extraction changes pass.

`AuthenticationMigrationBaseline.migrations()` is the list used by configure.
Migration files, schema SQL, module ownership and names are unchanged. Phase B
must preserve these names when introducing delegation/wrappers. Production's
migration history has not been queried by Phase A; deployment-time comparison
remains necessary before a later migration implementation move.

The existing OpenAPI contract assertions are unchanged. New tests verify actual
host audit-key wiring and lazy URL access, and the existing PostgreSQL lifecycle
now also exercises injected URL bases, rendering, delivery and IP quota buckets.
The package suite checks use without the server and unchanged transport errors.
No existing test is moved.

## Validation

```sh
swift build
swift build --package-path Packages/AuthenticationServerKit
swift test --package-path Packages/AuthenticationServerKit
swift test --filter 'ExtractionBaselineTests|HostDependencyBoundaryTests|OpenAPIContractTests'
swift test --no-parallel
```

The full server suite requires the existing disposable `waktrainer_test_auth`
database and TEST_DATABASE_* settings. Run against a test database only; do not
run multiple integration suites concurrently on that database.

Run the existing `scripts/openapi.py --check` with the Python environment described
in `docs/openapi/README.md`; no generator/CI changes are needed in Phase A.

## Explicitly deferred

Phase B moves implementations. Phase C moves route ownership/tests and updates
OpenAPI tooling, CI, Docker and the minimal consuming host. The current Dockerfile
resolves dependencies before copying the repository, so it cannot resolve this
new local package at that early layer until the planned package COPY adjustment.
Phase A is validated locally and is not ready for the unchanged Docker deployment
pipeline. No Dockerfile or production deployment is changed in this phase.
