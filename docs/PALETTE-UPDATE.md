# Between palette update — October 28, 2026

Implemented the supplied palette throughout the native SwiftUI app: Canvas `#FBFBF8`, Mist `#DBE3E9`, Cornflower `#6AA6DA`, Pear `#E1E5AC`, and Black `#000000`.

Canvas forms the background, Mist supplies cards/search fields, Cornflower fills primary actions/time cards/map pins, and Pear highlights selections and study time. Filled controls use black labels. Dark mode retains the blue and Pear brand colors with black canvas and cool dark surfaces. The logo was recolored with image generation; the original green artwork is preserved in docs/brand.

## Verification

- Xcode simulator build succeeded for Between-Demo on iPhone 17 Pro / iOS 26.2.
- Visually inspected Find in light and dark appearance, library details, and the report screen.
- Key text contrast: black on Cornflower 8.08:1; black on Pear 16.00:1; metadata on Mist 5.52:1; dark metadata on its card surface 8.99:1.
- Git whitespace checks passed. Existing application logic and data services have no edits.
- Screenshots use the app's labeled Demo configuration for stable visual previews. This color update did not revalidate live UF feeds or reporting services.

The source ZIP contains the updated project with its existing backend source and documentation. It omits local credentials, dependencies, generated build products, and the unrelated pre-existing Between 2.xcodeproj folder. Open Between.xcodeproj and use Between-Demo for a preview without backend configuration.
