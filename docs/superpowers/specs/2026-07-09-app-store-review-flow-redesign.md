# App Store Review Flow Redesign

## Goal

Rework JJPost's **App Store Review (提审商店)** section from four flat, order-ambiguous action buttons into a single **state-driven guided flow**: one primary call-to-action whose label and behavior follow the real review phase, backed by a readiness checklist and a single source of truth for status. This eliminates the current bugs where the UI shows contradictory state (stale version badge next to a "submitted" message), lets the user re-submit an already-submitted version, and offers no way to withdraw a submission.

The product principle is unchanged: let the user drive an App Store release **without logging into App Store Connect** for routine work.

## Scope

**In:**
- A combined `AppStoreReviewPhase` derived from both the App Store version state and the active review submission state — the single source of truth for all UI.
- A state-driven primary CTA: **提交审核 → 提交中… → 撤销提审 → 发布到 App Store** (and status-only phases with no CTA).
- Auto-bind the selected build as the first step of submit (no separate bind button).
- Reading the active review submission on refresh (fixes the hard-coded `reviewSubmissionState: nil`), including its cancelable state and ID.
- Withdraw / cancel a submission that is Waiting for Review or In Review.
- Release a `PENDING_DEVELOPER_RELEASE` version to the App Store from the app.
- Edit the release strategy (Manual ↔ Automatic-after-approval).
- A readiness checklist that blocks or warns with actionable reasons, replacing the silently-disabled button.
- Multi-step progress feedback during submit/cancel/release.
- Reloading the snapshot after every write, so status is always consistent.

**Out (unchanged from prior slice):**
- Screenshot upload/replacement. Existing screenshots stay **read-only**; a missing required screenshot is a **warning**, not a hard block.
- Scheduled-date (`SCHEDULED`) release editing. If a version already uses `SCHEDULED`, show it read-only; the editable picker offers only Manual and Automatic-after-approval.
- Any change to the TestFlight or upload flows.

## Global Constraints

- No new third-party dependencies.
- Every new user-facing string is added to `AppStrings` in **both** English and Simplified Chinese.
- All new logic lives in **ProjPostCore** with tests; `ProjectDetailView` stays a thin rendering layer that reads a phase/checklist computed in Core.
- Existing dirty worktree changes (the prior advanced-save slice) are work-in-progress and must not be reverted.
- Every new action method on `AppViewModel` early-returns on `guard !isOperationRunning` and reloads the snapshot on completion.

## State Model — the single source of truth

### `AppStoreReviewPhase` (new, in `DomainModels.swift`)

A pure enum derived from `(versionState, submissionState)`. UI reads only this.

```
enum AppStoreReviewPhase {
    case noVersion          // project version has no App Store version yet
    case editable           // can submit
    case submitting         // local in-flight submit
    case inReview           // submitted; cancelable
    case canceling          // cancel in flight (server CANCELING)
    case pendingDeveloperRelease  // approved, manual release pending
    case releasing          // release in flight / Apple releasing
    case live               // on sale / accepted
    case replaced           // superseded by a newer version
}
```

Derivation (pure function `AppStoreReviewPhase(versionState:submissionState:)`, fully unit-tested):

| Signal | Phase |
|---|---|
| version `PREPARE_FOR_SUBMISSION`, `DEVELOPER_REJECTED`, `REJECTED`, `METADATA_REJECTED`, `INVALID_BINARY`, `WAITING_FOR_EXPORT_COMPLIANCE` **and** no active submission | `editable` |
| submission `READY_FOR_REVIEW`, `WAITING_FOR_REVIEW`, `IN_REVIEW`, `UNRESOLVED_ISSUES` **or** version `WAITING_FOR_REVIEW` / `IN_REVIEW` | `inReview` |
| submission `CANCELING` | `canceling` |
| version `PENDING_DEVELOPER_RELEASE` | `pendingDeveloperRelease` |
| version `PENDING_APPLE_RELEASE`, `PROCESSING_FOR_APP_STORE` | `releasing` |
| version `READY_FOR_SALE` / `READY_FOR_DISTRIBUTION`, `ACCEPTED` | `live` |
| version `REPLACED_WITH_NEW_VERSION` | `replaced` |
| snapshot absent | `noVersion` |

The local `submitting` phase is expressed by the existing `AppStoreReviewState.submitting` case; the derived `AppStoreReviewPhase` covers the server-observed phases.

### Primary CTA state machine

One button, top-right of the section:

| Phase | Button | Enabled when | Action |
|---|---|---|---|
| `editable` | **提交审核** Submit for Review | readiness checklist has no red items | auto-bind → create/reuse submission → submit → reload |
| `submitting` | **提交中…** (spinner, sub-step text) | never (disabled) | — |
| `inReview` | **撤销提审** Withdraw (destructive, confirm) | always | PATCH submission `canceled:true` → reload |
| `canceling` | **撤销中…** (disabled) | never | — |
| `pendingDeveloperRelease` | **发布到 App Store** Release Now (confirm) | always | POST release request → reload |
| `releasing` / `live` / `replaced` / `noVersion` | no primary button | — | (see contextual actions) |

`noVersion` shows a contextual **创建 {version} 商店版本** button in the body (create is a write and never happens silently on refresh).

## Readiness checklist (`editable` phase)

Computed in Core as `[ReviewReadinessItem]` (title, severity, hint, isFixableInApp). Rendered as a ✓/⚠/✗ list; when any **red** item exists, the Submit button is disabled and the blockers are listed beneath it.

