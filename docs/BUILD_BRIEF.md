# Between — native iOS capstone research and Codex build brief

Prepared for Matsvei Yakubovich's Product Space capstone. Research checked October 22, 2026.

**Working name:** Between. Name and App Store availability have not been checked; keep the display name easy to change.

## How to use this file

Give this entire file to Codex in a dedicated project folder on your Mac, and paste:

> Implement the master build prompt in `Between_Native_iOS_Codex_Brief.md`. Read the research context first, then build the actual native SwiftUI app and its shared backend. Work through the milestones and verification criteria. Start by inspecting the repository and available Xcode tools, then implement; do not stop at a plan or a visual prototype. Report clearly which checks actually ran and which release steps need my credentials.

The master prompt starts after the research notes below. The app should be tested on a Mac with Xcode and an iPhone before submission. Source code, a successful simulator run, a live backend test, and App Store approval are separate milestones.

## Research scope and evidence

This review uses official product websites, current developer-published App Store descriptions, university pages, and Apple developer documentation. It is a comparison of published capabilities and documented interaction patterns, not a hands-on audit of the installed competitors. Advertised accuracy, privacy, and live-data claims are not independently verified. Small App Store rating samples are not evidence of reliability or market demand. The design recommendations below are our synthesis, not claims that competitors lack every proposed feature.

### Direct competitors

| Product | What its primary sources establish | Pattern worth adopting | Implication for this capstone |
| --- | --- | --- | --- |
| **Waitz University / Occuspace** | Waitz displays campus busyness. Occuspace documents live occupancy counts, capacities, percentages, and textual crowd levels, with data available through customer products and APIs. | Communicate the current crowd condition early, with a clear location hierarchy. | A useful reference for occupancy communication. Its measured-data infrastructure is different from a student reporting system; building the interface does not create access to its sensors or customer API. |
| **Affluences** | Its app advertises attendance estimates and predictions at partner venues. Its official website also supports booking; a university deployment describes comparing library occupancy and reserving study seats or rooms. | Make availability, opening information, and the next action easy to understand together. | Separate finding somewhere to sit from reserving a particular room. Use UF's existing booking service for reservations until there is an authorized integration. |
| **SeatChk** | Its listing describes a campus map, crowd updates, historical charts, on-site crowd reports, a proximity check, and contribution rewards. | A short reporting flow connected to the selected place. | A very close functional comparator. Treat proximity as a limited signal: GPS cannot prove an exact seat or floor, and anti-spam controls still need to run on the server. |
| **LockIn – Study Spots** | Its listing describes maps of study-friendly venues, user noise/crowd reports, Wi-Fi and outlet information, favorites, and focus tracking. Some discovery and trend features are part of a subscription. | Use study-specific attributes instead of generic restaurant ratings. | Another close comparator. A polished map plus amenity filters alone would reproduce an existing category. Our recommended focus is the usable time remaining between commitments. |
| **Muggerino: Study Spot Finder** | Its current listing combines nearby study locations, crowd reports, amenities and favorites with timers, pets, and social study features. | Put the location's practical study conditions within quick reach. | Discovery can be valuable without adding a large engagement system. For this capstone, prioritize finding a suitable seat and contributing a useful update. |

### Adjacent references

| Product | Documented behavior | What to translate into Between |
| --- | --- | --- |
| **LaptopFriendly** | Curated work venues emphasize Wi-Fi, power, seating, atmosphere, and community information. | Separate fairly stable venue amenities from short-lived crowd reports. Unknown amenities should remain unknown. |
| **Google Maps** | Google's help pages distinguish typical popular times from current live visit information, and explain that such information requires sufficient underlying data. | Visually distinguish current reports, historical patterns, and missing information. A typical Tuesday pattern must never masquerade as an observation from now. |
| **Waze** | Its documented flow uses a prominent report action, a short category selection, feedback on obsolete reports, and reporting limits. | Make a report quick, expire old observations, and provide a way to challenge bad information. Because study conditions are short-lived, an offline draft must be reconfirmed rather than sent much later as fresh. |
| **Apple Maps / Apple's native design guidance** | MapKit supports interactive maps, annotations and route information; Apple's design guidance covers map controls, sheets, navigation and system materials. | Use the native map-and-place-detail mental model, with coherent sheets, readable controls and familiar navigation. This is the primary interface foundation. |

### The opportunity for the capstone

The screenshots define two things: a study-space finder with crowd reports and preference-based recommendations, and the theme of designing for overlooked transitional moments. A strong product framing joins them:

**“I have 45 minutes before my next class. Where can I actually sit down and get useful work done?”**

Recommended differentiation is **time-aware campus discovery with visible evidence freshness**. This is a product hypothesis to validate with students, not an established competitive moat.

The core loop is: enter the time available → see a few suitable places → inspect conditions and evidence → walk there → contribute a quick update. The measure of success is a useful study session, not time spent exploring the app.

