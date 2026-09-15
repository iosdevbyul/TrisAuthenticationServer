# AuthenticationServerKit — Phase A

This independent Swift 6.3 package currently contains only configuration and
Sendable dependency interfaces. It has no external dependencies, environment
lookup, host import, routes, database models, migrations or authentication logic.
The eventual runtime implementation will target Vapor and PostgreSQL; Phase A
interfaces alone do not implement an authentication server.

Public surface:

- `AuthenticationURLs`: optional reset, verification and email-change URL bases.
- `AuthenticationConfiguration`: lazy `urls` and `auditHashKey` providers.
- `AuthenticationEmail`: recipient, subject and HTML delivery value (not an API DTO).
- `AuthenticationEmailPurpose`: reset, verification, change template selection.
- `AuthenticationIPPurpose`: login, email, audit IP resolution selection.
- `AuthenticationDependencies<Context: Sendable>`: configuration plus `renderEmail`,
  async throwing `sendEmail`, and `resolveIP` closures supplied by the host.

`renderEmail` receives purpose, recipient and the already constructed link in
that order. `sendEmail` receives the rendered message and host request context.
`resolveIP` receives that context and purpose. Providers and closures must be
thread-safe. Do not log rendered links, credential values or secrets. No provider
is evaluated by an initializer; the server retains validation/error timing.
The audit key is read when the host constructs its route audit service.

Build/test independently from the repository root:

```sh
swift build --package-path Packages/AuthenticationServerKit
swift test --package-path Packages/AuthenticationServerKit
```

The unit tests use an integer context and an in-memory actor delivery recorder;
they do not import WakTrainerServer or Vapor.
