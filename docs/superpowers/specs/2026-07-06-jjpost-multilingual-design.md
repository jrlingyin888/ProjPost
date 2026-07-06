# JJPost Multilingual Design

## Goal

Add an in-app language switch for JJPost v1.1.0 with English as the default language and Simplified Chinese as the second supported language.

## User Experience

- Add a compact language menu in the lower-left Add Project panel, next to the app version.
- The menu shows `English` and `简体中文`.
- New installs default to English.
- The selected language is saved locally and restored on the next launch.
- Switching language updates the visible interface immediately without requiring an app restart.
- The language control is disabled while an upload or other blocking operation is running, matching the existing sidebar controls.

## Localization Scope

The v1.1.0 scope includes:

- Sidebar project list, add project, delete project, drag/drop help, and project status labels.
- Project Workbench labels, buttons, warnings, and apply-change summaries where the label text is user-facing.
- Apple Account section labels, buttons, key status, saved-account summary, and guide launcher.
- Apple Account Guide sheet language should follow the global app language by default while keeping its local segmented control available.
- TestFlight upload controls, distribution group labels, beta review status labels, and upload console framing text.
- Core user-facing AppViewModel status and error messages shown in the UI.
- Configuration check result titles and messages.

Out of scope for v1.1.0:

- Localizing raw command output from Xcode, altool, notarytool, or App Store Connect errors.
- Localizing stored historical upload messages that were persisted before the language switch.
- macOS system file picker strings.

## Architecture

Create a small localization layer in `ProjPostCore` instead of relying only on SwiftUI `LocalizedStringKey`. JJPost currently generates many user-facing messages in core state code, so the view layer alone cannot cover the app.

The localization layer should define:

- `AppLanguage`: `english`, `simplifiedChinese`.
- `LocalizationStore`: an `ObservableObject` that stores the selected language in `UserDefaults`.
- `AppStrings`: typed string helpers that return text for the active `AppLanguage`.

SwiftUI views receive the localization store through the environment and call typed helpers instead of embedding display strings. Core workflows that produce user-facing messages should accept or reference the selected language through `AppViewModel`, so status messages are created in the current language.

Keep technical constants unchanged: bundle IDs, scheme names, build settings, API enum values, file names, and Apple raw states remain English/raw as required by tools.

## Data Flow

1. `ContentView` owns `@StateObject var localizationStore`.
2. The store loads `UserDefaults["JJPost.selectedLanguage"]`, defaulting to English.
3. The store is passed into SwiftUI via `environmentObject`.
4. `AppViewModel` exposes `appLanguage` or receives language changes from `ContentView`.
5. Views and model-generated UI messages use `AppStrings` with the current language.
6. Changing the language menu updates the store, persists the value, updates the view hierarchy, and affects future status messages.

## Error Handling

- If the saved language value is unknown, fall back to English and overwrite it on the next explicit change.
- If a localized string is missing during development, tests should fail rather than silently falling back.
- Raw external error text is appended after a localized prefix, for example `Upload failed: <raw error>` / `上传失败：<raw error>`.

## Testing

- Add unit tests for the default language and persistence behavior.
- Add unit tests that every supported `AppLanguage` has values for key UI strings.
- Update existing tests that assert Chinese-only status labels, such as project status labels, to assert both English and Simplified Chinese variants.
- Add AppViewModel tests for representative localized messages: missing project, upload success, TestFlight review status, and configuration checks.
- Run the full Swift test suite before packaging.

## Release Notes

JJPost v1.1.0 should mention:

- Added English and Simplified Chinese app language support.
- English is now the default interface language.
- Language can be changed from the lower-left app panel.
