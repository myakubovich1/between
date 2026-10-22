# UF data connection — October 22, 2026

The default **Between** scheme now reads actual published UF data directly on the device. It does not require Supabase credentials or an account. Between-Live is an equivalent existing scheme; Between-Demo remains an explicitly labeled fixture environment for deterministic UI tests.

## Occupancy

Source: [UF Libraries occupancy](https://www.uflib.ufl.edu/status/). Its page embeds public SafeSpace read-only display endpoints. The six display identifiers in `UFLibraryData.displays` were matched to the page's DOM targets, not guessed or copied from a private customer API. Requests do not use credentials, cookies, analytics scripts or location. Each display is fetched at most once per 60 seconds per running app. Requests are small and bounded; a failed/invalid response leaves the previous value and its original retrieval date intact.

| Place | UF display target | Public display ID |
| --- | --- | --- |
| Library West | currocclw | 6be1325f |
| Marston | currocc | 6d60eb03 |
| Health Science | currocchscl | dc7c5f6a |
| Architecture & Fine Arts | curroccafa | bb2a5b5e |
| Education | curroccedu | 53b6c442 |
| Smathers | curroccsmath | 7cbdd017 |

The response is a plain integer building count. **It has no sensor observation timestamp.** The UI therefore says “UF count · retrieved Xm ago” and “Sensor update time unavailable.” `observedAt` remains nil, so `OfficialOccupancy.isFresh` never treats it as a fresh sensor measurement. A retrieval time is not an observation time. Numeric building counts never become available-seat counts, free desks, percentages, or evidence about a floor. Counts do not influence the community-seat ranking factor. A failed feed does not become zero. Saved counts retain their age offline.

UF's page also contains older JavaScript pointing to `library-occupancy.s3.amazonaws.com`. Its Marston response was dated July 25, 2023 when checked. That obsolete feed is deliberately excluded from the app.

These are best-effort public display integrations, not a contracted provider API, UF endorsement, or a guarantee of accuracy. UF/SafeSpace can change or remove them. No separate redistribution contract or service agreement has been obtained. Before distributing a public product at scale, settle provider reuse/support terms and replace the adapter if required. This does not block the requested local development integration.

## Opening hours

Source: [UF LibCal hours](https://libcal.uflib.ufl.edu/hours/), through the public LibCal hours widget JSON at `https://api3.libcal.com/api_hours_grid.php?iid=6&format=json&weeks=2`.

The parser uses location IDs 8626 (AFA), 8627 (Education), 8871 (Health), 7728 (West), 8622 (Marston), and 8625 (Smathers). It reads absolute published dates, status and structured time ranges in America/New_York. It ignores the feed's `currently_open` flags and computes opening against the actual arrival time, including overnight ranges. It merges consecutive 24-hour intervals so Marston's Thursday does not falsely close at midnight. Only Marston's published 11:59pm-to-24-Hours Sunday convention receives a one-minute bridge; holidays are never replaced by weekly assumptions. Closed days are known closures; malformed, missing and by-appointment dates remain unknown. Schedules refresh every six hours while used and expire after 24 hours without a successful retrieval. Open-now filters and useful study minutes consume these schedules. General entry eligibility and usable entrances remain separately unverified.

`Tests/Fixtures/uf-hours-2026-10-22.json` is a factual snapshot containing only the six locations' dates and structured hours for repeatable parser checks. No fixture supplies production counts or production hours. Production always requests the current widget; no static weekly schedule is substituted.

## Availability and privacy

Official data and community reports have independent availability. A community backend failure cannot stop UF browsing, replace counts with sample reports or erase a successfully fetched schedule. Sign-in and contributions still require a configured Supabase/Apple deployment. Local development configuration is excluded from the source ZIP.

As with any direct web request, the UF/LibCal and SafeSpace infrastructure can receive the device's IP address and request metadata. The app sends no user identity, search query, favorites, study plan or precise location to these feeds. Values and schedules are cached locally, separated from Demo storage. No embedded website JavaScript executes in the app.
