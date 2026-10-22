# Asset and source provenance

- App icon: original geometric artwork generated for this project using Core Graphics. Opaque 1024×1024 PNG lives in AppIcon.appiconset; the reproducible source is `scripts/generate-icon.swift`. No competitor logo or SF Symbol is embedded in it.
- In-app symbols and typography: Apple's SF Symbols and system SF fonts through native framework controls. No font files are redistributed.
- Maps, routing, annotations and attribution: native MapKit. Apple Maps/Legal attribution remains visible. No downloaded map tile pack, floorplan artwork or campus photography is bundled.
- Catalog: factual venue identities, published addresses and paraphrased policies linked to official UF pages with check dates in `catalog-source-manifest.json`. Address locations were resolved through Apple Core Location geocoding on October 22, 2026; usable entrances are not verified. Do not interpret a source link as permission to scrape or republish a provider's occupancy feed. That integration remains disabled.
- Demo conditions, date intervals and estimated walk times: synthetic fixtures authored for this project, isolated and labeled. They are not community activity or evidence of current UF conditions.
- Screenshots: actual native simulator captures from the development builds. Demo labeling is retained. They are verification artifacts; App Store screenshots must accurately represent the final configured release.
- Third-party source dependencies: official supabase-swift 2.55.4 and the exact transitive versions in Package.resolved; Edge jose 6.2.13 and backend-test supabase-js 2.118.0. Root license/notice files from resolved Swift checkouts are preserved under `docs/third-party/`. Review final distribution acknowledgments for any changed dependencies. The backend test SDK is not bundled into the iOS app.

No external publication or open-source license for the original app has been assumed. The owner should decide distribution/licensing and validate the provisional name before public release.
