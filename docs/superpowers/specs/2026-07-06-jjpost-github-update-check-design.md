# JJPost GitHub Update Check Design

## Goal

Add a lightweight update check for JJPost using GitHub Releases. The first version only alerts the user and opens the GitHub release page; it does not download, unzip, replace, or relaunch the app.

## Behavior

- On app launch, JJPost calls GitHub's latest release endpoint for `jrlingyin888/ProjPost`.
- The app compares `ProductBranding.appVersion` with the latest release tag after normalizing tags such as `v1.1.0`.
- If the latest release is newer, JJPost shows an update alert.
- The alert explains that installation is manual: quit JJPost, download the zip, unzip it, replace the old `JJPost.app`, then reopen.
- The primary alert button opens the GitHub release page in the user's browser.
- If the latest release is the same or older, no alert is shown.
- Network errors do not block the app and do not show an alert.

## Scope

- This feature does not auto-download zip assets.
- This feature does not replace the running app.
- This feature does not use Sparkle.
- The UI follows the existing English/Simplified Chinese localization system.

## Files

- Core update model and checker live in `Sources/ProjPostCore/Updates/AppUpdateChecker.swift`.
- `AppViewModel` owns update state and startup checking.
- `ContentView` presents the update alert and opens the release URL.
- Tests cover version comparison, GitHub release JSON parsing, update availability, and ViewModel state.
