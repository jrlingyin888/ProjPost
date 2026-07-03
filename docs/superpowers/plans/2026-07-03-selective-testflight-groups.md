# Selective TestFlight Groups Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace all-external-group TestFlight linking with per-external-group manual and automatic linking controls, and color TestFlight review status by Apple review state.

**Architecture:** Persist per-project external group automation preferences by beta group id. The view model filters manual and automatic linking to selected group ids, while SwiftUI renders per-group controls and status colors. Existing App Store Connect client calls remain unchanged.

**Tech Stack:** Swift, SwiftUI, XCTest, Swift Package Manager.

## Global Constraints

- New projects must not automatically link approved builds to every external group.
- Each external group must have its own manual link action.
- Each external group must have its own "auto after approval" toggle.
- Approved status is green, in-review/waiting status is yellow, rejected status is red.
- Run `swift test` before claiming completion.

---

### Task 1: Persist Per-Group Automation

**Files:**
- Modify: `Sources/ProjPostCore/Models/DomainModels.swift`
- Modify: `Tests/ProjPostCoreTests/AppViewModelStateTests.swift`

**Interfaces:**
- Produces: `ProjectProfile.autoLinkExternalGroupIDsAfterBetaApproval: Set<String>`
- Produces: `ProjectProfile.autoLinkExternalGroupsAfterBetaApproval == false` by default

- [ ] **Step 1: Write failing tests**

Add assertions that new projects default to no global automation and no selected group ids.

- [ ] **Step 2: Run tests**

Run: `swift test --filter AppViewModelStateTests`
Expected: FAIL before model changes.

- [ ] **Step 3: Implement model changes**

Add the set property, coding key, initializer argument, decode fallback, and encode behavior.

- [ ] **Step 4: Run tests**

Run: `swift test --filter AppViewModelStateTests`
Expected: PASS.

### Task 2: Link Selected Groups Only

**Files:**
- Modify: `Sources/ProjPostCore/AppState/AppViewModel.swift`
- Modify: `Tests/ProjPostCoreTests/AppViewModelStateTests.swift`

**Interfaces:**
- Produces: `updateAutoLinkExternalGroup(_ groupID: String, isEnabled: Bool)`
- Produces: `linkExternalGroupForLatestBuild(groupID: String) async`
- Changes: approved-build automation links only ids in `autoLinkExternalGroupIDsAfterBetaApproval`

- [ ] **Step 1: Write failing tests**

Add tests for approved build linking only selected ids and manual linking only one id.

- [ ] **Step 2: Run tests**

Run: `swift test --filter AppViewModelStateTests`
Expected: FAIL before view model changes.

- [ ] **Step 3: Implement view model changes**

Filter `linkExternalGroups` by target ids, add per-group methods, persist toggle changes.

- [ ] **Step 4: Run tests**

Run: `swift test --filter AppViewModelStateTests`
Expected: PASS.

### Task 3: Render Per-Group Controls And Status Colors

**Files:**
- Modify: `Sources/ProjPostApp/Views/ProjectDetailView.swift`

**Interfaces:**
- Consumes: `updateAutoLinkExternalGroup(_:isEnabled:)`
- Consumes: `linkExternalGroupForLatestBuild(groupID:)`
- Produces: per-group `Link Build` button and `Auto after approval` toggle
- Produces: status text color mapping green/yellow/red

- [ ] **Step 1: Implement SwiftUI controls**

Remove the global all-groups button from the distribution header and render controls only for external groups.

- [ ] **Step 2: Compile and test**

Run: `swift test`
Expected: PASS.

### Task 4: Package And Commit

**Files:**
- Package output: `dist/JJPost.app`

- [ ] **Step 1: Build package**

Run: `scripts/package_app.sh`
Expected: signed `dist/JJPost.app`.

- [ ] **Step 2: Verify signature**

Run: `codesign --verify --deep --strict --verbose=2 dist/JJPost.app`
Expected: valid on disk and satisfies designated requirement.

- [ ] **Step 3: Commit**

Run: `git add ... && git commit -m "feat: select TestFlight external groups"`
