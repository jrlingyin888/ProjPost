# Apple Account Guide Design

## Goal

Add an in-app guide next to the Apple Account section so users can find and enter the `.p8` private key, Key ID, Issuer ID, and Team ID without leaving ProjPost to guess the App Store Connect layout.

## User Experience

- Add a compact `Guide` control beside the `Apple Account` group label.
- Open a local SwiftUI sheet, keeping the current account form visible behind it.
- Structure the guide as short numbered sections:
  1. Create or find an App Store Connect API key in App Store Connect > Users and Access > Integrations > App Store Connect API.
  2. Copy Issuer ID from the App Store Connect API page.
  3. Copy Key ID from the generated API key row.
  4. Download the `.p8` key once and import it with `Import .p8`.
  5. Find Team ID in Apple Developer Account > Membership details.
- Include a security note that `.p8` is downloaded only once by Apple and ProjPost stores imported key content in Keychain rather than displaying it.
- Include the two user-provided reference screenshots inline in the sheet, with captions explaining what each one shows.

## Implementation

- Add a SwiftUI guide view named `AppleAccountGuideView` under `Sources/ProjPostApp/Views`.
- Add `@State` in `ProjectDetailView` to present the guide sheet from the Apple Account label.
- Add `Sources/ProjPostApp/Resources/AppleAccountGuide/` and copy the two provided screenshots there with neutral names.
- Update `Package.swift` so `ProjPostApp` processes its resources.
- Keep the guide static and local. Show Apple reference URLs as `Link` controls, but loading the guide must not require network access.

## References

- Apple documents creating App Store Connect API keys and notes the generated key page contains the key name, Key ID, download link, and related information.
- Apple Developer Account Help says Membership details include Team ID, role, renewal date, and contact information.

## Testing

- Add a lightweight test that verifies the packaged guide image resources exist in `Bundle.module`.
- Run the Swift test suite and `swift build`.
- Package and relaunch the app to verify the sheet opens and both screenshots render.

## Out of Scope

- No credential validation changes.
- No automatic scraping from App Store Connect or developer.apple.com.
- No storage or display changes for the `.p8` key.
