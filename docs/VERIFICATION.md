# Verification record — October 22, 2026

This records checks actually run on this Mac. Native simulator, localhost backend, real Apple integration, hosted deployment and public release are separate milestones. The last three remain unverified/blocked; this is not a public-release signoff.

## UF data and UI update — subsequent verification

The main `Between` scheme now connects directly to UF's public display counts and date-specific LibCal hours, independently of Supabase. The logo/app icon and Find/detail/saved screens have been updated. Earlier Demo screenshots and results below document the first implementation; the new source evidence supersedes their data-provider limitation.

| Check | Result | Evidence |
| --- | --- | --- |
| UF-connected iPhone 17 Pro / iOS 26.2 | 18 passed: 17 domain/source tests + native real-network UF flow | `evidence/uf-data-test-summary.json` |
| Updated UI, iPhone 16e / iOS 18.5 | 21 passed: 17 domain/source tests + 4 complete Demo UI flows | `evidence/uf-ui-ios18-summary.json` |
| Final-source domain + largest-text native flow, iOS 26.2 | 18 passed: 17 domain/source tests + UF flow at accessibility-extra-extra-extra-large | `evidence/uf-large-text-summary.json` |
| Actual native cached UF values | All six building counts and all six published date-specific schedules present | `evidence/uf-native-data.json` |
| New app icon | 1024×1024 RGB, no alpha, asset compilation succeeded | AppIcon.appiconset |

The source tests use a captured factual public-hours fixture for repeatability and verify continuous Marston opening, West's overnight closing, other library hours, closure, 24h schedule expiry, malformed/by-appointment unknowns, strict display count parsing and absent sensor timestamps. The live native UI test receives actual counts/hours over HTTPS and checks detail provenance; no fixture or fake report is injected into this build. Counts fluctuate, so screenshots are retrieval-time evidence, not promises about current occupancy.

New captures: `15-Official-UF-Find.png`, `16-Official-UF-Details.png`, `17-Official-UF-Dark.png`, `18-Official-UF-LargeText.png`, `19-Official-UF-iPad.png`. The iPad capture was visually inspected with map/list side by side; dark appearance and largest text were also visually inspected. See UF_DATA.md for source URLs, refresh behavior, lack of sensor timestamps and provider-contract limits. No backend schema or authenticated endpoint changed in this update; prior backend checks remain the relevant evidence.

## Environment and native results

Xcode 26.3 (17C529), Apple Swift 6.2.4, iOS SDK 26.2. Deployment target iOS 18. XcodeGen 2.44.1. Official supabase-swift pinned to 2.55.4 with its resolved transitive dependencies committed in the project lockfile.

| Check | Actual result | Evidence |
| --- | --- | --- |
| iPhone 17 Pro, iOS 26.2 | 18/18 passed: 14 domain + 4 UI tests | `evidence/iOS26-test-summary.json` |
| iPhone 16e, iOS 18.5 | 18/18 passed: 14 domain + 4 UI tests | `evidence/iOS18-test-summary.json` |
| Final-source domain rerun, iOS 26.2 | 14/14 passed | `evidence/final-domain-summary.json` |
| Final report-flow repeat, iOS 26.2 | Three consecutive iterations passed | `evidence/repeated-report-summary.json` and `repeated-report-iterations.txt` |
| Between-Live Development simulator build | BUILD SUCCEEDED | Native guest cache/connection evidence saved separately |
| Between-Live Release unsigned arm64 device archive | ARCHIVE SUCCEEDED | `evidence/unsigned-archive.txt` |
| App icon | 1024×1024 opaque RGB PNG; asset compilation succeeded | AppIcon.appiconset and preflight validation |

The full UI suite exercised guest discovery → 45-minute plan → list → details → Demo sign-in/report acceptance; manual origin → MapKit walking directions panel; saving → terminate/relaunch → Saved; and You/no-community-report states. Accepted Demo writes change only the isolated store. Actual Apple authentication is not substituted by the Demo contributor button.

Domain tests cover the 45−6−7−5=27-minute example, negative-time exclusion, closing before arrival and during a plan, unknown hours, date-specific closure, overnight and fall-back DST intervals, hard unknown-amenity/access filters, independent authors, decay/presence weighting, median ties/opposition, missing sound, zone separation, blocks/removal/suspension, expiry without push, official observation time versus fetch time, aliases and out-of-order request tickets. A removed latest observation does not resurrect replaced influence.

After the full suites, small contrast/campus-time/error-display refinements were compiled in the final build. The final domain rerun and repeated report flow cover that application source. One final automation run failed to reach the acceptance assertion; an immediate diagnostic rerun passed with no app changes. The test now explicitly waits for Submit to become enabled after sign-in and passed three consecutive iterations. This test synchronization change is not a claim of physical-device reliability.

