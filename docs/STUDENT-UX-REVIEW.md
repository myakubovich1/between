# Between: student experience review

Reviewed October 29, 2026. This is an expert walkthrough using student personas and actual app/source behavior, not interviews or a measured usability study.

## Who the app serves

The primary audience is UF students on the Gainesville campus with a short gap between classes. Their central question is: “Where can I study now and still get to my next class on time?” They usually need a quick decision on a phone while walking, with no account setup and little patience for uncertain status or long forms.

Secondary audiences are graduate/research students looking for designated quiet floors, and small groups looking for an appropriately sized reservable room. New students benefit from recognizable building names, a map and explicit entry rules. Visitors need public-access information; the app does not assume UF eligibility or guarantee entry.

These are product hypotheses inferred from the app's purpose. Research with actual students should establish their relative sizes and decision priorities.

## Walkthrough findings and shipped fixes

| Moment | Friction from a student's perspective | Implemented change |
| --- | --- | --- |
| First launch | A default Marston starting point makes travel times look personal when they are not. | Starting point stays unchosen. Walking and usable-study estimates appear only after a deliberate location/building choice. Browsing does not prompt for GPS or sign-in. |
| Leaving class | A library-only next stop cannot represent the next lecture. | Origin and next-stop search accept real campus buildings. UF's building directory is primary, with five genuine bundled common-building records and MapKit fallback. Common destinations take one tap to search; results show their UF source. |
| Planning a gap | A fixed “45 minutes” budget restarts implicitly as the clock moves. | An applied plan stores an absolute deadline. Remaining and usable study time count down, including outbound/onward walking and the arrival buffer. Expired gaps have a direct change-plan action. Older saved plans still decode. |
| Choosing where to go | Occupancy, seat reports and availability can blur together. | Actual UF building counts have retrieval ages and source detail. Area counts stay separate. Unknown amenities stay unknown. No unconnected community feed appears as empty real observations. |
| Checking opening times | A single closing label does not help tomorrow's planning or explain a closed option. | Expandable seven-day official schedule in campus time. Closed libraries remain reachable and show their next opening. Distinct open/closed row identities prevent a live schedule refresh from reusing the wrong card style. Missing or stale hours remain unconfirmed. |
| Reserving with friends | A generic booking link forces a second search and may suggest rooms at other times. | Native selected-time LibCal results, duration and capacity filters, Health Science individual/group selection, names/capacities and direct official links. Other-time suggestions are excluded. UF handles reservation confirmation and authentication. |
| Fitting a booking into a short gap | A room slot can start before arrival or run beyond class time. | Initial search aligns to estimated arrival; visible warnings explain before-arrival and outside-gap selections. Zero results offer a later time and the official search. |
| Browsing the map | Large controls leave too little screen space for the actual options. | Compact origin/time controls in map mode, an adjustable map height, and the same accessible library results beneath the map. |
| Entering a bad search | Debounced text can leave an apparently stuck empty result. | Submit commits immediately. Clear cancels older work and resets both input and applied query. Empty states distinguish no matching name, expired time and restrictive filters. |
| Setting filters | Unsupported outlet/Wi-Fi filters can remove everything; active filter counts can omit constraints. | Hide unsupported amenities unless previously active, distinguish quiet policy from current noise, add bookable-room filtering, include study minimum/room filters in active counts, and use the same recommendation logic for filter preview and results. Walk filtering waits for an origin. |
| Starting directions | Directions without a starting point are ambiguous. | Request the origin at that moment and continue to directions after selection. Selecting the current library produces a zero-minute walk. Estimated routes are labeled. |
| Empty Saved tab | An empty explanation leaves the student hunting for the next action. | A direct Find a library action returns to discovery. Favorites remain local without an account. |
| Repeated use/offline | Old values can look freshly fetched; cached catalog data can overwrite updated policies. | Preserve observation timestamps on failures, mark saved values, coalesce overlapping requests, and restore cached hours without replacing current bundled identities/policies. |
| Motion | Abrupt changes weaken continuity; excessive movement can obstruct use. | Short press feedback, interruptible springs, card-to-detail navigation, numeric transitions and native sheets. System Reduce Motion disables custom movement and uses standard navigation. |

## Interaction and information structure

Find remains the primary task surface: search, choose origin, set the gap/next stop, narrow needs, compare options, then open details. Details place official occupancy, opening schedules, study policies, directions and reservation search in one path. Saved supports repeat visits. You explains data sources and local controls without asking a browsing student to configure a backend.

Canvas, Mist, Cornflower, Pear and Black remain the visual foundation, with appearance-aware contrast. Apple Maps place-card behavior and Waitz campus discovery were reviewed as interaction references; the app's implementation and artwork remain its own.

## Validation and limits

See VERIFICATION.md for executed test totals, actual HTTPS checks and screenshots. Native UI scenarios cover origin → next class → applied plan → unsuccessful search → clear → Saved recovery; actual occupancy → map → library → weekly hours → actual room results; and reduced-motion discovery. Parser/transport tests include malformed feeds, partial failures, exact reservation time matching, source fixtures and overnight times.

UF's display feed supplies headcounts without sensor measurement timestamps, not available-seat counts. Rooms can be reserved by someone else after retrieval. Neither routes nor entrance coordinates guarantee access. The optional community backend and native Apple account lifecycle still need their separately documented hosted/signing setup. Physical-device VoiceOver and student usability sessions remain unrun; this review does not claim perfection or measured conversion improvements.
