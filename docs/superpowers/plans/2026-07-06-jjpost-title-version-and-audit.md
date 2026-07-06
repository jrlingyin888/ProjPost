# JJPost Title Version And Audit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the app version next to the `JJPost` title and produce a prioritized product/code audit.

**Architecture:** Keep the version source in `ProductBranding`, render a compact title view from `ContentView`, and remove the duplicate sidebar version label from `ProjectListView`. The audit is documentation-only and should reference the current code structure and observed product flows.

**Tech Stack:** SwiftUI, Swift Package Manager, XCTest, Markdown documentation.

## Global Constraints

- Do not refactor `AppViewModel` in this pass.
- Do not change the GitHub Releases update mechanism.
- Keep the version text sourced from `ProductBranding.appVersionDisplay`.
- Preserve English and Simplified Chinese support.

---

### Task 1: Title Version UI

**Files:**
- Modify: `Sources/ProjPostApp/Views/ContentView.swift`
- Modify: `Sources/ProjPostApp/Views/ProjectListView.swift`
- Test: `Tests/ProjPostCoreTests/ProductBrandingTests.swift`

**Interfaces:**
- Consumes: `ProductBranding.displayName`, `ProductBranding.appVersionDisplay`
- Produces: A compact SwiftUI title view that displays `JJPost` beside `v1.1.0`

- [ ] **Step 1: Inspect current title and sidebar code**

Run:

```bash
sed -n '1,120p' Sources/ProjPostApp/Views/ContentView.swift
sed -n '118,160p' Sources/ProjPostApp/Views/ProjectListView.swift
```

Expected: `ContentView` uses `.navigationTitle(ProductBranding.displayName)` and `ProjectListView` shows `ProductBranding.appVersionDisplay` in the Add Project card.

- [ ] **Step 2: Add a compact title view**

In `Sources/ProjPostApp/Views/ContentView.swift`, replace the plain navigation title with a toolbar principal item:

```swift
.navigationTitle(ProductBranding.displayName)
.toolbar {
    ToolbarItem(placement: .principal) {
        appTitle
    }
}
```

Add:

```swift
private var appTitle: some View {
    HStack(spacing: 8) {
        Text(ProductBranding.displayName)
            .font(.headline.weight(.semibold))
        Text(ProductBranding.appVersionDisplay)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.quaternary.opacity(0.8), in: Capsule())
    }
    .lineLimit(1)
    .accessibilityElement(children: .combine)
}
```

- [ ] **Step 3: Remove the sidebar version label**

In `Sources/ProjPostApp/Views/ProjectListView.swift`, remove the `Spacer()` and `Text(ProductBranding.appVersionDisplay)` from the Add Project card header so the header only contains the Add Project label.

- [ ] **Step 4: Run targeted tests**

Run:

```bash
swift test --filter ProductBrandingTests
```

Expected: all filtered tests pass.

- [ ] **Step 5: Run full tests**

Run:

```bash
swift test
```

Expected: all tests pass.

### Task 2: Optimization Audit

**Files:**
- Create: `docs/jjpost-optimization-review-2026-07-06.md`

**Interfaces:**
- Consumes: Current source files and observed user flow issues.
- Produces: A prioritized audit with immediate fixes, next-version improvements, and later refactors.

- [ ] **Step 1: Inspect high-risk files**

Run:

```bash
wc -l Sources/ProjPostCore/AppState/AppViewModel.swift Sources/ProjPostApp/Views/ProjectDetailView.swift Sources/ProjPostCore/AppStoreConnect/AppStoreConnectClient.swift
rg -n "keychainStatus|fetchBuildsForBetaGroup|refreshLatestBuildTestFlightStatus|isOperationRunning|AppUpdateChecker" Sources Tests
```

Expected: output identifies large files and the current Keychain/TestFlight/update paths.

- [ ] **Step 2: Write the audit**

Create `docs/jjpost-optimization-review-2026-07-06.md` with these sections:

```markdown
# JJPost Optimization Review - 2026-07-06

## Immediate Fixes

## Next Version Improvements

## Later Refactors

## Suggested Removals Or Simplifications

## Suggested Priority Order
```

Each item should include the user impact and the recommended action.

- [ ] **Step 3: Review the audit for actionable wording**

Run:

```bash
rg -n "T[B]D|T[O]DO|FIX[M]E|PLACE[H]OLDER" docs/jjpost-optimization-review-2026-07-06.md
```

Expected: no matches.

### Task 3: Final Verification And Commit

**Files:**
- Modify: files changed by Tasks 1 and 2.

**Interfaces:**
- Consumes: test results from Task 1 and audit from Task 2.
- Produces: committed UI and audit changes.

- [ ] **Step 1: Review git diff**

Run:

```bash
git diff -- Sources/ProjPostApp/Views/ContentView.swift Sources/ProjPostApp/Views/ProjectListView.swift docs/jjpost-optimization-review-2026-07-06.md
```

Expected: diff only includes title version placement, sidebar version removal, and audit documentation.

- [ ] **Step 2: Commit**

Run:

```bash
git add Sources/ProjPostApp/Views/ContentView.swift Sources/ProjPostApp/Views/ProjectListView.swift docs/jjpost-optimization-review-2026-07-06.md docs/superpowers/plans/2026-07-06-jjpost-title-version-and-audit.md
git commit -m "feat: show version in app title"
```

Expected: commit succeeds.
