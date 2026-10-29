# Testing Between on your team's iPhones

Updated October 29, 2026. Source is public at [myakubovich1/between](https://github.com/myakubovich1/between). A public repository shares source code; the installable iPhone beta is distributed separately.

## Recommended: TestFlight

Testers need an iPhone running **iOS 18 or later** and the free TestFlight app. They do not need Xcode or a paid developer membership. The person uploading Between needs access to an enrolled Apple Developer Program team. Apple's standard US membership price is $99 per year; use your organization's existing team if one is available. [Apple enrollment](https://developer.apple.com/programs/enroll/), [TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/).

Owner / uploader:

1. Open Between.xcodeproj on a Mac. Select the Between scheme and your Apple development team in Signing & Capabilities. Confirm the bundle ID belongs to that team; the current source value is app.between.study. Register/enable the capabilities requested by the target, including Sign in with Apple, and use automatic signing where appropriate.
2. Create the matching app record in App Store Connect. Archive for a generic iOS/device destination, then use Xcode Organizer to validate and upload the signed build to App Store Connect. The normal scheme archives Release and fetches actual public UF data.
3. In App Store Connect → Between → TestFlight, provide beta test/contact information and complete the applicable export-compliance questions. For ordinary teammates who are not App Store Connect users, create an **External Testing** group. Submit the first build for TestFlight App Review; after approval, invite them by email or enable a join link. Existing App Store Connect teammates with suitable roles/app access can use an **Internal Testing** group instead. [External testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers/), [internal testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers/).
4. Share the invitation/join link. Testers install TestFlight, accept the invitation and tap Install for Between. Builds are available for up to 90 days; upload new builds for ongoing testing. A public App Store launch is not needed for a TestFlight beta.

Current project status (October 29, 2026): simulator builds and native UI checks have passed. A signed Release archive for version **1.0.0 (1)** successfully uploaded and completed Apple's processing. The App Store Connect record is **Between Study Spaces** (Apple ID **6828482930**, bundle ID **app.between.study**); the installed app remains named Between. The build was submitted for external TestFlight review and assigned to the private **Team** group, with automatic tester notification selected. External installation invitations depend on Apple's approval. Tester contact details stay in App Store Connect and are excluded from this public repository; no public join link is enabled.

The guest beta can test official UF counts, hours, campus planning, saved places and browser booking without configuring a community backend. Community contributions and Apple account/deletion flows remain separate hosted/signing work documented in RELEASE.md; leave those unavailable until genuinely configured and verified. Sign-in/confirmation on the linked UF booking site is handled by UF in the browser.

## Suggested first team pass

- Choose a starting building, set a study gap and add the next class/building. Check the walking allowance and countdown.
- Compare actual opening schedules, closed-library behavior and count retrieval ages. Headcounts do not promise free seats.
- Choose a room/time and check that UF's portal receives the intended room and interval. Complete a real reservation only when you actually need one.
- Save a place, relaunch the app, and check light/dark and larger-text layouts.
- Send screenshots and feedback through TestFlight, including device/iOS version and reproduction steps.

For developers with Macs, cloning the repository and running Xcode is another testing route. This is developer installation, not a shareable iPhone download link. Paid-team signing supports the target's existing capabilities; personal-team/free signing can require a guest-only capability configuration.