Commands run from the workspace containing `outputs/Between` (installed destinations were discovered first):

```sh
xcodebuild test -project outputs/Between/Between.xcodeproj -scheme Between-Demo \
  -configuration Demo -destination 'platform=iOS Simulator,id=C3813301-BAF8-4498-9D46-3899BE45AF60' \
  -derivedDataPath work/DerivedData -clonedSourcePackagesDirPath work/SourcePackages CODE_SIGNING_ALLOWED=NO

xcodebuild test -project outputs/Between/Between.xcodeproj -scheme Between-Demo \
  -configuration Demo -destination 'platform=iOS Simulator,id=DB3E14E6-320D-4081-A750-890FFB6A6A91' \
  -derivedDataPath work/DerivedData -clonedSourcePackagesDirPath work/SourcePackages CODE_SIGNING_ALLOWED=NO

xcodebuild archive -project outputs/Between/Between.xcodeproj -scheme Between-Live \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath work/Between-Unsigned.xcarchive -derivedDataPath work/ArchiveDerivedData \
  -clonedSourcePackagesDirPath work/SourcePackages CODE_SIGNING_ALLOWED=NO
```

The final repeat command used `-only-testing:BetweenUITests/BetweenUITests/testGuestFindPlanDetailsAndReport -test-iterations 3`. Raw result bundles remain in workspace `work/`; exported JSON summaries and actual screenshots are included here. Unsigned archiving proves source/SDK compilation; it does not authorize entitlements, install on a device, validate distribution signing or establish TestFlight readiness.

## Backend results

Docker 28.4.0, Supabase CLI 2.121.0, local Edge Runtime 1.77.4. A clean `supabase db reset --local` successfully recreated the schema and metadata seed; `migration list --local` showed version 20261022164538 applied. No synthetic crowd reports are in the seed.

Nine real localhost integration groups passed, using disposable Auth accounts, two independent SDK clients and Postgres persistence:

1. Guest safe catalog, private-row/RPC protection and denied client catalog mutations.
2. Concurrent duplicated keys across two sessions return one original receipt; forged author/time/proximity fields are ignored. A stale duplicate still returns its original receipt.
3. Two sessions cannot race the per-scope five-minute limit.
4. Invalid places/zones/enums, stale confirmations and oversized streamed bodies are rejected.
5. A server-accepted update produces safe Realtime invalidation and is visible in a second client's aggregate and a fresh HTTP fetch, without exposing author IDs.
6. Flags, personalized blocks, protected moderation and suspended-user rejection affect aggregates correctly.
7. Twenty accepted submissions per hour is enforced atomically against 21 concurrent distinct-scope submissions.
8. Server expiry removes stale influence without deleting hourly anti-abuse history prematurely.
9. Deletion eligibility gate, Auth hard-delete cascades, refresh-token failure and old-access-token rejection.

The final healthy two-client invalidation event measured **258 ms** after subscription readiness (an earlier run measured 67 ms). The second client then fetched the accepted aggregate. These are local network measurements, not a hosted/native Apple contribution latency claim. The test explicitly waits for PostgreSQL's subscription readiness; joining a channel alone is not sufficient to assume replication registration finished.

Separate SQL assertions passed exact median ties, opposition, decay/presence, deduplication, missing sound, building/zone separation, viewer blocks, removal of latest influence and the exact 30-minute boundary. All SQL fixtures rolled back. Four Deno validation tests passed; `deno check` passed for the complete handler. The protected moderation review script successfully read an empty queue. Supabase local security advisors returned **No issues found** after the final schema rebuild. These results do not substitute for a hosted advisor/security review after configuration changes.

The actual native Development app also fetched all six catalog entries with zero observations and no Demo payload. A safe campus counter invalidation (no report rows added) triggered a refreshed on-device cache in **1,463 ms**. See `evidence/native-development-guest.json`, `native-realtime.txt` and screenshot 14. This independently exercises the Swift SDK listener and native HTTP/cache path; it does not verify native Apple contribution authentication.

See `evidence/backend-integration.txt`, `sql-aggregation.txt`, `edge-validation.txt`, `edge-typecheck.txt`, `security-advisors.txt` and `moderation-review.txt`.

## Visual and accessibility checks

Actual captures were inspected for Find, Details, Report, accepted state, Saved, You, no reports, walking directions, dark Find/Details, iPad Find, maximum accessibility text Find/Report and Increase Contrast. iPad Pro 13-inch (M5), iOS 26.2 was used for the split-layout capture. The Demo banner/title overlap found during inspection was corrected; final static captures preserve map attribution and essential actions. Native list scrolling provides access to information below a floating tab bar.

