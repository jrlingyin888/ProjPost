# ProjPost Session Handoff - 2026-07-03

## 给新会话的第一句话

请先阅读本文件，并继续在仓库 `/Users/jerrypop/Documents/JR/Mac_sofeware/iOSProjPost` 工作。当前目标是继续推进 ProjPost 这个 macOS iOS/TestFlight 上传工具。上一轮已经完成 MVP 实现、本地合并、测试、打包，但 GitHub HTTPS push 因本机未配置凭据失败。

## 当前仓库状态

- 仓库路径：`/Users/jerrypop/Documents/JR/Mac_sofeware/iOSProjPost`
- 当前分支：`main`
- 当前 HEAD：`2bd33ae Allow cleared project fields to reach checks`
- 远程仓库：`https://github.com/jrlingyin888/ProjPost.git`
- 已清理临时 worktree：之前的 `.worktrees/ios-uploader-mvp` 已移除
- 当前未追踪/忽略产物：
  - `.build/`
  - `dist/`
  - `.DS_Store`
- 已生成本地 App：
  - `dist/ProjPost.app`
  - 可执行文件：`dist/ProjPost.app/Contents/MacOS/ProjPostApp`

## 已完成内容

本轮已经完成一个 SwiftUI + SwiftPM 的本地 macOS MVP：

- `ProjPostApp`：SwiftUI macOS UI
- `ProjPostCore`：可测试核心库
- 项目列表卡片、项目详情工作台
- Apple 账号元数据本地保存
- `.p8` 导入到 macOS Keychain，不在 JSON/UI/log 中展示私钥
- App Store Connect JWT signer 和 API client
- Xcode 项目扫描：workspace/project、scheme、Bundle ID、Version、Build、Team ID
- 配置检查：Xcode 环境、Bundle ID、App、Team ID、Build Number，红黄绿结果
- 红色检查阻止上传，黄色检查需要显式确认
- 项目字段修改需要先生成摘要并 `Apply Project Changes`
- `ProjectMutator` 已改为 XcodeProj-backed，避免全局字符串替换误改多个 target
- 修改项目文件前会备份
- 上传流程：archive、export IPA、发现 IPA、upload
- Keychain 中的 `.p8` 上传时会写入 per-run 临时目录，敏感写入使用 `0600` 权限，并在结束后清理
- `.app` 打包脚本：`scripts/package_app.sh`
- 手工验收清单：`docs/manual-test-checklist.md`

## 关键文档

- 设计文档：`docs/superpowers/specs/2026-07-02-ios-testflight-uploader-design.md`
- 实施计划：`docs/superpowers/plans/2026-07-02-ios-testflight-uploader-implementation.md`
- 手工测试清单：`docs/manual-test-checklist.md`
- 本 handoff：`docs/session-handoff-2026-07-03.md`

## 最近验证结果

在主工作区 `main` 上已经跑过：

```bash
swift test
```

结果：61 tests, 0 failures。

```bash
swift build
```

结果：Build complete。

```bash
bash -n scripts/package_app.sh
```

结果：exit code 0。

```bash
scripts/package_app.sh
```

结果：成功生成 `dist/ProjPost.app`。

## GitHub Push 状态

已经尝试过：

```bash
GIT_TERMINAL_PROMPT=0 git push -u origin main
```

失败原因：

```text
fatal: could not read Username for 'https://github.com': terminal prompts disabled
```

这不是代码问题，是本机 GitHub HTTPS 凭据/token 未配置。下一步可以让用户在本机配置 GitHub 凭据后执行：

```bash
git push -u origin main
```

如果用户希望继续由 Codex 推送，需要先确保当前 shell 能非交互访问 GitHub，例如配置 credential helper、GitHub CLI 登录，或使用可用的 token 认证方式。

## 后续建议

1. 先把本地 `main` push 到 GitHub。
2. 用真实 Apple Developer 账号按 `docs/manual-test-checklist.md` 试跑。
3. 重点验证 `.p8` 导入、Keychain 保存、真实项目扫描、Bundle ID/Build Number 检查。
4. 用一个小型真实 iOS 项目试 archive/export/upload。
5. TestFlight 分组、public link 自动化目前主要在客户端能力和文档层，UI 仍是后续增强重点。
6. 后续打包分发前需要考虑签名、notarization、图标、权限说明和更正式的 `.app` 发布流程。

## 注意点

- 不要把真实 `.p8`、Key ID、Issuer ID、Issuer 私钥内容提交到 git。
- `dist/` 和 `.build/` 是 ignored，不应提交。
- `.superpowers/` 是 ignored，不应提交任务报告。
- 当前 UI 允许产品路径使用 `.app`，开发者仍可用 `swift run ProjPostApp` 调试。
- `AppViewModel` 还有一个 minor 技术债：未标注 `@MainActor`，最终 review 认为不是 blocker。
