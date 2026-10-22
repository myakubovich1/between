# Native interaction and component guide

Three stable tabs each own a NavigationStack: Find, Saved, You. Reporting opens from a place. Find shares query/filters and selection across the native map and a scrollable results panel; its handle resizes the map from 130 to 310 points. List-only mode retains discovery without requiring map gestures. iPad uses map/results side-by-side. Accessibility text sizes use an independently scrollable list layout so large headers cannot consume the whole screen. Details and report sheets keep primary actions in safe-area insets. No stacked reporting/authentication sheets are required.

Find begins with a visibly manual UF library origin. Permission is never requested on launch. A map origin control opens “Use my location” or the curated manual origins. Next destination is optional. Time controls include 30/45/60/90 minutes and a custom stepper; the default buffer is five minutes. Plans show inbound walk, study, onward walk and buffer. Unknown opening/access information produces “possible study” with a check-before-going label. A hard confirmed-entry filter excludes unknown access. No destination means the plan explicitly excludes onward travel.

Ranking factors: preference fit 30%, usable study time 25%, recent seat evidence 20%, convenience 15%, freshness 10%. Values are bounded and deterministic. Sound is an optional soft preference; unknown sound adds no positive match and remains labeled missing. Quiet filters refer to a designated quiet policy, not to an unobserved current sound level. Outlets/Wi-Fi hard filters exclude unknown values. One building marker represents all its zones; floor choice and building evidence remain separate.

## Tokens and components

| Token | Light | Dark | Use |
| --- | --- | --- | --- |
| Canvas | #F7F7F4 | #111A17 | Main content background |
| Ink | #1B2422 | #E6EFEA | Primary content |
| Forest | #1C6B5A | #77D5BA | Accent text and symbols |
| SoftForest | #E8F0E9 | #20382F | Quiet supporting surfaces |
| Metadata | #59645F | #B3C1BA | Essential secondary text |
| BrandFill | #1C6B5A | #1C6B5A | Filled buttons with white text |

SF system/rounded titles, native controls and SF Symbols; no downloaded fonts or photography. Spacing 4/8/12/16/24/32pt; margins 20pt; typical radius 14–22pt. Semantic surfaces support system appearance. Native bars and system sheets adopt platform materials; content-heavy cards are opaque. Explicit light/dark accent fills preserve contrast rather than placing white text on the light dark-mode accent. The custom icon is an original geometric lowercase “b”/gap composition and does not embed an SF Symbol or competitor asset.

`PlaceCard` orders identity/walk, seat condition, usable minutes, hours/access caveat, evidence freshness. Save is a sibling button, not nested inside the navigation button. `StatusLabel` always uses words and an SF Symbol; gray/metadata means missing, never empty seats. `EvidenceCaption` uses independent reporter count and observation age. `Surface`, `Pill`, `Eyebrow`, `NoticeView` and `PrimaryButton` supply shared layouts. All primary hit regions are at least 44pt.

Labels distinguish “Plenty of seats / Some seats / Almost full / Full”, “Reports differ”, “No recent reports” and “Reports have expired”. Optional sound labels remain separate. One reporter is described as one student report. Community categories never become occupancy percentages, desk counts, adjacent-seat guarantees or accuracy claims.

The report form requires one seat choice and makes sound optional. Native Apple authentication keeps the current form mounted. Cancel returns to the place. Submit disables duplicate taps; success follows acceptance. Failure retains choices, shows a useful error and requires a fresh explicit confirmation before retry. A small success haptic is used; there are no custom ornamental animations. System motion/transparency preferences are respected through native bars and controls, and core content remains readable without material effects.

Demo labeling is visible in all tab roots and presented flows. You provides no-data, offline and 31-minute clock-advance controls; only that isolated store changes. A live backend failure never adds fake reports.

## Accessibility and remaining user validation

List navigation supports VoiceOver labels, native focus behavior and the full contribution path. Map controls are supplementary. Text wraps at Dynamic Type sizes, and essential actions remain in scroll or safe-area layouts. Dates and distances use Foundation formatting; UF schedules are absolute date-specific intervals curated for America/New_York. Verify VoiceOver on a physical device, including sheet dismissal/focus return, and perform a user-timed reporting trial before claiming a sub-10-second flow. Screenshot coverage and unrun accessibility checks are recorded in VERIFICATION.md.
