# App Store Review Submission Design

## Goal

Add a semi-automated App Store review flow to JJPost so users can prepare a store version, choose the exact build to bind, review App Store-facing localizations, and submit the selected version for App Store review without reopening App Store Connect for routine release updates.

## Scope

This feature uses the existing project `Version` as the default App Store version target, but the build is not assumed to be the newest build. JJPost loads all builds for the selected App Store version and lets the user explicitly choose which build to bind.

The first interactive version includes:

- Refreshing App Store review status for the selected app/version.
- Creating or loading the App Store version for the project version.
- Listing builds for that version.
- Defaulting the selected build to the latest successful JJPost upload when available, then the project build number, then the currently bound build, then the first valid build.
- Binding the selected build to the App Store version.
- Showing review contact/demo-account information when Apple returns it.
- Showing App Store version localizations and their `What's New` status.
- Submitting the bound selected build for App Store review through `reviewSubmissions`.

Advanced editing for review information, descriptions, keywords, screenshots, and per-locale screenshot sets is visible as a future entry point but not part of this first interactive slice.

## UI Placement

Add an `App Store Review` section below the existing `TestFlight Upload` section. Keep the section operational and compact:

- Top row actions: `Refresh Store Status`, `Create/Load Version`, `Bind Selected Build`, `Submit Store Review`.
- A safety hint explains that the first two actions update App Store Connect version data but do not submit the app for review.
- A version/build card displays the App Store version, selected build picker, release strategy, and binding status.
- A review information card displays existing contact/demo notes.
- A store localizations card lists App Store-facing locales separately from in-app language support and highlights whether each locale has `What's New` filled.

## App Store Connect API

Use the current App Store Connect API resources:

- `GET /v1/apps/{id}/appStoreVersions`
- `POST /v1/appStoreVersions`
- `GET /v1/appStoreVersions/{id}/relationships/build`
- `PATCH /v1/appStoreVersions/{id}/relationships/build`
- `GET /v1/appStoreVersions/{id}/appStoreReviewDetail`
- `GET /v1/appStoreVersions/{id}/appStoreVersionLocalizations`
- `POST /v1/reviewSubmissions`
- `POST /v1/reviewSubmissionItems`
- `PATCH /v1/reviewSubmissions/{id}` with `submitted: true`

## Error Handling

Refresh and action failures stay inside the App Store Review section and preserve the previous loaded snapshot when possible. Missing Bundle ID/version, missing app, missing App Store version, missing selected build, and submitting before binding should each produce actionable messages.

## Testing

Core tests should cover:

- App Store Connect request paths and JSON bodies for version listing, build binding, localizations, and review submission.
- View-model default build selection that prefers the last successful JJPost upload.
- Binding the user-selected build, not the newest build and not implicitly the project build number.
