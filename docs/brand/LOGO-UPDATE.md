# Between logo update — October 29, 2026

The new **Open Interval** mark uses two opposing book pages to frame an open space, with a Pear bookmark as its focal point. It connects the app's library purpose with finding useful study time between classes. The broad shapes and simple center gap remain legible at the 46-point header size. The native lowercase Between wordmark remains sharp and accessible alongside it.

The artwork uses the existing Cornflower, Canvas and Pear palette. It was created with the built-in image-generation tool and refined once, then exported for the asset catalog. Generated artwork can have small tonal variation; the app's exact color tokens are unchanged. No UF or competitor logo was referenced.

## Implemented assets

- `BetweenIcon.png`: opaque 1024 × 1024 PNG in AppIcon, with no baked-in rounded-corner mask. iOS applies its icon shape.
- `BetweenMark.png`: 384 × 384 PNG in BrandMark, shared by the Find header and You profile section.
- `Between-Open-Interval.png`: 1254 × 1254 master in docs/brand.
- The previous icon/mark and original prompt are preserved in docs/brand/archive. The original green master is also retained.

The existing asset names AppIcon and BrandMark remain the public integration points, so all existing consumers receive the new artwork together. No app logic, booking flow or data-service change is part of this update.

## Verification

- Development simulator build succeeded with the actual asset catalog.
- Icon verified at 1024 × 1024 with no alpha; BrandMark verified at 384 × 384 with no alpha.
- The rebuilt app was installed on iPhone 17 Pro / iOS 26.2 and inspected in light and dark appearance, including the Find header, You profile mark and system app icon.
- This asset-only update did not rerun the previous booking/domain test suite. Its prior results remain documented separately.

Exact generation and refinement prompts are in docs/brand/PROMPT.md in the GitHub repository.
