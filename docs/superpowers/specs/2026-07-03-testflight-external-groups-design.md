# TestFlight External Groups Automation Design

## Goal

Show TestFlight external testing readiness in ProjPost and let users distribute the latest approved TestFlight build without opening App Store Connect.

The app should read all TestFlight beta groups for the selected app, distinguish internal and external groups, show each external group's public link status, and support linking the current build to all external groups. By default, ProjPost should automatically link the latest build to external groups and enable public links after TestFlight beta review is approved. Users can turn this automation off and trigger the same operation manually.

## User Experience

In the existing `TestFlight Upload` section, replace the placeholder internal/public-link rows with a real `TestFlight Distribution` area.

Display:

- Current build status: version, build number, Apple processing state, and TestFlight beta review state.
- Automation toggle: `Auto link approved build to external groups`, default on for new projects.
- Internal testing summary: internal group names and whether the selected build is associated with each group.
- External testing list: one row per external beta group with name, current-build association status, public link status, and public link when available.
- Manual action button: `Link External Groups`, visible when the current build exists and external groups are available. It runs the same linking and public-link enablement flow used by automation.

When automation is on and the build review state becomes `Approved`, ProjPost should start the external group linking flow automatically after a status refresh. The UI must keep the user informed with running, success, partial failure, and failure states.

## Behavior

Status refresh should:

1. Resolve the selected App Store Connect app by bundle ID.
2. Resolve the current build by project version and build number.
3. Fetch all beta groups for the app.
4. Fetch the beta groups currently associated with the build.
5. Publish a single TestFlight distribution state that the UI can render.
6. If automation is enabled and the beta review state is approved, link the build to every external group and enable public links.

Manual linking should:

1. Require a selected project, Apple account, bundle ID, version, build number, and a resolved build.
2. Fetch external groups.
3. Add the build to each external group that is not already associated.
4. Enable each external group's public link if it is not already enabled.
5. Refresh distribution state after the operation so the UI shows links and final association status.

Internal groups should be read and displayed, but ProjPost should not enable public links for internal groups.

## Data Model

Add a project-level setting:

- `autoLinkExternalGroupsAfterBetaApproval: Bool`, default `true`.

Add a view-model distribution state:

- `idle`
- `loading`
- `loaded(TestFlightDistributionSnapshot)`
- `linking(TestFlightDistributionSnapshot?)`
- `failed(message: String)`

`TestFlightDistributionSnapshot` should include:

- App ID, build ID, version, build number.
- Processing state.
- Beta review state, converted to user-readable text.
- Internal groups.
- External groups.

Each group item should include:

- Group ID.
- Name.
- Internal/external flag.
- Whether the current build is associated with this group.
- Public link enabled.
- Public link URL.
- Public link limit, if present.
- Last operation status for this group when linking runs.

## App Store Connect API

Existing client support already covers:

- Fetch app by bundle ID.
- Fetch build by app version/build number.
- Fetch beta groups for the app.
- Add build to beta group.
- Enable beta group public link.

Add one missing read path:

- Fetch beta groups associated with a specific build.

Use App Store Connect build beta-group relationship APIs for that read. This lets the app show whether each internal or external group already has access to the current build instead of guessing from group existence alone.

## Error Handling

Status refresh failures should not clear upload console history. They should surface in the TestFlight distribution area.

Linking should be best-effort per external group:

- If one group fails, continue attempting the remaining groups.
- Mark failed groups individually.
- Show an overall partial-failure message.
- Keep successful group links visible.

If no external groups exist, show an empty state explaining that no external TestFlight groups were found.

If a public link is unavailable after enabling, show the group as linked but without a link, with a short message that Apple may still be processing the group link.

## Testing

Core tests:

- Fetching beta groups associated with a build maps internal and external group data.
- Refreshing TestFlight distribution state includes review state, internal groups, external groups, and current-build association flags.
- Approved build with automation enabled links external groups and enables public links.
- Automation disabled does not link groups during refresh.
- Manual linking links all external groups and enables public links.
- Partial group failures are captured without stopping remaining groups.
- Internal groups are never passed to public-link enablement.

UI-facing view-model tests:

- New projects default `autoLinkExternalGroupsAfterBetaApproval` to true.
- Toggling automation persists with the project profile.
- Distribution refresh does not reset upload console state.

Manual verification:

- Refresh status for an app with two external groups and confirm both appear.
- Confirm approved build auto-links external groups when the toggle is on.
- Turn the toggle off and confirm manual `Link External Groups` performs the operation.
- Confirm public TestFlight links are visible and copyable.
