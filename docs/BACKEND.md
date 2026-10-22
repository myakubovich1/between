# Shared backend and operations

## Environment

The repeatable local Supabase configuration uses ports 54321 (HTTP), 54322 (Postgres), 54323 (Studio) and 54324 (test mail). Tested with CLI 2.121.0, Docker 28.4.0 and local Edge Runtime 1.77.4. The Edge handler is TypeScript; all app screens are SwiftUI. `deno.json`, `deno.lock` and the backend-test npm lockfile pin dependencies.

A hosted project named Between Development was authorized in Hallovich Holdings.inc, us-east-1. The connected provider failed first with “Failed to create project service or origin protection keys: Call to createInitialAPIKeys failed”, then “Failed to retrieve organization.” No usable Between project, URL or publishable key was returned. Existing projects were not changed. Create/confirm a dedicated project in the dashboard, then use the migration and function below; do not point development fixtures at an unrelated project.

## Start or rebuild locally

From the project folder:

```sh
supabase start
supabase functions serve between-api
```

The migration and `seed.sql` create the safe public catalog, private contribution data, RLS, server-only RPCs, update counter and retention jobs. The seed contains venue metadata only: zero fabricated live reports. A fresh `supabase db reset --local` was run successfully to validate repeatability. The native app's catalog cache begins with the bundled copy, then reads the connected catalog. There is no silent Live → Demo fallback.

For hosted setup, inspect your chosen project's tables first, apply the versioned migration with Supabase tooling, seed its curated catalog, and deploy `between-api`. The function has `verify_jwt = false` because guest GETs are public; **every private route independently validates the bearer token with Auth**, then sensitive database functions also check the signed `session_id` against `auth.sessions`. Do not remove these checks or expose the service key to the app. Set the Auth provider to Apple for native contribution accounts. Password users exist only in the guarded localhost test runner.

## Endpoint contract

Base: `/functions/v1/between-api`. All JSON responses have `Cache-Control: no-store`.

| Method/path | Access | Result |
| --- | --- | --- |
| GET `catalog` | Guest | At most 100 active place documents with source metadata |
| GET `summaries` | Guest or signed in | `{evidence:[...]}`; blocks applied for an authenticated viewer |
| POST `reports` | Current authenticated session | `{id,acceptedAt,nearby}` after server acceptance |
| GET `reports/mine` | Current authenticated session | At most 100 own report records; no other author’s history |
| POST `feedback` | Current authenticated session | `{reference,action:"flag"|"block"}` → `{ok:true}` |
| DELETE `account` | Current authenticated Apple session | Fresh `{authorizationCode}` → revoke Apple authorization, hard-delete account and associated rows |

A report body contains `placeID`, optional `zoneID`, ordinal `seat` (0–3), optional `noise` (0–2), UUID `idempotencyKey`, ISO-8601 `reconfirmedAt`, and optional foreground `location` with latitude, longitude, accuracy and `sampledAt`. No author, trust score, acceptance timestamp or moderation field is trusted from the client. New confirmations must be within 120 seconds, with limited clock-skew allowance. Existing accepted idempotency keys return the original receipt without changing its acceptance time, including after a stale draft timestamp. Receipt lookup lasts for the retained report's lifetime (up to the 24-hour purge); clients generate new random keys for new observations.

HTTP 400 invalid scope/enum; 401 expired/missing sign-in; 403 ineligible account; 409 stale draft/Apple confirmation; 413 body over 4096 bytes; 429 rate limit with `retryAfter` seconds; 502/503 recoverable upstream failure. Request bodies are streamed with a size limit even without Content-Length. Zone membership and active scope checks also run in Postgres.

## Concurrency, evidence and freshness

`submit_observation` takes a transaction advisory lock per authenticated author. Multiple sessions cannot race the per-scope five-minute limit or the 20-per-hour global limit. Checks and insert happen in the same transaction; duplicate keys return their original row. Removed reports still count toward hourly rate limits while retained. The table uniquely constrains `(author,idempotency_key)`.

