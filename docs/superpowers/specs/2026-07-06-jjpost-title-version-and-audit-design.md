# JJPost Title Version And Audit Design

## Goal

Move the visible JJPost app version from the lower-left Add Project card to the right side of the main window title, then review the current app for code, feature-flow, and product-flow improvements.

## Scope

This change includes:

- Show `v1.1.0` beside `JJPost` in the main window title area.
- Remove the duplicate version label from the Add Project card so the language picker and folder button have enough room.
- Keep the current version source in `ProductBranding.appVersionDisplay`.
- Produce a concise optimization list grouped by priority.

This change does not include:

- Reworking the full sidebar layout.
- Changing the release/update mechanism.
- Refactoring `AppViewModel` in this pass.
- Adding automatic app replacement or Sparkle-style updates.

## UI Design

Use a custom navigation title view in `ContentView`:

- App name: `JJPost`, semibold, normal title color.
- Version: `v1.1.0`, smaller secondary text in a subtle capsule.
- Keep the window title compact so it fits the toolbar area.

The Add Project card should keep:

- Add Project label.
- Language picker on its own row.
- Choose Folder button.

The version label should no longer appear in the Add Project card.

## Audit Design

The audit should be split into three groups:

1. Immediate fixes: low-risk changes that improve current user experience.
2. Next version improvements: functional changes that need implementation and tests.
3. Later refactors: structural changes that reduce long-term maintenance risk.

Known areas to inspect:

- Keychain error messages and `.p8` recovery flow.
- TestFlight distribution refresh speed and API shape.
- Upload/review/linking state clarity.
- `AppViewModel` size and responsibility boundaries.
- Manual update and release flow.
- Localization completeness and persisted historical messages.

## Error Handling

The title UI should not introduce new runtime error paths. The audit should call out error paths that currently produce raw technical messages, especially Keychain and App Store Connect failures.

## Testing

Run the Swift test suite after the UI change. If packaging or app launch is relevant, rebuild or open `dist/JJPost.app` only if the existing scripts are already available and fast enough for this pass.
