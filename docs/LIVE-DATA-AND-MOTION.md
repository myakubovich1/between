# Live data and native motion

## Data in the normal app

The `Between` and `Between-Live` schemes use public UF sources without credentials. The separate `Between-Demo` scheme is an explicit fixture harness; release and development builds cannot activate synthetic data through a plist value or launch argument. Normal app verification and the new screenshots use Development, not Demo.

| Data | Source | Refresh and behavior |
| --- | --- | --- |
| Six Gainesville library building counts | [UF occupancy page](https://www.uflib.ufl.edu/status/) → the public SafeSpace display IDs embedded in that page | Foreground refresh every 60 seconds; IDs rediscovered daily; overlapping requests coalesce |
| Five area counts | The same UF page: Grand Reading Room, Panama Canal Gallery, Latin American & Caribbean Collection, Map & Imagery, Marston Makerspace | Same refresh; shown separately and never summed into the building count |
| Opening hours for six libraries | [UF LibCal](https://api3.libcal.com/api_hours_grid.php?iid=6&format=json&weeks=2) | Hourly schedule cache, forced manual refresh, timezone/DST-aware intervals, overnight and 24-hour support, seven-day expandable display |
| Reservable rooms/carrels | Public [LibCal search](https://libcal.uflib.ufl.edu/r/search) for West, Marston, Education and Health Science | Selected date/time and 30/60/90/120 minutes; Health Science individual/group categories and room-size buckets; refresh every minute while active; two-minute stale label |
| Floor policies and reservation destinations | [UF Study & Testing Spaces](https://uflib.ufl.edu/using-the-libraries/studyareas/) and linked official library pages | Bundled factual catalog, with per-source checked dates; room availability and hours are never bundled as live data |
| Campus origin / next-class buildings | [UF campus building directory](https://campusmap.ufl.edu/library/api/searchBldg?srch=Turlington), with MapKit fallback | Explicit user search; five genuine common-building records bundled for recovery, with source links. No GPS history is persisted |
| Walking times and routes | Apple MapKit walking directions | Foreground route cache; coordinate-distance fallback explicitly marked estimated |

A count of people does not measure free seats. UF supplies no sensor timestamp in these displays, so the app distinguishes retrieval age from measurement freshness. Failed refreshes preserve earlier values as *saved* counts and never update their timestamps. Malformed payloads are unavailable, not zero. Unknown amenities remain unconfirmed.

Room search uses GET only. The parser separates exact-time results from suggestions for other times, validates the actual returned start/end for every match, and extracts names/capacities, stable detail links and validated, ephemeral UF-generated exact-time room links. Actual reservations and UF authentication stay on UF's site. The app never submits a booking. See [UF booking portal integration](UF-BOOKING-PORTAL.md) for browser handoff, stale-link fallback and refresh on return. A listed space is not a confirmed reservation. Overnight searches include LibCal's end date.

The optional community backend does not block official data. Unconnected community sections do not show synthetic observations or imply that a report service has returned zero results. Archived community/auth implementation remains available for a separately configured backend.

Closed libraries remain discoverable with their next published opening. Source links, retrieval ages, partial failures, cached schedules and unknown values are visible in the UI.

## Motion

Reviewed the live [Apple Maps Marston place card](https://maps.apple.com/?q=Marston%20Science%20Library), including collapsed/expanded map context, and [Waitz's campus discovery](https://waitz.io/). Apple's [Maps guidance](https://developer.apple.com/design/human-interface-guidelines/maps) and [Motion guidance](https://developer.apple.com/design/human-interface-guidelines/motion) inform the implementation. These are interaction references; Between retains its own palette, artwork and code.

- Interruptible spring transitions for map/list changes and result changes.
- A map handle that follows a drag and settles at a size stop.
- Native matched card-to-detail zoom, with the standard navigation transition under Reduce Motion.
- Short press feedback on custom buttons and save controls.
- Numeric transitions for occupancy/study-time updates and expanding published schedules.
- Native sheet detents, rounded corners and drag indicators for time/filter controls.

The app reads the system Reduce Motion preference and disables custom movement, springs and zoom when enabled. Debug UI tests can force the same custom-motion path with `-ui-testing -reduce-motion`; this does not modify the device's accessibility settings.

## Reproduce verification

Run `scripts/verify-live-data.sh` on macOS to compile the actual production data services and make real HTTPS requests. It checks all eleven counts, all six schedules and the four room-search locations, then prints source URLs and results. The small standalone runner declares only the app error type; it uses the production models/parsers/network code unchanged. `docs/evidence/live-sources-2026-10-29.json` records a successful actual run. Results naturally change with time.

Parser/transport tests cover real source-derived fixtures, request coalescing, failures, stale/future timestamps, zero counts, unavailable room suggestions, malformed HTML, timezone/date rollover and category validation. Native UI checks exercise actual count → search → place → published hours → actual room availability, plus reduced-motion discovery and accessibility-size search recovery. Test outcomes and screenshots are recorded after execution in the verification report.
