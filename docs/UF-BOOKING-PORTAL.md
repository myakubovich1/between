# UF booking portal integration

Implemented October 29, 2026. Between uses UF's existing LibCal booking flow. It opens the official site in the user's default browser, preserving the selected search or exact room/time when supported. UF performs any required authentication, eligibility checks, final reservation and cancellation.

## What was checked

- UF's [Study & Testing Spaces](https://uflib.ufl.edu/using-the-libraries/studyareas/) page links its public booking categories and [all-spaces portal](https://libcal.uflib.ufl.edu/allspaces). The LibCal root is an events calendar, so it is not the booking entry point.
- The live all-spaces portal was used to select Marston, search an actual interval and open a returned room link. The official room page displayed **Current Booking Time Selected** with the same date and 8:30–9:00 AM interval. No Book Now, authentication or final reservation submission was performed.
- UF's portal supplies room links containing a room ID, local start/end and a server-generated checksum. A plain `/space/id` drops the chosen interval. Between now preserves the exact returned link after checking its host, room and returned interval.
- The Health Science portal lists separate individual/group categories; its group category is 9718. UF publishes a separate [West graduate-floor booking page](https://libcal.uflib.ufl.edu/reserve/gradstudyLW) with a currently enrolled UF graduate-student restriction.
- UF's booking descriptions direct students to their confirmation email for cancellation. Between therefore does not invent a “My bookings” dashboard or claim that browser navigation proves a booking succeeded.

## Approach comparison

| Approach | Benefit | Cost / limitation | Decision |
| --- | --- | --- | --- |
| Official links in the default browser | Smallest integration; normal browser navigation, autofill and UF authentication; no account setup in Between | App switches to the browser; private bookings are not synced back | Implemented, with native search context and refresh on return |
| SFSafariViewController | System-provided browsing inside the app with Done and Safari controls | A second browsing surface to test through UF's sign-in and any MFA; app still cannot inspect reservation success or website data | Reasonable future option if an in-app browser is preferred; adds little booking capability now |
| Custom WKWebView / form automation | More control over embedded presentation | Must support UF's changing web flow, browser state and authentication; more integration work and failure points | Not appropriate for the easiest dependable handoff |
| Direct write API and native account/reservation management | Potential full native booking and booking history | Requires a UF-supported integration, a documented booking contract and authorized server credentials; none is configured in this repository | Separate institutional integration, not necessary for portal linking |

Apple documents [SFSafariViewController](https://developer.apple.com/documentation/safariservices/sfsafariviewcontroller) as a self-contained interface whose website interactions/data are unavailable to the app. [Springshare](https://www.springshare.com/libcal) advertises read/write APIs; this is not evidence that UF grants Between API write access. The API cost above is an implementation assessment, not a claim that a UF partnership has been established or refused.

## Shipped user paths

1. **Find → calendar button → UF room bookings.** The same directory is available from You and in the accessibility-size Find layout. Browse all study spaces, or open West, Marston, Education, Health Science individual/group, or the West graduate page. These links remain usable when Between's availability lookup fails.
2. **Library → Rooms → choose date, duration and size → room.** A current, exact-time room link opens UF with that room and interval selected. Between uses only the link supplied by UF and never constructs a booking signature or submits a booking POST.
3. **Continue on UF for this time.** The chosen library, Health Science category, date, overnight end date, duration and capacity are carried into UF's search. This action is available while loading, on zero results and after a data error; it is not gated by the native parser.
4. **Return to Between.** The original native selection remains and a foreground transition rechecks room availability. A room link older than the app's two-minute freshness window, with a failed refresh, missing a supported exact-time URL, restored from JSON, or with mismatched metadata falls back to the same selected-time UF search.
5. **Manage the booking.** UF's confirmation email supplies the management/cancellation link. Between does not infer success, send booking notifications, or request UF credentials.

If the operating system cannot open the selected-time link, the view offers a retry and a share/copy link. All room times use America/New_York, including overnight searches.

## Data and maintenance

`UFBookingPortal` centralizes the official destinations and validates exact-time room URLs: HTTPS, exact UF LibCal host, matching numeric room ID, start/end matching the validated search interval, and only the expected checksum query. Unexpected links fall back to the public search. The browser handles UF's subsequent legitimate redirects.

The selected-time room URL exists only in the short-lived in-memory room result. Its field is explicitly excluded from Codable; the stable room URL remains serializable. Between keeps no UF password, authentication cookies, booking receipt or private reservation record. The browser and UF process their normal website/session data.

Library-specific rules differ and can change. The directory links to current UF rules instead of duplicating booking quotas in the app. No new backend, provisioning, paid service or application permission is required.

## Verification

See the booking update in VERIFICATION.md for executed tests and evidence. Checks include real source-derived room links; date/time preservation; rejection of external, mismatched and ambiguous URLs; JSON exclusion; stale-result fallback; and the native app → official browser portal → app return flow. Actual signed-in booking, MFA and cancellation are not claimed: no reservation was made during verification.


The final focused run passed **34 tests**: 31 domain/source tests and three native UI flows, including an actual selected-room handoff to Safari and return. Seven directory destinations returned HTTP 200. A production-service source pass validated exact-time links for all 55 rooms returned at that time. Evidence and the precise execution scope are in [VERIFICATION.md](VERIFICATION.md).
