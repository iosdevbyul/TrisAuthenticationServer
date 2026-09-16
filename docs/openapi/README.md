# Public API contract baseline

`openapi.json` is the generated, committed OpenAPI 3.0.3 artifact for Roadmap #7.
It includes all 18 registered operations (17 auth operations and `GET /hello`).
There are no public audit, maintenance, Swagger or OpenAPI-serving routes. Railway
configuration and production request behavior are unchanged.

## Generate and validate

From the repository root, with Python 3.10+:

```sh
python3 -m venv /tmp/waktrainer-openapi
/tmp/waktrainer-openapi/bin/pip install -r scripts/openapi-requirements.txt
/tmp/waktrainer-openapi/bin/python scripts/openapi.py
/tmp/waktrainer-openapi/bin/python scripts/openapi.py --check
/tmp/waktrainer-openapi/bin/python -m unittest discover -s scripts -p 'test_openapi.py'
swift build
swift test --filter OpenAPIContractTests
```

`--check` validates OpenAPI using `openapi-spec-validator`, resolves every local
reference and rejects stale generated output. Generation does not read `.env`,
connect to a database, run migrations or make HTTP requests to the application.
The Python dependency is tooling-only. Existing VaporToOpenAPI package changes
are preserved, but this workflow does not require route annotations or runtime UI.

Full regression: `swift test --no-parallel`, with the existing disposable
`waktrainer_test_auth` database and `TEST_DATABASE_*` settings described in the
root README. Never use a production database. The compiled OpenAPI suite itself
requires no database. The GitHub workflow runs generation/staleness, specification,
reference and Python regression checks. Swift build/tests remain local checks;
the workflow does not provision Swift or PostgreSQL.

## Sources and update policy

- `Sources/TrisAuthenticationServer/DTOs/*.swift`: property types and requiredness.
- `AuthController.swift` / `SessionController.swift`: route, request/response DTO
  and current Bearer checks.
- `APIError.swift`: complete error-code catalog and default status mapping.
- `operations.json`: reviewed summaries, behavior descriptions and reachable
  service/controller errors, keyed by handler name.
- `scripts/openapi.py`: composition, common middleware errors, safe headers and
  field descriptions that JSON Schema cannot precisely express.

Edit source/metadata, regenerate, review the JSON diff, then run validation and
Swift contract tests together. The bounded extractor supports today's simple
stored-property Content DTOs and route declarations, not arbitrary Swift syntax.
Custom CodingKeys, custom Codable or new routing conventions require extending
this tooling and its tests. It is not a compiler or proof of service behavior.
Compiled tests compare the complete live route registry and real Vapor encodings
for every public DTO; Python checks alone cannot replace these tests.

Error status/code pairs are narrowed in each operation's response schema. The
component catalog also retains currently unused codes already defined in the
server (including EMAIL_VERIFICATION_REQUIRED), without claiming they are
returned by protected endpoints. Generic middleware fallback HTTP_ERROR may
carry an Abort status other than its catalog default 500. Unknown paths/methods
return 404 NOT_FOUND; no artificial catch-all public route is added.

JSON is the primary format. Vapor also currently registers JSON API, URL-encoded
and multipart decoders for these bodies. Optional output properties are omitted,
not emitted as null. Swift Character counts and UTF-8 byte limits are described
in prose rather than incorrect JSON Schema minLength/maxLength constraints.
Request decoders ignore unknown fields, so schemas do not forbid extra fields.

Only login throttling emits Retry-After; email-change throttling returns 429
without that header. Signup/resend hide delivery failures; forgot-password hides
throttling but may expose EMAIL_DELIVERY_FAILED (502). Email link query tokens
belong to the frontend; the server accepts them in POST request bodies.

## View locally

Open `openapi.json` in an OpenAPI viewer in your editor, or mount it in a locally
installed Swagger UI configured with `supportedSubmitMethods: []` to disable
interactive requests. No UI server is bundled and no production server URL is
embedded. The raw file can also be read directly. Never paste real credentials
into documentation, examples or shared viewers.

OpenAPI semantics follow the [official 3.0.3 specification](https://spec.openapis.org/oas/v3.0.3.html).

## Before Roadmap #8

Keep this artifact as the pre-extraction review baseline. Run the same route,
DTO and error tests against the extracted AuthenticationServerKit integration.
Review changes to route prefixes, media types, date encoders, omitted fields,
error mappings/messages, token rotation, stable session IDs and session revocation
semantics. Service error reachability and business descriptions remain reviewed
metadata and must be checked whenever service implementation changes. Extend
integration coverage when changing these policies; generation alone cannot
infer transaction behavior, rate-limit suppression or concurrency guarantees.
