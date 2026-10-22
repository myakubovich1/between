# Device, TestFlight and App Store release

## Current state

Native Xcode project, shared schemes, assets, lockfiles, local backend and tests are supplied. **Public release remains blocked** by hosted availability, real Apple authentication/revocation, owner signing/public URLs, catalog verification and physical-device/accessibility validation. Run `python3 scripts/release_preflight.py` to see missing local inputs. Passing it records configuration/signoffs; it does not prove App Review approval.

Toolchain checked October 22, 2026: Xcode 26.3 (17C529), Swift 6.2.4, installed iOS SDK 26.2; deployment target iOS 18. The [current Apple requirements](https://developer.apple.com/news/upcoming-requirements/) require Xcode 26+ with iOS 26+ SDK for uploads. Recheck before uploading; deployment target and upload SDK requirements are separate.

## Owner configuration

1. Confirm the provisional name, trademark/App Store availability, actual reverse-DNS bundle ID and Apple Developer Program enrollment. Current source bundle ID: `app.between.study`, display name configurable via `BETWEEN_NAME`. Set the actual `DEVELOPMENT_TEAM` in Xcode/Local.xcconfig and update the project if changing bundle ID.
2. Register the App ID, enable Sign in with Apple and create signing profiles. Use the same accepted audience/client ID in Supabase Apple provider configuration. See [Supabase native Apple guidance](https://supabase.com/docs/guides/auth/social-login/auth-apple).
3. Establish the dedicated development backend after the provider-side project-creation failures described in BACKEND.md. Apply migration, seed only curated catalog metadata and deploy `between-api`. Run security advisors. Configure Apple auth and server-side Apple token-revocation secrets. Never bundle the service key, Apple private key or a database credential.
4. Copy Local.xcconfig.example to Local.xcconfig and configure URL/key plus real HTTPS PRIVACY_URL, TERMS_URL and SUPPORT_URL. Use **Between-Live**; its Run action uses Development and Archive uses Release. Demo is an isolated scheme; it is not a production backend fallback. Release accepts only HTTPS backend configuration.
5. Complete catalog curation in `docs/catalog-source-manifest.json`, app catalog and server seed: current usable entrances/coordinates, explicit access eligibility, date-specific intervals, holiday/overnight exceptions and schedule expiry. Unknowns remain unknown. Newell/Reitz are deliberately deferred. The local development build now reads the public UF display and LibCal widget. Before public distribution at scale, settle provider reuse/support terms. Its display feed has no sensor timestamp; preserve the explicit unknown-age label and never substitute retrieval time. See UF_DATA.md.
6. Test a signed build with two independent Apple identities on physical iPhones: genuine report → server acceptance → separate client update → relaunch persistence. Test nearby checks with denied/approximate location, rate-limit/error recovery, stale-draft reconfirmation, flag/mute/moderation and actual Apple authorization revocation/account deletion. Test revocation, not just sign-out. Do not set preflight signoff flags before running these checks.

## Archive and upload

Open Between.xcodeproj, select Between-Live and a generic iOS/device destination, set the actual Team, then Product → Archive. An unsigned archive validation can compile source but cannot establish distribution signing, entitlement authorization, installation on a physical device or TestFlight readiness. After successful signed archive validation, distribute through Organizer to App Store Connect and test through TestFlight before App Store submission.

For a CLI unsigned validation, discover the available tools first and use:

```sh
xcodebuild archive -project Between.xcodeproj -scheme Between-Live \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath work/Between-Unsigned.xcarchive CODE_SIGNING_ALLOWED=NO
```

For tests, `scripts/test-ios.sh` discovers a real installed iPhone simulator; `xcrun simctl list devices available` lists alternatives. Physical-device signing needs the owner's account, and cannot be inferred from a simulator pass.

## Required release gate

- [ ] Hosted backend is available, migrated, seeded without demo crowd rows and verified by two real clients.
- [ ] Apple sign-in nonce exchange, session refresh, credential revocation, cancellation and real deletion/revocation work on signed devices.
- [ ] Old tokens cannot post after account deletion; failures remain retryable and truthful.
- [ ] Catalog entrances/access/date-specific schedules curated; coordinates and accessibility routes not overpromised.
- [ ] Current public privacy/terms/support links work and the support route is monitored.
- [ ] App privacy answers and final archived SDK manifests match actual behavior, location processing and provider logs/backups.
- [ ] Moderation queue is staffed; flagging, muting, removal and suspension work. Assess [App Review 1.2](https://developer.apple.com/app-store/review/guidelines/#user-generated-content): structured reports still need appropriate reporting/blocking and a published contact route. No public free-text or images are enabled.
- [ ] VoiceOver, Dynamic Type, light/dark, Increase Contrast, Reduce Transparency, Reduce Motion, small/large iPhones and iPad tested on release candidate; performance measured on devices.
- [ ] App icon remains opaque 1024×1024, original assets licensed and screenshots reflect the actual build with Demo content disclosed.
- [ ] Export compliance answers reviewed. The current Info.plist declares no non-exempt encryption based on standard Apple networking/SDK use; reassess if cryptographic behavior changes.
- [ ] Current SDK/toolchain, age-rating questionnaire and category requirements checked in App Store Connect.
- [ ] Signed archive validates, TestFlight passes, reviewer has working guest access and instructions for the real contribution/deletion flow.

The [Apple deletion guidance](https://developer.apple.com/help/app-review/guideline-reference/5-1-1-account-deletion) and [privacy detail documentation](https://developer.apple.com/app-store/app-privacy-details/) were consulted. Final submission, enrollment, paid services, credentials and account agreements remain owner actions.
