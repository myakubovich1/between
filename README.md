# Between

A native SwiftUI iPhone/iPad app for finding somewhere useful to study between commitments. iOS 18 minimum. Includes Find, Saved and You, MapKit walking directions, time budgets, six Gainesville libraries, separate floor reports, structured contributions, local favorites, preferences, offline caching and an isolated Demo store.

**This is a working development build, not a public-release signoff.** A local Supabase backend and automated tests run on this Mac. Hosted project creation failed at the Supabase provider. Real Apple sign-in, Apple revocation, device signing and physical-device checks require owner configuration. Catalog access, date-specific opening schedules and usable entrances still need release curation. No official occupancy feed is connected.

## Run the app

1. Open `Between.xcodeproj` in Xcode 26.3 or newer.
2. Select **Between-Demo** and an available iPhone simulator, then Run. No backend credentials or Apple account are needed for Demo. Synthetic reports, hours and route estimates always carry a Demo label; Demo writes stay isolated.
3. Start with a 45-minute gap, optionally choose a next library, inspect a place, save it, or submit through “Use demo contributor.” You → Demo controls provides no-data, offline and expiry demonstrations.

Shared schemes and the resolved official supabase-swift 2.55.4 dependency are included. Xcode resolves remaining packages automatically. `project.yml` reproduces the project with XcodeGen 2.44.1; no manual target assembly is needed. The display name is configurable in `Config/*.xcconfig`.

## Local shared backend

Install Docker Desktop and Supabase CLI (tested 2.121.0), then from this folder:

```sh
supabase start
supabase functions serve between-api
```

On a fresh installation `start` applies the migration and seed. For a disposable local database reset, `supabase db reset --local` rebuilds it. **Never use the test fixture runner or reset on a production database.**

The function provides public catalog/summaries and authenticated reports, feedback, My Reports and account deletion. Native contributions use Apple sign-in; local integration tests use disposable password Auth users to exercise the same verified-session and server-validation path. See [backend setup](docs/BACKEND.md).

For local backend tests, in a second terminal:

```sh
mkdir -p work
supabase status -o json > work/local-status.json
chmod 600 work/local-status.json
npm ci --prefix supabase/tests
BETWEEN_LOCAL_STATUS="$PWD/work/local-status.json" node supabase/tests/integration.mjs
deno test --config supabase/functions/between-api/deno.json supabase/functions/between-api/validation_test.ts
```

The JSON status file contains local server credentials: keep it out of Git and screenshots. The integration runner refuses non-loopback URLs and deletes its disposable accounts. It creates no synthetic community observations in a hosted project.

## Connect a development or release backend

On this Mac, the ignored `Config/Local.xcconfig` is configured for the running localhost backend and its publishable key; the source ZIP omits machine-specific configuration. For a hosted project, copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig`; add your project's HTTPS URL and publishable key. Choose **Between-Live**. Live failures never substitute Demo data. Configure Apple provider and the native bundle ID in Supabase; enable the Sign in with Apple entitlement for your Developer Team. The live scheme archives with Release settings. See [release setup](docs/RELEASE.md) for Apple token revocation, public URLs, signed-device testing and TestFlight.

## Verify and hand off

- `scripts/test-ios.sh` discovers a simulator and runs domain and native UI tests.
- `python3 scripts/release_preflight.py` fails until actual release inputs and signoffs exist.
- [Verification report](docs/VERIFICATION.md): commands, measured results, screenshots and unrun checks.
- [Asset provenance and dependency notices](docs/ASSETS.md).
- [Design guide](docs/DESIGN.md), [demo script](docs/DEMO.md), [catalog sources](docs/catalog-source-manifest.json), [privacy/data flow](docs/PRIVACY.md), [draft policies](docs/POLICIES_DRAFT.md), [App Store copy](docs/APP_STORE.md).

The app has no ads, calendar access, microphone access, location trail, paid features or LLM recommendations. Address markers are geocoded destinations, not verified entrances. Unknown hours/access/amenities are displayed as unknown; exact route or seat availability is never promised.
