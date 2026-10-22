# Privacy and data-flow inventory

Development draft, checked October 22, 2026. Final answers must match the actual hosted services, logs, retention and owner privacy policy. No advertising, tracking SDK, analytics service or personal study-history analytics is configured.

| Data | Device | Server / third party | Purpose / retention |
| --- | --- | --- | --- |
| Guest favorites, study preferences | UserDefaults | Not synchronized | Local until cleared or app data removed; not authentication storage |
| Catalog and safe conditions | Versioned atomic JSON cache, separated by mode | Public catalog and aggregate endpoint | Offline discovery; refresh/expiry labels prevent stale data appearing current |
| Apple identity / optional relay email | Auth session in Keychain; Apple opaque user identifier locally for credential checks | Supabase Auth user and Apple identity records | Authentication; erased through account deletion subject to actual operational backup/log retention |
| Structured conditions | Demo only locally; real accepted summaries in cache | Private report with author, scope, seat/noise enums, server time, proximity category, moderation state | Shared aggregate for 30m; private report retained up to 24h plus next hourly purge, then deleted; flags cascade |
| Location sample | In foreground memory, cleared when leaving active use | MapKit for routes; optional report endpoint for a nearby heuristic | Immediate task only; raw report coordinates never reach Postgres or explicit logs; no location trail |
| Flag / mute | Current UI result only | Private reporter→report reference or viewer→target record | Moderation and personalized aggregates; flags expire with reports; blocks until account deletion |
| Moderation audit | None | Operator/action/time/opaque operation reference; no author ID | Operational accountability; 90-day purge |
| Apple deletion authorization code/tokens | AuthenticationServices memory | Apple's token/revoke endpoints through the server | Fresh same-account authorization and revocation; tokens are not persisted |
| Auth/service security logs and backups | Minimal fixed-message OSLog diagnostics | Provider infrastructure | Owner must verify settings and publish actual retention; never enable request-body capture of coordinates or credentials |

## Current declarations

`PrivacyInfo.xcprivacy` declares no tracking, User ID, Email Address (when provided/retained by Apple/Supabase identity), and Other User Content for app functionality, linked to the account. Required-reason UserDefaults access uses CA92.1 for app-local saves/preferences. Tokens use the SDK's KeychainLocalStorage. The pinned Supabase SDK and transitive package manifests ship with their own declarations; inspect the final Xcode privacy report after signing/configuration changes.

Precise location is optional and transient. Apple's privacy-detail definition distinguishes ephemeral request processing from retained collection; verify actual deployment logging before selecting the final location disclosure. If any raw sample or location-bearing request body is retained by infrastructure or analytics, update the policy and App Store answers accordingly and remove that retention. MapKit/Apple also process requests under their service terms. No claim is made that a GPS sample proves a seat, floor or student status.

Location usage copy: “Use your location to find nearby study spots and add context to your condition report.” Only When In Use is requested in context. No background location, microphone, contacts, calendar or advertising identifiers. No account is required to browse, choose manual origins or save locally.

## Deletion and retention limits

In-app account deletion first blocks new contributions from all existing sessions, then confirms and revokes the Apple authorization and hard-deletes Auth/account-associated private rows. Failure is reported and can be retried; a failed operation is not presented as deletion success. Local session/cache cleanup follows success. Local guest favorites can be separately cleared. The accountless moderation audit retains an opaque reference for 90 days for abuse-operation accountability. Determine actual provider backup/log windows before publishing a promise about erasure from backups.

## Owner release inputs

Publish real HTTPS privacy, terms and support pages; identify the controller/operator, contact route, geographic hosting region, service processors and current retention/backup practices. Configure those URLs in Local.xcconfig. Complete App Store privacy answers against the signed archive's final SDK inventory, not merely this draft.

Primary references: [Apple App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/), [Required reason APIs](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api), [Account deletion guidance](https://developer.apple.com/help/app-review/guideline-reference/5-1-1-account-deletion).