| Item | Severity | Fixable in app | Rule |
|---|---|---|---|
| Build selected & VALID | red | via build picker | a build is selected and its processing state is `VALID` |
| What's New filled | red / yellow | via advanced sheet | only when the version exposes a `whatsNew` field (i.e. not the app's first version): **red** if *no* locale has non-empty `whatsNew`; **yellow** per locale that is empty while others are filled |
| Review contact complete | red | via advanced sheet | `contactFirstName/LastName/Email/Phone` all present |
| Screenshots present | **yellow** | no (read-only this slice) | warn if the version has zero screenshots across its locales; do not claim a device-specific matrix and never block |
| Export compliance | green | n/a | builds archive with `ITSAppUsesNonExemptEncryption=NO`; if version is `WAITING_FOR_EXPORT_COMPLIANCE`, show red with hint |

## UI layout

```
┌ App Store 提审 ───────────────────────────────────────────────┐
│  1.2.6  [等待审核]  ← status badge (color by phase)   🔄刷新  ▸主CTA │
│                                                                │
│  商店版本 1.2.6   选择Build [3 · VALID ▾]   发布策略 [手动 ▾]   │
│                                                                │
│  提交就绪                                                       │
│   ✓ 构建可绑定 (Build 3 · VALID)                               │
│   ✓ 更新说明 zh-Hans 已填                                      │
│   ⚠ 截图缺 6.7" 机型 → 去 App Store Connect 补                  │
│   ✗ 审核联系信息不完整 → 点“编辑审核信息”补                     │
│                                                                │
│  审核信息  zhina · ye · mdc@… · +86…        [✎ 编辑审核信息]   │
│  商店语言  zh-Hans [已填]                      [🌐 管理语言]    │
└────────────────────────────────────────────────────────────────┘
```

- **Status badge** is the only status indicator (removes the "one-off message vs. version badge" conflict). Color: gray (editable), orange (inReview/canceling/releasing), blue (pendingDeveloperRelease), green (live).
- **刷新** is read-only and safe. **发布策略** is an inline picker (Manual / Automatic-after-approval; a pre-existing Scheduled shows read-only).
- **Removed** top-level buttons: 「创建/载入版本」(now contextual only when `noVersion`) and 「绑定所选 Build」(folded into Submit).

## API changes — `AppStoreConnectClient`

New protocol methods + minimal models + JSON mappers:

1. `fetchActiveReviewSubmission(appID:) -> ASCReviewSubmission?`
   `GET /v1/reviewSubmissions?filter[app]={appID}&filter[platform]=IOS`, pick the submission whose state is not `COMPLETE`; return id + state. Fills the previously hard-coded `reviewSubmissionState: nil` hole.
2. `cancelReviewSubmission(reviewSubmissionID:) -> ASCReviewSubmission`
   `PATCH /v1/reviewSubmissions/{id}` with `attributes.canceled = true`.
3. `updateAppStoreVersionReleaseType(appStoreVersionID:, releaseType:) -> ASCAppStoreVersion`
   `PATCH /v1/appStoreVersions/{id}` with `attributes.releaseType`.
4. `requestAppStoreVersionRelease(appStoreVersionID:) -> Void`
   `POST /v1/appStoreVersionReleaseRequests` with a relationship to the version.
5. `createReviewSubmissionItem` / `createReviewSubmission` gain **idempotent reuse**: submit reuses an existing `READY_FOR_REVIEW` submission and tolerates an already-present item instead of erroring on a duplicate `POST`.

## ViewModel changes — `AppViewModel`

- `loadAppStoreReviewSnapshot`: additionally call `fetchActiveReviewSubmission` and populate new snapshot fields `reviewSubmissionID` and a real `reviewSubmissionState`.
- `submitSelectedAppStoreReview`: reworked pipeline — (1) auto-bind selected build if not bound, (2) find/create the active submission (reuse dangling `READY_FOR_REVIEW`), (3) ensure the version item, (4) submit, (5) **reload snapshot**. Sub-steps surface as progress text.
- New: `cancelAppStoreReview()`, `updateAppStoreReviewReleaseType(_:)`, `releaseApprovedVersion()`. Each guards on `!isOperationRunning` and reloads the snapshot on completion.
- Keep the internal bind logic but remove `bindSelectedAppStoreReviewBuild` as a surfaced UI action.
- Expose the derived `AppStoreReviewPhase` and the readiness checklist to the view (computed in Core so the view is dumb and the logic is testable).

Snapshot (`AppStoreReviewSnapshot`) gains: `reviewSubmissionID: String?` and a populated `reviewSubmissionState`.

## Error handling & feedback

- Submit/cancel/release each show **sub-step progress text** on the CTA (e.g. 绑定构建… / 创建提审… / 提交…) instead of a generic "Working…". This addresses the "clicking does nothing" perception.
- Every action reloads the snapshot on success, so the badge, picker, and checklist never disagree.
- On failure, preserve the previous snapshot and show a red, actionable message (existing pattern). Re-submitting an already-active submission can no longer happen from the UI (phase gates it) and is additionally tolerated at the client layer.
- Withdraw and Release are destructive/irreversible-ish; both require an explicit confirm.

## Testing

Core tests (ProjPostCore) cover:
- `AppStoreReviewPhase` derivation for every `(versionState, submissionState)` combination in the table.
- Readiness checklist item computation (red/yellow/green, fixability) across missing build / missing what's-new / incomplete contact / missing screenshots.
- Client request paths + JSON bodies for: fetch active submission, cancel submission, patch release type, release request.
- Submit pipeline: auto-binds before submitting; reuses a dangling `READY_FOR_REVIEW` submission; tolerates a duplicate item; reloads snapshot afterward.
- Cancel, release-type change, and release-request each reload the snapshot and transition phase.
- Regression: after submit, the snapshot's version state and submission state are consistent (no stale badge).

UI stays a thin layer; no view logic beyond rendering the phase, badge, checklist, and CTA.
