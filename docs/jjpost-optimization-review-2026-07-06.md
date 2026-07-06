# JJPost Optimization Review - 2026-07-06

这份清单基于当前代码结构、最近测试流程、以及这轮用户反馈整理。目标是帮助后续版本少走弯路：先修最影响使用信心的问题，再做体验增强，最后处理结构性重构。

## Immediate Fixes

1. Keychain 错误提示需要产品化
   - 用户影响：现在 `keychainStatus(-25293)` 这类错误会直接暴露给用户，用户很难知道这是 `.p8` 私钥读取授权失败，还是 App Store Connect 账号问题。
   - 建议动作：在 `AppViewModel.testFlightDistributionErrorMessage`、上传失败路径、账号密钥状态里统一转换 `CredentialVaultError.keychainStatus`。例如 `-25293`、`errSecAuthFailed`、`errSecInteractionNotAllowed` 显示为“钥匙串拒绝读取 .p8，请重新导入 .p8；如果仍失败，请删除旧钥匙串项后再导入”。
   - 相关文件：`Sources/ProjPostCore/Credentials/CredentialVault.swift`、`Sources/ProjPostCore/AppState/AppViewModel.swift`、`Sources/ProjPostCore/Localization/AppStrings.swift`。

2. `.p8` 状态不应只显示 Key Saved
   - 用户影响：当前 `privateKeyExists` 查询到条目属性就显示已保存，但真正读取私钥时仍可能被 Keychain 拒绝，导致“看起来已保存，刷新/上传却失败”。
   - 建议动作：新增“密钥可读取性检查”状态，把 `exists` 和 `readable` 区分开。账号卡片可显示 `Key Saved`、`Key Needs Reimport`、`Key Missing` 三种状态。
   - 相关文件：`Sources/ProjPostCore/Credentials/CredentialVault.swift`、`Sources/ProjPostCore/AppState/AppViewModel.swift`、`Sources/ProjPostApp/Views/ProjectDetailView.swift`。

3. 手工验证文档仍有旧名称
   - 用户影响：`docs/manual-test-checklist.md` 仍提到 `ProjPost.app`，和当前 `JJPost.app` 不一致，发布或产品交接时容易误导。
   - 建议动作：把 `ProjPost.app`、旧 Task 文案、旧按钮文案同步为 JJPost 当前流程，并补充 TestFlight 审核/外部测试组/多语言/更新提示的验证项。
   - 相关文件：`docs/manual-test-checklist.md`。

4. TestFlight 状态刷新失败时应保留旧快照
   - 用户影响：刷新失败后如果直接变成失败区域，用户可能看不到上次成功拉到的外部测试链接，无法判断是当前网络/钥匙串失败还是 TestFlight 状态丢失。
   - 建议动作：刷新失败时保留 `currentDistributionSnapshot`，只在顶部显示错误提示；不要清空已经显示的 internal/external group 列表和 public link。
   - 相关文件：`Sources/ProjPostCore/AppState/AppViewModel.swift`、`Sources/ProjPostApp/Views/ProjectDetailView.swift`。

5. 上传、刷新、提审按钮的并发状态还可以更明确
   - 用户影响：虽然很多控件已经用 `isOperationRunning` 禁用，但 UI 上还不容易区分“上传中”“刷新 TF 中”“提交审核中”“关联外部组中”。
   - 建议动作：把操作状态拆成明确枚举并映射到按钮 loading、禁用原因、console 文案。上传中保留转圈，刷新和提审也显示轻量 loading。
   - 相关文件：`Sources/ProjPostCore/AppState/AppViewModel.swift`、`Sources/ProjPostApp/Views/ProjectDetailView.swift`。

## Next Version Improvements

1. TestFlight 分发刷新需要提速
   - 用户影响：当前刷新会先取全部 beta groups，再对每个 group 调 `fetchBuildsForBetaGroup` 判断当前 build 是否已关联。外部组多时请求数会增长，刷新容易慢，也容易遇到 Apple API 限制。
   - 建议动作：做 bounded concurrency，最多同时请求 3 到 5 个 group；增加分页处理；失败的单个 group 不应让整个刷新失败，而是标记该 group 为无法确认。
   - 相关文件：`Sources/ProjPostCore/AppState/AppViewModel.swift`、`Sources/ProjPostCore/AppStoreConnect/AppStoreConnectClient.swift`、`Tests/ProjPostCoreTests/AppViewModelStateTests.swift`。

2. 外部测试组自动关联流程需要更细的状态
   - 用户影响：用户会按组选择“审核通过后自动关联”，但当前状态文字还可以更接近 Apple 后台，例如 Waiting for Review、Approved、Rejected、Linked、Public Link Enabled。
   - 建议动作：为每个 external group 保存 `autoLinkEnabled`、`linkState`、`publicLinkState`、`lastError`，界面上每组独立显示操作按钮和结果。
   - 相关文件：`Sources/ProjPostCore/Models/DomainModels.swift`、`Sources/ProjPostCore/AppState/AppViewModel.swift`、`Sources/ProjPostApp/Views/ProjectDetailView.swift`。

