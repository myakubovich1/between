# Asset and source provenance

- App icon and header mark: original bitmap artwork created with the built-in image generation tool for this project. Original saved in `docs/brand/Between-logo.png`; opaque RGB icon exported at 1024×1024 with a 240×240 header asset. The old Core Graphics generator is historical and does not reproduce the current mark. See `brand/PROMPT.md` for the exact generation prompt. No UF or competitor logo is included.
- In-app symbols and typography: Apple's SF Symbols and system SF fonts through native framework controls. No font files are redistributed.
- Maps, routing, annotations and attribution: native MapKit. Apple Maps/Legal attribution remains visible. No downloaded map tile pack, floorplan artwork or campus photography is bundled.
- Catalog: factual venue identities, published addresses and paraphrased policies linked to official UF pages with check dates in `catalog-source-manifest.json`. Address locations were resolved through Apple Core Location geocoding on October 22, 2026; usable entrances are not verified. The requested development integration now consumes UF's public read-only display feeds and LibCal widget. Source semantics, absent sensor timestamps, missing provider contract, and release-scale terms are documented in UF_DATA.md.
- Demo conditions, date intervals and estimated walk times: synthetic fixtures authored for this project, isolated and labeled. They are not community activity or evidence of current UF conditions.
- Screenshots: actual native simulator captures from the development builds. Historical Demo captures retain their labels. New UF captures show actual fetched published counts and schedules. They are verification artifacts; App Store screenshots must accurately represent the final configured release.
- Third-party source dependencies: official supabase-swift 2.55.4 and the exact transitive versions in Package.resolved; Edge jose 6.2.13 and backend-test supabase-js 2.118.0. Root license/notice files from resolved Swift checkouts are preserved under `docs/third-party/`. Review final distribution acknowledgments for any changed dependencies. The backend test SDK is not bundled into the iOS app.

No external publication or open-source license for the original app has been assumed. The owner should decide distribution/licensing and validate the provisional name before public release.

## Palette update — October 28, 2026

The app icon and header logo use sibling PaletteIcon.png / PaletteBrandMark.png assets recolored with OpenAI image generation from the existing logo. The original green files are preserved under docs/brand/Before-palette-*.png. The SwiftUI theme uses the exact supplied hex values; generated artwork may have slight tonal variation.