Calculated text contrast on the actual tokens: Ink/Canvas 14.80:1 light and 15.12:1 dark; Metadata/Canvas 5.73:1 and 9.51:1; accent text 5.93:1 and 10.14:1; white on filled actions 6.36:1 in both modes. This verifies those token pairs, not every native material, map label, system placeholder or disabled state.

No completed physical VoiceOver traversal, Reduce Motion/Reduce Transparency device run, real location-denial/approximate-location report trial or user-timed reporting study is claimed. Maximum Dynamic Type captures and native semantic controls are implementation evidence, not a substitute for those checks. Cached launch <1s, typing responsiveness and power use were not measured on physical hardware and remain targets.

## Blocked or unrun release checks

- Hosted project creation failed twice at the connected provider (API-key creation, then organization retrieval). No usable Between hosted project/key was returned; existing projects were not changed.
- Real native Apple sign-in, provider credential revocation, Apple authorization-code exchange/revocation and the complete in-app deletion flow need the owner's Team/App ID/provider/server secrets and signed devices. Local Auth tests used disposable password accounts and do not claim Apple success.
- Native two-Apple-client contribution → shared update → app-relaunch testing on a hosted backend remains blocked. A fresh HTTP fetch demonstrates local server persistence, not an actual native app restart with Apple authentication.
- Public URLs/contact details, final privacy answers/log/backup review, distribution signing, TestFlight, App Store Connect submission and physical-device tests remain owner inputs.
- Catalog usable entrances and general entry eligibility still need field verification. Unknown amenities remain null. The October 29 update below supersedes the earlier occupancy/hours limitation: public UF counts, schedules and room searches are integrated.
- Offline/reconnect, sign-in cancellation, deletion failure and error-recovery implementations need complete real-device/manual validation with the configured release backend.

Release preflight intentionally fails with the missing inputs rather than producing a false readiness claim. See `evidence/release-preflight.txt`, BACKEND.md and RELEASE.md.


## October 29, 2026: live sources, student planning and motion update

The earlier baseline sections are historical. This update integrates the public UF feeds into the normal app, and supersedes the earlier statement that occupancy/date-specific hours were unavailable. The standard Development app was used throughout these checks; no synthetic data was substituted.

**33 tests passed, zero failures, zero skips:** 29 domain/source/transport tests and four native UI scenarios on iPhone 17 Pro, iOS 26.2 (arm64 simulator). The final result bundle was `BetweenVerifiedFinal.xcresult`; a portable summary is in [evidence/student-live-tests-2026-10-29.json](evidence/student-live-tests-2026-10-29.json).

The native scenarios exercised:

1. Choose Library West as an explicit origin → choose Turlington Hall from UF's building directory as the next class → apply the plan → submit an unsuccessful library search → clear it → recover from empty Saved back to Find.
2. Real UF count with fresh retrieval label → map → Education row consistency after schedule refresh → West (open or closed according to actual campus time) → published weekly hours → real selected-time LibCal results, with source and freshness labels.
3. Map/list changes using the same custom reduced-motion path read from the system preference. The debug launch override does not change the device's accessibility setting.
4. Actual accessibility XXXL content-size layout → search → no matches → clear → recovered results. The test asserts that the accessibility-specific layout is active.

Use `scripts/test-live-ios.sh <simulator-UUID>` to reproduce these selected tests. The equivalent Xcode invocation uses `-scheme Between -configuration Development`, `-only-testing:BetweenTests`, and the four test names in that script, with `CODE_SIGNING_ALLOWED=NO`. The source folder was copied out of iCloud Documents to a temporary local build directory because Xcode file coordination stalled on the iCloud-backed checkout. Source and project contents were mirrored before the final run.

A separate production-service HTTPS runner, `scripts/verify-live-data.sh`, completed at **2026-10-29T10:46:55Z**: eleven counts, six complete schedules, and successful room searches for West, Marston, Education and Health Science. Marston returned 22 exact-time spaces for 7:00–7:30 AM campus time; the other three returned valid zero-result responses. These are observed results at that time, not fixed expectations. See [the saved source snapshot](evidence/live-sources-2026-10-29.json). Source fixtures test positive room results, zero results with other-time suggestions, returned-time mismatch, malformed data and the real UF campus-building record.

Final manual visual checks covered settled map tiles and compact map controls, native card-to-detail navigation, the Rooms shortcut showing 22 real spaces and capacities, and light/dark appearance. The new `Live-*` screenshots show actual Development data; older palette/Demo screenshots remain historical. This is visual/functional simulator evidence, not a measured animation frame-rate or physical-device power test.

The [student experience review](STUDENT-UX-REVIEW.md) documents audience hypotheses, the walkthrough findings and shipped fixes. No actual student interview study, physical VoiceOver traversal, physical Reduce Motion test, signed Apple account lifecycle or App Store release certification is claimed. UF supplies no sensor timestamp or guaranteed free-seat count. Reservations are completed only on UF's site.
