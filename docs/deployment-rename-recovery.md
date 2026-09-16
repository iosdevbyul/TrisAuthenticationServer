# Deployment after an executable/module rename

The executable and 11 registered migration identities now use `TrisAuthenticationServer`.
Fluent matches the complete migration name against `public._fluent_migrations.name`;
renaming a Swift module or editing a local database does not update a remote database.
The current canonical schema fixture validates the new names. It does not establish
which names, or how many migrations, are present in production.

Do not run reset, drop, revert, delete migration rows, insert fabricated history, or
add `IF NOT EXISTS` to mask a name mismatch. Keep the existing production database
and volume. The public hostname is independent of migration identities; changing it
is not part of this recovery and could break existing clients.

## First establish the actual failure

1. In Railway, select the existing project, production environment, and backend
   service. Open **Deployments**, select the failed deployment, check its commit,
   and open the pre-deploy/deploy logs (not only Build Logs). Record the first error
   and the migration listed immediately before it. Do not share connection URLs,
   passwords, JWT secrets, or provider keys.
2. Verify **Settings → Deploy → Pre-deploy Command** is
   `./TrisAuthenticationServer migrate --env production --yes`. The Docker image
   uses `/app` and contains `/app/TrisAuthenticationServer`.
3. Classify the error before applying any history repair:
   - Executable missing: verify that deployment's image/commit and executable path.
   - Required `DATABASE_PASSWORD` or `JWT_SECRET` missing: repair the relevant
     variable reference without changing the database or exposing its value.
   - Connection/authentication failure: verify `DATABASE_HOST`, `DATABASE_PORT`,
     `DATABASE_USERNAME`, `DATABASE_NAME`, and `DATABASE_PASSWORD` still refer to
     the existing PostgreSQL service. This application reads these individual
     variables, not `DATABASE_URL`. Renaming a service can require reviewing references.
   - `42P07` / `relation "users" already exists` while preparing `CreateUserMigration`:
     inspect the migration ledger below. A prefix mismatch is a possible cause,
     not proof that every migration has already run.
   - Other DDL errors: investigate that migration's real schema state. A history
     rename must not be used to mark an incomplete migration as complete.

Railway pre-deploy commands run in a separate container with service environment
variables/private networking, and do not mount volumes. Local Compose volume names
do not change the production PostgreSQL ledger.

