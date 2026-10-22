# Capstone demonstration (about 3 minutes)

Run **Between-Demo**, never a live project seeded with fake observations. Point out the persistent “Demo data” label: crowd reports, opening intervals and walk estimates are synthetic; the catalog names/policies have official source references.

1. On Find, choose a manual campus origin. Set 45 minutes and a next destination, then select Quiet. Explain the practical question: how much of the gap is usable after walking and a buffer?
2. Open a recommended library. Show the time breakdown and change between building and floor reports. Identify designated quiet policy separately from current sound observations. Open “Where this comes from”; no UF occupancy provider is connected.
3. Tap Directions. This uses actual MapKit routing when available, with a recoverable failure and Apple Maps handoff. Address markers are not verified entrances. The synthetic recommendation times remain labeled Demo and can differ from a real route.
4. Save the place, relaunch and show Saved. Browsing, saving and manual origins need no account or location permission.
5. Report “Some seats”, optionally choose a sound level and use **Use demo contributor**. Submit, then show the explicit Demo acceptance. This only changes the local isolated Demo store; it is not the shared-backend demonstration.
6. In You → Demo controls, turn on no community reports. Return to Find: the catalog remains useful but there is no fake empty-building status. Advance the clock by 31 minutes to demonstrate expiry, or toggle simulated offline to show cached conditions.

## Real shared-update demonstration

When a development backend is available, use two independent clients of **Between-Live**, authenticate each with its own real Apple test identity and submit an actual observation at a place you are visiting. The second client refreshes after the campus invalidation. Relaunch the first client and show that the accepted update persists. Record actual observation and propagation timing. Do not characterize Demo submissions as shared.

The automated localhost integration runner has already performed independent-client persistence and Realtime checks using disposable local Auth users. That verifies server behavior, not the unconfigured native Apple account integration or a hosted deployment. A live student pilot requires consenting participants, current factual reports and the owner’s signed/configured build.