3. 更新检查可以直接指向 release asset
   - 用户影响：GitHub Releases 固定显示 Source code 下载项，用户容易点错。
   - 建议动作：`AppUpdateChecker` 解析 release assets，优先找到 `JJPost-<version>-dev-id.zip`，更新弹窗按钮打开 zip asset 下载地址或 release 页面中更明确的说明。
   - 相关文件：`Sources/ProjPostCore/Updates/AppUpdateChecker.swift`、`Sources/ProjPostApp/Views/ContentView.swift`。

4. 发布流程应补齐 notarization 版本
   - 用户影响：未公证包会触发 macOS 安全提示，给产品用户或外部测试用户的信任成本高。
   - 建议动作：保留 `dev-id` 快速包，同时增加 `notarized` 发布包流程：`notarytool submit`、`stapler staple`、`spctl` 验证，并在 release notes 标清楚。
   - 相关文件：`scripts/package_app.sh`、`scripts/release_zip.sh`、`docs/jjpost-update-release-flow.md`。

5. 多语言覆盖应加入 UI 文案基线测试
   - 用户影响：后续新增按钮或状态容易漏翻译，导致中英文混排。
   - 建议动作：为核心页面字符串建立 smoke test，至少覆盖项目列表、账号、上传、TestFlight、更新提示、Apple Account Guide。
   - 相关文件：`Sources/ProjPostCore/Localization/AppStrings.swift`、`Tests/ProjPostCoreTests/LocalizationTests.swift`。

## Later Refactors

1. 拆分 `AppViewModel`
   - 用户影响：当前 `AppViewModel.swift` 约 1393 行，同时处理项目、账号、上传、配置检查、TF 审核、外部组、更新检查。功能继续增长后，修一个流程容易影响另一个流程。
   - 建议动作：逐步拆成 `ProjectWorkbenchModel`、`AppleAccountModel`、`UploadCoordinator`、`TestFlightDistributionModel`、`UpdateModel`。先通过协议和单测保护行为，再移动代码。
   - 相关文件：`Sources/ProjPostCore/AppState/AppViewModel.swift`。

2. 拆分 `ProjectDetailView`
   - 用户影响：当前详情页约 716 行，账号、项目、上传、TF 分发混在一个 SwiftUI 文件里，后续布局修改容易产生局部回归。
   - 建议动作：拆出 `ProjectWorkbenchSection`、`AppleAccountSection`、`TestFlightUploadSection`、`TestFlightDistributionSection`、`UploadConsoleSection`。
   - 相关文件：`Sources/ProjPostApp/Views/ProjectDetailView.swift`。

3. App Store Connect API 错误模型需要类型化
   - 用户影响：现在很多错误最终显示为字符串，无法稳定区分权限不足、凭据失败、找不到 build、Apple 后台处理中、请求过多。
   - 建议动作：把 `AppStoreConnectError.badStatus` 的 JSON API error code/title/detail 解析成结构化类型，再由 `AppStrings` 映射用户文案。
   - 相关文件：`Sources/ProjPostCore/AppStoreConnect/AppStoreConnectClient.swift`。

4. 本地状态持久化可增加 schema version
   - 用户影响：后续项目字段、外部组设置、账号状态继续扩展时，旧 JSON 迁移可能靠 Codable 默认值隐式处理，不够可控。
   - 建议动作：给 `projects.json`、`accounts.json` 增加轻量 schema version 或迁移层，保留旧数据兼容。
   - 相关文件：`Sources/ProjPostCore/Storage/ProjectProfileStore.swift`、`Sources/ProjPostCore/Storage/AppleAccountProfileStore.swift`。

## Suggested Removals Or Simplifications

1. 移除过时的 Configuration Checks 独立心智
   - 当前方向已经是上传时自动跑配置检查，保留 console 输出即可。界面中如果还有旧的检查区域或旧文案，应继续收敛，减少用户以为必须先点检查再上传。

2. 减少“右上角 Save”的依赖
   - 项目字段和账号选择已经倾向自动保存。后续可以把 Save 改成状态提示或移除，只保留必要的显式动作，例如 Apply Project Changes、Import .p8、Upload。

3. 减少重复状态来源
   - 项目卡片状态、上传 console、TF 状态区、lastUpload 都在描述相近结果。建议定义一个唯一的 upload/testflight summary，再由各区域派生显示。

## Suggested Priority Order

1. 修 Keychain 错误文案和 `.p8` 可读取性状态。
2. 保留 TestFlight 刷新失败前的旧分发快照。
3. 更新手工验证文档和 release 文档中的旧名称/旧流程。
4. 优化 TestFlight 分发刷新请求和 per-group 错误隔离。
5. 解析 release assets，减少用户点到 Source code 的概率。
6. 做 notarized 发布包。
7. 拆 `AppViewModel` 和 `ProjectDetailView`。
