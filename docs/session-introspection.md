# Session introspection

`GET /auth/introspect` is the minimal backend-to-backend session-validation contract.
Send the user's access token in `Authorization: Bearer <access-token>` over HTTPS.
No request body is required.

A valid active session returns HTTP 200:

```json
{
  "active": true,
  "userId": "<user UUID>",
  "sessionId": "<session UUID>"
}
```

These are the only response fields. No email, profile, access token, refresh token,
or password data is returned. `/auth/me` remains the existing account/profile endpoint.

The handler calls `AuthSession.payload(from:)`, then `AuthSession.validate(...)`.
The existing helpers verify the JWT and its expiration, require `sid`, and check
that the session exists, belongs to `sub`, and has not expired. The handler uses
the returned session directly, without another session or user lookup.

`sessionId` matches the access token's `sid`. It is not the stable management ID
used by `DELETE /auth/sessions/:sessionID`. Refresh rotation replaces `sid` and
invalidates the previous access token under the existing session semantics.

## Authentication failures

Failures preserve the existing HTTP 401 `APIErrorResponseDTO` contract:

| Code | Condition |
| --- | --- |
| `AUTHENTICATION_REQUIRED` | Missing bearer authentication |
| `ACCESS_TOKEN_INVALID_OR_EXPIRED` | Invalid or expired JWT, including missing required session claims |
| `SESSION_INVALID` | Missing, expired, or mismatched server-side session |

Authentication failures never return HTTP 200 with `active: false`.
Logout, explicit revocation, password change, password reset, and account withdrawal
remove sessions through the existing flows. Their previous access tokens therefore
fail introspection even while their signatures and expiration remain valid.
A successful response describes session state when checked, not a guarantee against
subsequent revocation. Infrastructure failures remain server errors, not successful
authentication results.

## Integration boundary and validation

Consuming services call this HTTP endpoint; they do not query `users` or
`refresh_tokens`, own authentication persistence, or issue replacement credentials.
This addition requires no migration, new token format, JWT issuer, service API key,
cache, or consumer-specific configuration.

The package's PostgreSQL lifecycle suite covers active sessions, malformed or missing
authentication, expired access tokens, absent/mismatched/expired sessions, logout,
revocation, password change/reset, and withdrawal. Account invalidation tests use
real API flows with the existing mock email delivery service. Host and Python
contract tests check route security and the generated OpenAPI response schema.
See the root README for disposable test database setup and validation commands.