Aggregates use the latest accepted observation per author/scope, exclude suspended/deleting accounts, viewer blocks and removed latest observations, and discard age ≥30 minutes. Weight is presenceWeight × 2^(-ageMinutes/10), presenceWeight 1 for a passing limited nearby check, 0.5 otherwise. Exact median ties choose the lower ordinal. Two or more contributors with ≥30% weight on each side of the 0–1/2–3 divide produce “Reports differ.” Sound is aggregated separately and skipped answers remain absent. The API exposes no author IDs. Report references are opaque UUIDs, scoped to their observation.

Only `public.status_versions` is replicated: a campus ID and monotonically increasing version, without report contents. The native client listens while foregrounded, fetches the authorized aggregate after invalidation, removes the channel on leaving the foreground, and keeps a 60-second polling fallback. An independent client clock refreshes at the next expiration boundary even with no push. If offline, expired summaries lose their current status; older cached content is labeled as such. No report draft auto-uploads on reconnect.

## Proximity and logging

The Edge handler checks sample age ≤120s, accuracy 0–100m and distance ≤150m from the configured address coordinate. Invalid/missing samples become self-reported. Coordinates are discarded in memory and never passed to Postgres, persisted, broadcast or explicitly logged. Address geocodes are not verified venue entrances, and this heuristic does not resist GPS spoofing. A single GPS sample cannot prove a floor or identity.

Keep request-body logging and tracing payload capture disabled at gateways and Edge infrastructure. Verify that in the actual hosted configuration before collecting location samples. Default function code logs no user data, tokens, emails, Apple codes or coordinates. Supabase Auth has its own security logs and retention: include those in the owner's operational privacy review. Do not enable broad analytics or retain study histories for measurement.

## Apple account deletion

The iOS app uses AuthenticationServices, a cryptographically generated nonce and SHA-256 request nonce, exchanges the ID token using the official Swift SDK and stores sessions in Keychain. No name/email scope is requested. Credential revocation is checked on foreground entry; canceling authentication preserves the report form.

Deletion requests fresh Apple authorization for the same identity. Server-side `apple.ts` exchanges that authorization code, verifies Apple's signed ID token and its subject against the authenticated user's Apple identity, and revokes the returned refresh token through Apple's endpoint. No Apple refresh token is persisted. Configure these **server secrets only**:

- `APPLE_CLIENT_ID`: the native bundle ID accepted by this Apple authorization flow.
- `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY`: the owner's Apple token-revocation signing credentials. The PEM may contain escaped newlines.

The server atomically marks the account deleting first, so all existing sessions immediately lose posting eligibility. If Apple revocation fails, deletion reports failure and the account stays in a retryable, contribution-disabled state. Reauthenticate to retry. After successful revocation, the Auth admin hard-delete cascades private reports, flags, blocks and controls and removes refresh sessions. Already-issued JWTs cannot post: sensitive endpoints check current Auth/session existence, not signature validity alone. The Auth server has narrowly granted permission to update only the public counter during cascades; client roles gain no privileges.

**Actual Apple sign-in and revocation are unverified until owner credentials and a signed device build are configured.** Local tests verify the deletion gate, cascade and old-token rejection with real local Auth sessions, not Apple endpoints.

## Moderation

Set `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` only in an operator shell. Then:

```sh
node scripts/moderate.mjs review
BETWEEN_OPERATOR='your-operator-name' node scripts/moderate.mjs remove REPORT_UUID
BETWEEN_OPERATOR='your-operator-name' node scripts/moderate.mjs suspend REPORT_UUID
BETWEEN_OPERATOR='your-operator-name' node scripts/moderate.mjs restore REPORT_UUID
```

Review output is protected and limited to 100 flagged observations. Targets are resolved server-side from the report reference; there is no client-assigned moderator role or editable metadata authorization. Operations are audited by operator, action, time and opaque reference. Review flags within the report retention window. Structured enums eliminate public free-text/photo abuse, but misleading conditions still require active moderation. Publish a real support route and staff the queue before release.

Hourly purge removes observations older than 24 hours and cascades flags. Audit entries retain no author ID and are purged after 90 days. Blocks persist until account deletion. Auth/user operational retention and backup windows must be reflected in the deployed privacy policy. UF counts and hours are fetched directly by the native client through the separate UFLibraryData adapter; they do not flow through the community database. See UF_DATA.md.