### UF-specific findings that change the implementation

- **UF already publishes an occupancy page** for several library locations. Its existence is verified; an authorized integration, machine-readable feed contract, observation timestamps, refresh reliability, and reuse terms have not been verified. Do not promise this feed as a completed integration.
- **Building occupancy is not seat availability.** A people count or building capacity cannot establish how many desks, outlets, or adjacent seats are free.
- **Zones matter.** UF identifies Marston floors 1–3 as collaborative and floors 4–5 as quiet/silent study areas. Library West identifies its fourth floor as a quiet study space. These are venue policies, not observations of today's actual noise.
- **Access matters.** UF's study-space page identifies Library West's sixth floor as graduate-only. It should not be suggested as an unrestricted undergraduate option.
- **Hours need exceptions.** Newell's official hours page lists break/holiday and home-football-day closures, and an after-hours GATORONE access note. A static “open every day” label would be misleading.
- **Reservations already have a workflow.** UF links to LibCal for study-room booking. Open an accurate official link; never show a booking confirmation or bookable inventory without an actual integration.

### Primary sources

Product and interaction references:

1. [Waitz University, App Store](https://apps.apple.com/us/app/waitz-university/id1346827447)
2. [Occuspace: using live data](https://docs.occuspace.io/guides/using-live-data)
3. [Affluences, App Store](https://apps.apple.com/us/app/affluences/id869919405)
4. [Affluences official site](https://affluences.com/en/)
5. [University of Padua: Affluences deployment](https://biblio.unipd.it/en/app-affluences/app-affluences)
6. [SeatChk, App Store](https://apps.apple.com/us/app/seatchk/id6759760542)
7. [LockIn – Study Spots, App Store](https://apps.apple.com/us/app/lockin-study-spots/id6778997194)
8. [Muggerino, App Store](https://apps.apple.com/us/app/muggerino-study-spot-finder/id6747711259)
9. [LaptopFriendly](https://laptopfriendly.co/)
10. [Google: popular times and live visit data](https://support.google.com/business/answer/6263531?hl=en)
11. [Waze: report traffic](https://support.google.com/waze/answer/13740207?hl=en)

UF references:

12. [UF library occupancy](https://www.uflib.ufl.edu/status/)
13. [UF study and testing spaces](https://uflib.ufl.edu/using-the-libraries/studyareas/)
14. [Marston study spaces](https://marston.uflib.ufl.edu/spaces/study-spaces/)
15. [Library West quiet floor](https://librarywest.uflib.ufl.edu/spaces/quiet-study-floor/)
16. [Newell Hall hours](https://newell.ufsa.ufl.edu/hours/)
17. [Reitz Union hours](https://union.ufl.edu/hours/)

Native implementation and distribution references:

18. [Apple Human Interface Guidelines: maps](https://developer.apple.com/design/human-interface-guidelines/maps)
19. [Apple Human Interface Guidelines: materials](https://developer.apple.com/design/human-interface-guidelines/materials)
20. [Apple: adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass)
21. [MapKit for SwiftUI](https://developer.apple.com/documentation/mapkit/mapkit-for-swiftui)
22. [MKDirections](https://developer.apple.com/documentation/mapkit/mkdirections)
23. [Apple: location authorization](https://developer.apple.com/documentation/corelocation/cllocationmanager/requestwheninuseauthorization())
24. [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
25. [Apple: offering account deletion](https://developer.apple.com/support/offering-account-deletion-in-your-app/)
26. [Apple: privacy manifests](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)
27. [Apple: upcoming submission requirements](https://developer.apple.com/news/upcoming-requirements/)
28. [Apple Developer Program](https://developer.apple.com/programs/)
29. [Supabase: native Sign in with Apple](https://supabase.com/docs/guides/auth/social-login/auth-apple)
30. [Supabase Swift: sign in with ID token](https://supabase.com/docs/reference/swift/auth-signinwithidtoken)

---

# MASTER BUILD PROMPT — BEGIN

You are the senior native iOS engineer and product designer implementing my Product Space capstone. Build **Between**, a polished native study-space discovery app, with an initial University of Florida campus launch. The name is provisional and must be configurable.

This is an implementation task. Produce a maintainable Xcode project, working shared backend implementation, realistic catalog, documented setup, and verification evidence. Do not stop at a plan, mockup, single-screen demo, or locally simulated social feature. Make reasonable reversible decisions, record assumptions, and continue until the implementation is complete or a specific external dependency blocks a step.

## 1. Product contract

The product helps a student use the time between classes or other commitments:

> I have a limited amount of time. Help me find a nearby place where I can sit, focus, and still reach my next destination.

The original concept requires finding study spots, indicating current busyness, matching preferences and distance, and allowing students to report conditions. The architecture should accommodate cafés later, while the first release concentrates on a useful, curated UF campus catalog.

The essential loop must work end to end:

1. Browse without an account or location permission.
2. Optionally set current/manual origin, time available, next destination, and study preferences.
3. Compare suitable spots using walk time, hours/access, seat reports, noise, amenities, and evidence freshness.
4. Open a place, select a verified floor/zone if appropriate, and get walking directions.
5. Submit a short observation; another user sees the shared update.
6. Save spots and preferences across app launches.

Use the research earlier in this file as context. Combine familiar map discovery, practical venue attributes, and quick reporting into an original product. Keep our own branding, wording, assets, and layout details. The time-budget workflow and evidence treatment must be central, visible product behavior.

## 2. Native platform and implementation choices

- Build an actual **SwiftUI iOS app**, using MapKit and Core Location. A web app, PWA, React Native app, Flutter app, or embedded website does not satisfy this brief.
- Default minimum deployment target: **iOS 18**, with native behavior on supported newer versions. Use the installed stable Xcode/Swift toolchain and verify Apple's submission requirements before preparing a release. As checked October 22, 2026, Apple requires Xcode 26 or later and the iOS 26 SDK or later for uploads; this is distinct from our minimum supported OS.
- iPhone is the primary experience. Support small and large iPhones; make the same app adapt sensibly to iPad using a split layout where practical. Do not add Mac, Watch, or Vision targets in this release.
- Use Swift concurrency, Observation where appropriate, dependency injection, and a small feature-based structure. UI state belongs on the appropriate actor. Cancel obsolete searches and requests.
- Use SwiftData for a small local catalog/status cache and saved spots if practical. Keep account tokens in Keychain, never UserDefaults. Avoid unnecessary frameworks and architectural layers.
- Use the official **supabase-swift** package via Swift Package Manager for shared services. Pin and commit resolved dependencies. Use Supabase Postgres/Auth and a small server layer for validated submissions, aggregate reads, moderation, and deletion. Backend code may use the platform's supported server runtime; all app screens remain native SwiftUI.
- Use native Sign in with Apple for contributions. Guest browsing and local favorites must stay available without sign-in. Do not assume Apple sign-in proves someone is a UF student. Do not implement UF SSO without a real integration.
- Inspect the repository, AGENTS.md instructions, current packages, Xcode version and available simulators first. Preserve unrelated work. Use an existing valid project when present; otherwise create a complete project with committed shared schemes. An undocumented instruction to manually assemble the project is insufficient.
- If the environment has no Xcode, implement everything possible and report the native build as unverified. Do not claim that a SwiftUI app has compiled based only on static inspection or a Linux Swift test.

## 3. Scope and priorities

Ship a narrow, complete release: discovery, time budget, filters, place/zone details, shared reports, saved spots, preferences, account management, moderation controls and graceful offline behavior.

Keep subscriptions, ads, chat, friends, leaderboards, pets, focus timers, calendar integration, continuous tracking, indoor navigation, predictive ML and room-booking ownership outside this release. Do not present nonfunctional controls for these features. Provide a real official reservation link where it is useful.

No LLM is needed for recommendations. Use a deterministic, inspectable ranking function. A short explanation such as “6-minute walk · designated quiet floor · 3 recent seat reports” is more useful here than a chatbot.

## 4. Design system and information architecture

The interface should feel calm, precise, and native. Apple Maps is the principal interaction reference. Take inspiration from Waitz for understandable crowd status, LaptopFriendly/LockIn for study attributes, and Waze for quick contribution. Translate the patterns into the design below rather than making a generic app dashboard.

Use three stable native tabs: **Find**, **Saved**, **You**. Give each tab its own navigation state. Reporting is an action associated with a place, not a fourth destination tab.

Design tokens:

- SF system type, Dynamic Type, SF Symbols for in-app controls, a restrained hierarchy of large titles, headlines, body and metadata.
- Warm neutral content backgrounds and a forest-green accent; starting light-mode palette: background `#F7F7F4`, primary text `#1B2422`, accent `#1C6B5A`. Provide separately verified dark-mode tokens. Adjust these values when contrast testing requires it.
- Use system semantic surfaces and separators. Use modern native materials for navigation and floating controls; keep information-heavy cards readable and mostly opaque. Let supported system controls adopt current platform styling, including Liquid Glass where available. Provide iOS 18 fallbacks and respect Reduce Transparency.
- Approximate spacing scale: 4, 8, 12, 16, 24, 32 points; 16–20-point content margins. Use purposeful rounded cards, not a card around every line.
- Minimum 44×44-point interactive targets. A small visual icon can have a larger hit area.
- All seat/crowd states require words and/or symbols as well as color. Gray means unknown, not available. Seat availability and noise are different measurements.
- Motion should explain a selection, transition or successful action. Keep it subtle and respect Reduce Motion. Use restrained success haptics.
- Use original or appropriately licensed assets. No competitor screenshots as app content, no copied logos, and no unlicensed campus photos. The interface must still look finished without venue photography.

Build reusable place cards, status labels, freshness/evidence labels, amenity rows, filter chips, skeletons, empty states and retry states. Component previews should include long names, missing fields, stale observations and accessibility text sizes.

## 5. Screen specifications and interactions

### A. First launch

Reach the usable Find screen immediately. At most one short introduction, with a clear way to continue. Default to a visibly selected UF campus area; do not imply we know the user's precise position.

Do not trigger sign-in or permission dialogs on launch. Offer “Use my location” and manual origin selection in context. Explain that crowd information comes from recent reports and any separately identified authorized source.

### B. Find

Use a MapKit campus map, native search control, a compact time-budget control, and a resizable results panel. The results panel must not cover essential map controls, map attribution, or the bottom tabs. Use a supported system presentation or a carefully implemented in-view panel; verify gestures and safe areas. Avoid nested/stacked sheets.

Search supports curated place names, aliases such as MSL and Lib West, and configured campus destinations. Debounce input and retain the query and scroll position when returning from a place.

Expose a short row of useful filters: **Open now**, **Quiet**, **Outlets**, **Under 10 min**, and **More**. The full filter screen supports study mode (solo/group), noise preference, verified amenities, access eligibility and maximum walk time. Show active filters, result count, Reset, and Apply. Do not hide an important requirement in a profile screen.

Allow list-first use and a list-only accessible alternative. Map and list share selection and filters. Selecting a card highlights the correct marker; tapping a marker reveals the same place. If several floors share a building coordinate, use a single building marker and reveal its zones instead of overlapping identical pins. Panning the map must not recenter it without an explicit action. Use an explicit “Search this area” control if spatial re-querying is implemented.

Recommended card order:

1. Place and selected floor/zone, if any.
2. Walking time, or explicitly marked approximate distance/estimate.
3. Seat report summary or “No recent reports.”
4. Hours and access status, including closing soon.
5. Two or three relevant study attributes.
6. Report age/count and one short reason the place fits.

Keep a save control on the card without making the full card a nest of conflicting tap targets. Preserve useful content during a refresh; show an unobtrusive update indicator instead of replacing everything with a spinner.

### C. Time-budget workflow

Provide quick choices of 30, 45, 60 and 90 minutes plus a custom duration. A next destination is optional and can be selected from campus destinations. Use the user's selected origin and time horizon; do not silently read a calendar.

Compute a plan using the actual walk to the spot, optional onward walk, a configurable buffer initially 5 minutes, and verified opening intervals. Default minimum useful study time is 15 minutes. Show the components clearly. If the next destination is omitted, explain the available time without claiming the user will reach an unspecified class.

Example with synthetic route values: 45 minutes available, 6 minutes to the spot, 7 minutes onward, and a 5-minute buffer leaves 27 minutes to study, assuming the spot remains open. These numbers are demonstration inputs, not actual UF route times.

### D. Place details

Show name, category, verified access constraints, hours, seat-report condition, current noise reports, stable amenities, source/freshness, floor/zone choices and a small map. Put the main action **Directions** and secondary action **Report conditions** within easy reach. Include Save and an official reservation link where applicable.

The evidence panel explains whether a condition is a student report, official occupancy, or venue policy. Show observation age and independent recent reporter count. A designated quiet floor must not automatically display “Quiet right now.” Do not fabricate Wi-Fi speed, outlet counts, accessible routes, or available seats.

For zones, distinguish building-wide measurements from zone-level observations. A building occupancy count may appear in a separate labeled section; it must never be copied to every floor.

### E. Report conditions

From a selected place, open one short native sheet. Ask the user to confirm the floor/zone if applicable. Require only a seat condition:

- Plenty of seats
- Some seats
- Almost full
- Full

Optionally report sound level: **Silent**, **Low conversation**, **Lively**, or skip. Do not convert sound labels into decibels without an actual measurement system. Include an optional outlet observation only if it remains quick and clearly distinct from stable outlet presence.

Show Submit and Cancel. After the first sign-in, target a typical report in under 10 seconds; validate that target with users. If guest sign-in is needed, preserve their choices through authentication. Cancellation must return them to their place.

Use a contextual foreground location request only to support a “nearby report” signal. If permission is denied, location is approximate, or accuracy is inadequate, allow an explicitly self-reported observation with lower weight. GPS is a weak proximity signal, not proof of floor, identity, or honesty. Do not label it “verified accurate.”

Show success only after the server accepts the report. Disable duplicate taps. Rate-limit errors must state when the user can try again. A failed submission must preserve the form. Offline drafts require explicit reconfirmation after connectivity returns; never silently upload an old observation as current.

### F. Saved and You

Saved displays the same useful, current place information and persists across launches. Guest saves are local; account synchronization is not required for this release.

You includes preferences, local data controls, optional Sign in with Apple, My Reports, a plain-language data explanation, support, privacy/terms links, Sign Out and in-app account deletion. Guest and signed-in states must both feel complete. Do not add public profiles or publish a person's study history.

### G. Required state handling

Design and implement: loading, refreshing, zero results, denied/restricted/approximate location, failed directions, offline with cache, offline without a prior cache, unavailable backend, no reports, stale reports, conflicting reports, missing hours, restricted entry, closed place, sign-in canceled/expired, rejected report, duplicate submission, and deletion failure.

Give each state a useful next action. For example, offer to relax a named filter, choose a manual origin, open official hours, retry, or browse saved places. Never substitute fabricated information to make a screen look populated.

## 6. Recommendation and route logic

Keep recommendation logic in a testable service independent of SwiftUI. Inject a clock and route provider.

For a plan starting at `now`, let arrival be `now + walkToSpot`. The latest usable finish is the earlier of the spot's known closing time and `deadline - onwardWalk - buffer`. Study time is that finish minus arrival. If there is no onward destination, onwardWalk is zero and the UI must say this plan excludes travel to the next commitment. Clamp negative durations to zero.

Exclude places that are known closed at arrival, inaccessible to the selected eligibility, outside a hard walk limit, unsuitable for the remaining study time, or contrary to an explicit hard requirement. Do not silently relax a requirement. Unknown access/hours must not be presented as confirmed eligibility; offer uncertain options separately when useful.

For suitable candidates, rank using normalized, bounded factors: preference fit 30%, usable study time 25%, recent seat evidence 20%, journey convenience 15%, evidence freshness 10%. These are initial product heuristics, not learned or validated coefficients. Keep them configurable. Avoid double-counting a building and its zones as separate winning destinations.

Missing values are not positive evidence. A hard “must have outlets” filter excludes unknown outlet availability; a soft preference can retain it with a missing-information label. Do not use “full” reports to guarantee a group can or cannot sit together. Known group-study suitability does not establish adjacent seat availability.

Use MapKit walking directions/ETA for actual route times. Calculate routes for a small shortlist, cache them briefly by origin/destination, limit concurrency, and handle throttling. Avoid route requests for every place on every map drag. Re-rank after valid ETAs arrive without repeatedly moving a selected result.

If only straight-line distance or a walking-speed heuristic is available, label it as an estimate. A drawn straight line is not a walking route. Open Apple Maps with the correct destination and walking mode; internal MapKit discovery should still work without depending on a separate app being installed.

Respect `America/New_York` for UF hours, including overnight intervals, exceptions and daylight-saving transitions. Prefer date-specific opening intervals over assumptions about weekly schedules. Treat unverified or expired schedules as unknown and link to official hours.

## 7. Honest crowd data and aggregation

Implement separate provenance-aware types for:

1. Community seat/noise observations.
2. Official occupancy measurements, if an authorized provider is configured.
3. Stable catalog policies and amenities.
4. Explicitly synthetic demo fixtures.

Community seat reports are ordinal observations, not a measurement of occupancy percentage. Never derive “72% full,” “18 seats left,” or a forecast from a few category reports. The app can say “Some seats · 3 recent reports · latest 4m ago.” With one reporter, say “One student reported some seats · 4m ago.” With none, say “No recent reports.”

Initial server-side community aggregation specification:

- Use server-authoritative acceptance time; clients cannot choose freshness, author identity, or trust weight. Decline delayed automatic retries of old observations unless the user reconfirms.
- Each contributor has at most one effective report per place/zone in the rolling window; their latest accepted report replaces their previous influence for that scope.
- Discard observations at age 30 minutes or older. For younger observations, use exponential age decay with a 10-minute half-life: `weight = presenceWeight * 2^(-ageMinutes / 10)`.
- Use presenceWeight 1.0 when the server's limited nearby check succeeds and 0.5 for self-reported proximity. These are transparent heuristics, not calibrated confidence probabilities.
- Compute a weighted median of the ordinal seat category. Define deterministic tie behavior. If the weighted distribution contains materially opposed reports, show “Reports differ” instead of a false decisive condition. Initially define opposition as at least 30% of weight in categories 0–1 and at least 30% in categories 2–3, with at least two independent contributors; keep this rule configurable and test it.
- Aggregate noise separately, excluding skipped answers. Do not fill missing noise from seat categories.
- Return unique reporter count, newest observation time, evaluation time, expiration boundary and a concise evidence label. Do not invent numerical accuracy or “95% confidence.”
- Resolve expiry when reading aggregates and in the client UI as time passes. A stale summary cannot stay fresh because no new row was inserted. Recompute at least at the next expiration boundary and on foreground/reconnect. Inject time for tests.
- Exclude suspended contributors and respect viewer blocks in personalized community aggregates. Public summaries must not expose user IDs or cross-place histories.

Optional official provider behavior:

- Verify access, usage permission, source scope, freshness and a supported machine-readable contract before enabling an integration. The UF page's public existence alone is not an API contract.
- Implement a provider interface and an unavailable-provider state. Without an authorized feed, the community app still works.
- Preserve source observation time separately from retrieval time. Fetching the same old value again must not make it newly observed. If observation time is unavailable, say so and do not badge it as live.
- A default 5-minute freshness limit can be used only as an explicit configurable provider assumption. Clearly show stale/unavailable states.
- Only display a numeric count/percentage that the provider actually supplies with suitable context. Never convert building capacity minus occupants into available study seats.
- Keep official occupancy and community seat evidence separate even when both are available. Do not average incompatible metrics or scopes.

## 8. Shared backend, security and privacy

Provide versioned schema migrations, seed tooling, a local development configuration, endpoint contracts and automated backend checks. A local array changing on the reporting device is not shared functionality.

Suggested data responsibilities; simplify names if needed without weakening the behavior:

- Public curated catalog: campuses, places, optional zones, amenities/policies, opening intervals/exceptions, access restrictions, source metadata.
- Private contribution records: report ID, actual authenticated author, place/zone, enum values, server timestamps, proximity category and moderation state.
- Server-controlled status/invalidation records: safe current summaries or versions for efficient refresh.
- Private user data: contribution controls, moderation flags and blocks.
- Server-only anti-abuse state and narrowly scoped moderation authorization.

Raw location coordinates must not be persisted in reports, analytics, logs or public data. If a user chooses a nearby check, transmit a recent foreground location sample over TLS to a server endpoint, evaluate against the place footprint/radius, and immediately discard the raw coordinates. Configure infrastructure logging accordingly. Retain only the resulting proximity category, not a location trail. Initial nearby-check heuristic: sample age at most 120 seconds, horizontal accuracy at most 100 meters, and distance within a configured venue radius initially 150 meters. Reject invalid samples; fall back to self-reported status rather than blocking browsing. Do not claim this resists GPS spoofing.

Backend requirements:

- Validate bearer tokens and derive author identity on the server. Ignore client-supplied author IDs, moderation states, scores and timestamps.
- Enforce accepted enums, valid active places/zones, body size limits and idempotency keys. A zone must belong to its specified place.
- Initial limits: one new accepted observation per contributor per scope per 5 minutes and at most 20 accepted submissions per hour across scopes. Enforce atomically on the server. A duplicated idempotency key returns the original result and does not refresh its observation time. Concurrency tests must cover simultaneous submissions from the same user on different sessions.
- Enable RLS on exposed tables and grant only necessary privileges. Public clients read safe catalog/summary data. Private reports and moderation data must not be broadly readable. Own-data access must enforce ownership, not merely an authenticated role.
- Never place Supabase service-role/secret keys, Apple private keys or server credentials in the iOS bundle. A publishable client key is expected to be visible and must be protected by server permissions. Native secrets cannot be kept secret by hiding them in source configuration.
- Prefer invoker-safe database operations. If privileged server functions are necessary, use explicit grants, a fixed search path, narrow ownership and input validation. Do not enable an unrestricted privileged RPC to work around RLS.
- Do not derive privileges from user-editable profile metadata. Review view access so that aggregate views cannot accidentally expose raw report rows.
- Use a safe campus-scoped Realtime subscription to summaries or invalidation versions, followed by an authorized aggregate fetch. Do not broadcast private report payloads. Reconnect safely and remove obsolete subscriptions. Fall back to a bounded foreground refresh, initially every 60 seconds, if realtime is unavailable.
- Implement server persistence and two-client integration tests. Target shared updates visible within 15 seconds on a healthy realtime connection; report measured behavior instead of claiming the target is automatically achieved.
- Time-dependent status must expire even while realtime is disconnected. Preserve the last known content but mark it old. An accepted report may update optimistically only as explicitly pending; reconcile with the server.

Implement native Sign in with Apple using current official guidance, a nonce and verified token exchange. Keep the signed-in session secure; handle canceled sign-in, first-use credential fields being absent on subsequent sign-ins, revoked credentials and sign-out. Request only identity fields actually needed; public display names are not required.

Account deletion must be initiated inside the app. Implement real server deletion of the user's associated contributions and private records, refresh-session revocation and applicable Apple token revocation, followed by local session/cache cleanup. Existing bearer tokens must not be able to continue creating reports after deletion; check current account eligibility on sensitive endpoints. A button that only signs out does not satisfy deletion. Document any genuinely required retention and its reason. Avoid retaining study histories for analytics.

Keep reports structured; no public free-text posts or photo uploads in this release. Provide an evidence-panel action to flag inaccurate/abusive contributions, a way to mute/block a contributor without exposing their identity or study history, and a support route. Resolve block targets server-side from opaque report references; do not publish raw author IDs. Supply a protected moderation script/tool to review flags, remove contributions and suspend abusers, with auditability. The ordinary user must never be able to grant themselves moderation rights. Explain the moderation operation in the handoff and assess the current applicable App Review UGC requirements.

No continuous location tracking, background location permission, microphone access, contacts, calendar access or advertising identifiers. Any analytics must be minimal, documented and free of precise location and personal study history. Default to local debug diagnostics until production measurement is deliberately configured.

## 9. Catalog, cold start and development modes

Create an initial catalog around the six Gainesville libraries appearing on UF's occupancy page: Library West, Marston Science Library, Health Science Center Library, Architecture and Fine Arts Library, Education Library and Smathers Library. Add Newell Hall and Reitz Union as appropriate after validating their study use, access and location. Do not accidentally include UF's Jacksonville library as a nearby Gainesville result.

For every release catalog entry, record the official source URL and verification date for known location, hours, access and policy information. Use unknown/null when a fact cannot be verified. Verify coordinates, usable entrances and aliases instead of inventing plausible values. Keep the launch catalog small enough to curate. Do not copy website text, floorplan artwork or photographs wholesale.

Represent verified zones for Marston and Library West when supported by sources. Do not recommend graduate-only spaces to an undergraduate by default. Treat Newell hours exceptions and GATORONE entry restrictions as first-class data. Include cafés in the data model, but do not pad the launch catalog with unverified venues.

Cold start must be useful and honest: students can discover locations, policies and hours when there are zero crowd reports. The UI invites a contribution rather than making empty data look like a quiet building. A short presentation pilot can recruit a small group of consenting students to report actual conditions; no fake community activity.

Provide separate configurations:

- **Demo:** deterministic synthetic reports, routes where needed, and controllable time. Keep a persistent visible “Demo data” label. Demo submissions only change the isolated demo store.
- **Development/live:** real authenticated backend reads/writes using development resources.
- **Release:** correct production configuration, no silently substituted demo values, and no demo traffic mixed into real community reports.

If credentials are unavailable, Demo must still run for presentation, while live readiness is explicitly documented as blocked. Never silently fall back to demo after a live request fails. Do not auto-reset a real user's data to make demonstrations reproducible.

## 10. Reliability and accessibility

Use async loading, cancellation, pagination/bounded requests, sensible retry/backoff, and real offline caching. Avoid main-thread network/JSON work, excessive map updates, unnecessary GPS use and unbounded listeners. Stop location collection when its immediate task ends.

Use a structured logger without tokens, email addresses or raw coordinates. Handle cache/schema failures with a recoverable state; do not crash with `fatalError` for ordinary runtime failures. Preserve local favorites through normal migrations.

VoiceOver users must be able to discover places, understand seat conditions and freshness, filter, get directions and submit a report through the list interface. Provide meaningful combined labels and logical focus movement after sheets and errors. Support accessibility text sizes without truncating essential conditions or making the submit button unreachable. Validate light/dark modes, Increase Contrast, Reduce Transparency and Reduce Motion. Use locale-aware dates, relative times and distance formatting.

Measure practical performance on the available devices. Initial targets: useful cached content within 1 second after launch, a responsive map/list, and no noticeable typing lag. These are targets to measure and report, not claims to write into the README without evidence.

## 11. Verification and acceptance criteria

Use Swift Testing or XCTest for meaningful domain behavior, XCTest UI tests for key native flows, and appropriate database/server integration tests. Inject time, location, backend and route dependencies. Avoid tests that merely restate view implementation details.

Required domain cases:

- The 45-minute synthetic plan with walks of 6 and 7 minutes and a 5-minute buffer yields 27 study minutes; negative time is excluded.
- Known closure before arrival, closing during a plan, unknown hours, overnight hours, holiday overrides and a daylight-saving boundary are handled correctly.
- Hard requirements exclude unknown or incompatible amenities/access; soft preferences display missing evidence instead of inventing it.
- A community report expires at 30 minutes even without a server push; one author cannot increase independent reporter count by repeatedly reporting.
- Weighted decay, exact median ties, opposing reports, missing noise, building/zone separation and viewer blocks produce deterministic results.
- Official observations preserve their source time, stale source values do not become fresh on fetch, and unavailable official data does not overwrite community data with zero.
- An out-of-order response does not replace a newer query/result set.

Required backend cases:

- Unauthenticated clients can browse only the safe public data; authenticated users cannot read another user's private records, forge authorship or modify catalog/summary/moderation fields.
- Simultaneous duplicate submissions are idempotent, and concurrent rate limits cannot be bypassed by separate sessions.
- Unknown places, mismatched zones, invalid enums and suspended/deleted users are rejected.
- Two independent clients demonstrate a server-accepted report propagating; restarting the submitting app does not erase the shared update.
- Blocking and moderation removal affect the appropriate aggregate without revealing the contributor's identity.
- Account deletion removes the account-associated data and prevents a previously issued token from posting again.

Required UI/manual flows:

- First launch → manual UF origin → choose 45 minutes/quiet preference → open an eligible place → open walking directions.
- Report after sign-in → accepted state → update visible in a separate client.
- Deny location → browse and use manual origin → submit clearly self-reported conditions if signed in.
- Save a place → terminate/relaunch → saved place remains.
- Lose connectivity → cached content is marked old → reconnect → data refreshes; old report drafts require reconfirmation.
- Sign-in cancellation, report rejection, failed account deletion and failed routing are recoverable.
- Small/large iPhone layouts, light/dark modes, large text and VoiceOver; iPad layout if shipped as an iPad-compatible target.

Run and record an actual simulator build and meaningful tests on available destinations. Inspect rendered screenshots of Find, Details, Report, Saved, You and important empty/error states. Fix overlaps, clipped text, map attribution obstruction and inaccessible controls. If a Mac is available, also prepare an unsigned device/archive validation where feasible; actual distribution signing depends on my Apple account.

Never mark a check passed unless you ran it. Clearly distinguish mocked service tests, local backend tests, live multi-client tests, simulator testing and physical-device testing.

## 12. App Store and handoff deliverables

Prepare the code for a real submission, without claiming approval is guaranteed. Recheck current Apple requirements at release time.

Deliver:

1. A complete native project with shared schemes, assets, dependency lockfile, configuration examples and a concise README.
2. Backend migrations, repeatable development seed, endpoint implementation, permission policies and setup instructions. Include protected moderation tooling and deletion setup.
3. A component/design guide describing the screen hierarchy, status language, interaction decisions and accessibility behavior.
4. Meaningful tests and a verification report listing commands, actual results, limitations and any unrun checks.
5. A catalog source manifest with verification dates, licenses/asset provenance, missing fields and outstanding provider permission questions.
6. A short capstone demo script using the visibly isolated Demo configuration, including a no-data state and a shared-report demonstration when a live development backend is configured.
7. Release documentation for bundle ID, Developer Team, Sign in with Apple capability, signing, environment selection, archive, TestFlight and App Store Connect. Discover actual simulator names/tool versions rather than hardcoding a nonexistent destination.
8. An original app icon asset and correctly sized asset-catalog entries, including an opaque 1024×1024 source suitable for submission. Keep branding provisional and do not use a competitor's icon or an unlicensed symbol as the icon.
9. A privacy/data-flow inventory, required location usage description, applicable `PrivacyInfo.xcprivacy` declarations based on the APIs/SDKs actually used, and draft privacy/terms/support content. Flag owner-supplied public URLs/contact details as explicit release inputs; do not publish placeholder contact information.
10. Draft App Store name/subtitle/description/keywords, category and age-rating notes, screenshot plan, and reviewer notes explaining guest access, location-denied behavior and how to test the real contribution flow. Screenshots must reflect the actual app and identify any demo content accurately.

Use native permission copy such as “Use your location to find nearby study spots and add context to your condition report.” Adjust it to the actual implementation. Do not ask for unrelated permissions.

The release checklist must cover functional backend availability, accurate privacy answers, working public privacy/support links, account deletion and Apple token handling, applicable UGC controls, required SDK manifests, export-compliance questions, current SDK/toolchain rules and device testing. Keep secret values out of source control and screenshots. Owner-only account enrollment, paid services, signing credentials and App Store submission must be identified concretely rather than replaced with fake success.

## 13. Execution milestones and completion report

Implement sequentially in complete vertical slices:

1. Inspect and scaffold the native project; establish the domain models, original design tokens and clearly labeled fixtures.
2. Complete guest discovery → time-aware recommendations → details → routes using the curated catalog.
3. Implement shared backend, actual Sign in with Apple, validated contribution, aggregate reads and multi-client refresh.
4. Finish saving, preferences, offline states, reporting controls, moderation and account deletion.
5. Verify domain/backend/UI behavior, polish rendered screens and assemble release/capstone documentation.

Continue past each milestone without asking me to approve routine reversible implementation decisions. If an external account or credential blocks a live check, finish the remaining independent implementation, state the exact missing input, and label that check blocked. Do not turn a temporary live-service limitation into a claim that the implementation is production verified.

At completion, tell me what works, where the project is, how to run it, what was actually tested, and which precise steps remain before TestFlight and App Store submission. Include screenshot evidence when the environment can produce it. Do not call the app ready for public release while essential live reporting, deletion, signing/configuration or required testing is still unverified.

# MASTER BUILD PROMPT — END
