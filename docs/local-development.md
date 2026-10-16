# Local authentication development

This is an **isolated, disposable-development** PostgreSQL stack. It does not use the old `trisauthenticationserver_postgres_data` volume, and it does not change Railway or production configuration.

## Initial setup

From the repository root, run:

```sh
cp .env.example .env
```

Replace `DATABASE_PASSWORD` with a new development password and `JWT_SECRET` with the output of `openssl rand -base64 48`. Never commit `.env` or expose secrets in terminal screenshots.

Ensure Docker Desktop is running and `docker context use desktop-linux` is selected. This Compose stack binds PostgreSQL only to `127.0.0.1:5434` to avoid the existing port 5432 container and other projects.

```sh
docker compose -f docker-compose.local.yml config --quiet
docker compose -f docker-compose.local.yml up -d db
docker compose -f docker-compose.local.yml ps
```

Do not run `docker compose down -v`, `docker volume prune`, or remove the existing volume. This local stack uses the separate Compose project `waktrainer-auth-local`.

## Swift server

Swift 6.3 is required. Start from the repository root so Vapor loads `.env` with host `127.0.0.1` and port `5434`:

```sh
swift run TrisAuthenticationServer migrate --yes
swift run TrisAuthenticationServer serve --hostname 127.0.0.1 --port 8080
```

This configuration runs the Vapor process natively on the Mac and PostgreSQL in Docker. Migrations are explicit; do not assume that startup applies them.

Do not publish port 8080 directly to the internet. On-device iPhone testing requires separate LAN-accessible or securely tunneled configuration, which must be verified before changing the server bind address. Localhost on an iPhone is not the Mac.

## Portability

Railway, AWS and other hosting environments should supply their own `DATABASE_*`, `JWT_SECRET`, network, TLS and deployment settings. Domain/application code should not depend on the hosting provider. The iOS app's authentication API base URL is a separate client configuration concern; changing the server host alone does not redirect the app.

The existing default `docker-compose.yml` remains unchanged for backward compatibility. Existing PostgreSQL volumes and Railway data are untouched.
