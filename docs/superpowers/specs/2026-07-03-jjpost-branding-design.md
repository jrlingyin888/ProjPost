# JJPost Branding Design

## Goal

Prepare the app for product users by changing the visible product name from `ProjPost` to `JJPost` and adding a polished macOS app icon.

## Naming

- The delivered app bundle should be `dist/JJPost.app`.
- The Dock, menu bar, window title, and Finder display name should show `JJPost`.
- The Swift package target and executable may remain `ProjPostApp` to avoid unnecessary code churn.
- Existing local storage and Keychain service names should remain `ProjPost` / `com.projpost.appstoreconnect` for now so saved projects, Apple accounts, and private keys keep working on the current machine.

## Icon

- The app icon should use a single capital `J`, not `JJ`.
- Style: dimensional, tech-focused, clean, suitable for macOS Dock sizes.
- Shape: macOS-style rounded square.
- Visual direction: dark-to-blue technical background, luminous cyan/blue `J`, subtle depth/extrusion and highlight.
- Deliverable: `AppIcon.icns` included in `JJPost.app`.

## Packaging

- `scripts/package_app.sh` should package `JJPost.app`, include `CFBundleDisplayName`, `CFBundleName`, `CFBundleIconFile`, and copy resources needed by the SwiftPM executable.
- The app should still launch via the same executable, `ProjPostApp`.

## Testing

- Add tests for product branding constants used by the SwiftUI app.
- Verify `swift test`, `swift build`, and `scripts/package_app.sh`.
- Inspect `dist/JJPost.app/Contents/Info.plist` and `dist/JJPost.app/Contents/Resources/AppIcon.icns`.

## Out of Scope

- Rename the repository, Swift package, module names, storage directories, or Keychain service.
- Add signing, notarization, DMG packaging, or auto-update.