References: [deployment logs](https://docs.railway.com/observability/logs),
[pre-deploy commands](https://docs.railway.com/deployments/pre-deploy-command).

## Read-only production inventory

If Railway shows only “Pre-deploy command failed”, the cause is still unconfirmed.
Do not repair history from that message alone. Open the existing PostgreSQL service
in the same production environment and look for its **Connect** connection details.
Use those details in a local PostgreSQL client (for example, `psql` or an existing
SQL GUI). Railway's browser UI does not need to provide a SQL editor. If a public
connection endpoint is unavailable, an authorized operator must provide a connection
or run the read-only query; do not provision a replacement database. Never paste
connection credentials into chat. Until this inventory is available, local reproduction
only establishes a possible cause, and retrying production migrations remains unverified.

Use the existing PostgreSQL service's connection details in Railway and your SQL
client. If using local `psql`, configure `PGHOST`, `PGPORT`, `PGUSER`, `PGDATABASE`
and the TLS settings from that connection's instructions. Use its public connection
endpoint for a local client, not a private Railway hostname. `-W` prompts for the
password; do not put a password/connection URL in a shell command or the repository.

```sh
python3 scripts/migration_history.py inspect > /tmp/migration-history-inspect.sql
psql -X -W -qAt -v ON_ERROR_STOP=1 -f /tmp/migration-history-inspect.sql > /tmp/migration-history.json
python3 -m json.tool /tmp/migration-history.json
```

The first command only prints SQL. The second executes a read-only transaction
and exports every ledger row, including IDs, batches, and timestamps. A SQL client
can run the printed SELECT transaction instead; save just its JSON result.
Keep all snapshots/plans outside the repository.

Before any UPDATE, confirm the database/service, review every row and the matching
schema, and count the rows carrying the previous module prefix. Do not assume 11.
If history is missing for objects that already exist, stop and investigate; this
tool does not infer completed migrations from table names. Take a database backup
using the established production procedure before approving changes.

## Generate and rehearse a reviewed plan

Set `SOURCE_MIGRATION_MODULE` to the exact previous module prefix observed by
SELECT (without the trailing dot), and `OBSERVED_ROW_COUNT` to its verified count.
These are operator-supplied values, not hardcoded legacy names.

```sh
python3 scripts/migration_history.py plan /tmp/migration-history.json \
  --source-prefix "$SOURCE_MIGRATION_MODULE" --expected-count "$OBSERVED_ROW_COUNT" \
  > /tmp/migration-history-review.sql
```

This offline tool does not connect to a database. It only maps observed, recognized
migration suffixes to the current committed baseline. Partial histories are supported;
missing migrations are not inserted or marked as applied. Unknown source migrations,
duplicate IDs/names, source/target collisions, and count mismatches are rejected.
Zero matching rows produce no UPDATE.

Pause/cancel concurrent deployment attempts and ensure no migrator is running before
executing the plan. The ledger lock cannot prevent a migrator from running schema DDL
before it tries to write its ledger row. Normal serving does not run migrations.

Review the SQL, then rehearse it:

```sh
psql -X -W -v ON_ERROR_STOP=1 -f /tmp/migration-history-review.sql
```

The default plan ends with **ROLLBACK**. It locks only the migration ledger, verifies
the complete SELECT snapshot and database name, changes only `name`, checks the exact
UPDATE count, and verifies that every other row/field is unchanged. Locks/statements
have bounded timeouts. Any discrepancy aborts the transaction.

Only after the SELECT, schema review, expected count, backup and rehearsal have been
approved, generate the same plan with `--commit`, review it, and run it explicitly:

```sh
python3 scripts/migration_history.py plan /tmp/migration-history.json \
  --source-prefix "$SOURCE_MIGRATION_MODULE" --expected-count "$OBSERVED_ROW_COUNT" \
  --commit > /tmp/migration-history-commit.sql
psql -X -W -v ON_ERROR_STOP=1 -f /tmp/migration-history-commit.sql
```

Export a new read-only inventory and verify the expected names and unchanged IDs,
batches and timestamps. If another process changed history after inspection, export
and review again instead of weakening the checks. Do not replay the stale SQL.

## Resume deployment

Only after production inventory/repair is verified, retry the intended Railway
backend deployment with the unchanged pre-deploy command. For a fully applied
11-migration schema it must report `No new migrations.`. For a reviewed partial
installation, only genuinely pending migrations should run in the registered order.
If already-applied schema migrations are listed, stop instead of accepting them.
Do not redeploy an older executable whose migration prefix differs from the ledger.

No script here automatically deploys, changes Railway variables, or accesses production.
The helper emits a manual proposal; it is not installed in the runtime image's entrypoint.

## CI validation

Keep the server's `.build` and the package's `Packages/AuthenticationServerKit/.build`
separate. Sharing a scratch directory across these two SwiftPM roots can reuse the
package test discovery plan for a server invocation. Check suite names as well as
exit status: the server must run `Extraction migration compatibility`, `Phase A
extraction baseline`, and `OpenAPI contract (no database)`.

```sh
swift build
swift build --package-path Packages/AuthenticationServerKit
swift test --package-path Packages/AuthenticationServerKit --no-parallel
swift test --no-parallel
python3 scripts/openapi.py --check
python3 -m unittest discover -s scripts -p 'test_*.py'
```

Swift tests require the documented disposable `TEST_DATABASE_*` settings and run
sequentially. Python checks include the offline planner refusal cases and do not
connect to any database.
