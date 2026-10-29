# Between

A native SwiftUI iPhone/iPad app for finding somewhere useful to study between commitments. iOS 18 minimum. Built for UF students fitting study time between classes. Includes Find, Saved and You, real UF occupancy, opening schedules and reservable-room searches, campus-building destinations, MapKit walking directions, a study-gap countdown, local favorites and offline caching.

The interface uses Canvas, Mist, Cornflower, Pear, and Black, with appearance-aware light and dark themes. See the [palette implementation and verification](docs/PALETTE-UPDATE.md).

<p>
  <img src="docs/screenshots/Live-Find.png" alt="Between in light appearance" width="280" />
  <img src="docs/screenshots/Live-Dark.png" alt="Between in dark appearance" width="280" />
</p>

Screenshots show the normal UF-connected Development app.

**The default app now connects to real UF data:** building counts for six Gainesville libraries, five area counts, date-specific LibCal hours, and room/carrel availability for four libraries. No backend credentials or sign-in are needed for UF browsing. Counts show retrieval age and explicitly disclose that the current display feed supplies no sensor timestamp. See [live data and motion](docs/LIVE-DATA-AND-MOTION.md) and the [student experience review](docs/STUDENT-UX-REVIEW.md).

The optional community backend can run locally. Hosted deployment requires your own backend configuration. Real Apple sign-in/revocation, device signing, physical-device checks and final release curation remain owner setup steps.

## Run the app

1. Open `Between.xcodeproj` in Xcode 26.3 or newer.
2. Select **Between** and an available iPhone simulator, then Run. This fetches actual UF counts, opening schedules and selected-time room availability over HTTPS. It opens a clear library list; use the map button for the campus map.
3. Choose a starting point, set your gap and optional next class/building. Compare options, inspect hours and rooms, save a place, or get walking directions.
4. **Between-Demo** is optional for deterministic presentation and report tests; it alone uses synthetic reports/hours and always displays a Demo label.

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

Copy `Config/Local.xcconfig.example` to the ignored `Config/Local.xcconfig`; add your project's HTTPS URL and publishable key. Machine-specific configuration and credentials are excluded from this repository. Choose **Between** (or the equivalent **Between-Live**). Live failures never substitute Demo data. Configure Apple provider and the native bundle ID in Supabase; enable the Sign in with Apple entitlement for your Developer Team. The live scheme archives with Release settings. See [release setup](docs/RELEASE.md) for Apple token revocation, public URLs, signed-device testing and TestFlight.

## Verify and hand off

- `scripts/test-live-ios.sh` runs domain/source tests and four native UF-connected flows, including accessibility-size search recovery.
- `scripts/test-ios.sh` runs the isolated Demo regression suite.
- `scripts/verify-live-data.sh` checks eleven actual UF counts, six schedules and four room-search locations over HTTPS.
- `python3 scripts/release_preflight.py` fails until actual release inputs and signoffs exist.
- [Verification report](docs/VERIFICATION.md): commands, measured results, screenshots and unrun checks.
- [UF data connection](docs/UF_DATA.md) and [new brand artwork](docs/brand/Between-logo.png).
- [Asset provenance and dependency notices](docs/ASSETS.md).
- [Design guide](docs/DESIGN.md), [demo script](docs/DEMO.md), [catalog sources](docs/catalog-source-manifest.json), [privacy/data flow](docs/PRIVACY.md), [draft policies](docs/POLICIES_DRAFT.md), [App Store copy](docs/APP_STORE.md).

The app has no ads, calendar access, microphone access, location trail, paid features or LLM recommendations. Address markers are geocoded destinations, not verified entrances. Unrecognized or expired hours, unknown access and unknown amenities stay unknown; exact route or seat availability is never promised.
