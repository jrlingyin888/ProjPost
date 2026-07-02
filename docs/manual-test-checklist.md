# ProjPost MVP Task 10 手工验证清单

## 环境准备
- [ ] 使用 `xcode-select -p` 确认当前已指向可用 Xcode（输出应包含 Xcode.app 路径）
- [ ] 使用 `xcodebuild -version` 记录版本（例如 `Xcode ...`）
- [ ] 使用 `swift --version` 记录 Swift 工具链版本
- [ ] 进入仓库并确认文件存在：`test -f docs/manual-test-checklist.md`
- [ ] 在本地构建验证：`swift build`
  - 预期输出：构建成功，无关键失败日志
- [ ] 运行单测：`swift test`
  - 预期输出：所有测试通过（Exit code 0）
- [ ] 启动应用：`swift run ProjPostApp`
  - 预期输出：打开 macOS App 窗口（左侧项目列表、右侧项目详情）

## Apple API Key / Keychain
- [ ] 在 App 内的 `Apple Account` 区域新增/选择一个账号草稿（Display Name、Key ID、Issuer ID；Team ID 可选）
- [ ] 点击 `Import .p8` 导入本地 `.p8`（按钮在账号字段完整时可用）
- [ ] 完成后确认：UI 仅显示 `Key Saved`，不会在文本框里直接展示私钥内容
- [ ] 切换到另一个账号后可见 `Key Missing`，并确认不会泄露旧私钥
- [ ] 使用错误 Key ID / Issuer ID 运行检查
  - 预期：配置检查出现红色结果，上传被阻断
- [ ] 使用真实可用凭据重新跑检查
  - 预期：Apple API 相关项从“红/黄”回到可接受状态（或出现其他真实项目层问题）

## 项目导入与字段检查
- [ ] 在左侧输入真实项目名与路径，点击 `Add`，确认项目出现在卡片列表
- [ ] 在详情页点击 `Scan Project`
  - 预期：`workspacePath`/`projectFilePath` 自动识别（若存在）
  - 预期：`Scheme`、`Bundle ID`、`Version`、`Build`、`Team ID` 等字段被扫描填充
- [ ] 检查项目卡片 `v版本号 (build)` 与 `statusLabel` 能展示最近上传结果（首次为空时显示“未配置”）
- [ ] 修改字段后不要保存也能在内存中更新当前项目（并观察 `Run Checks` 提示文案变为“请重新检查”）
- [ ] 点击 `Save` 持久化后重启 App，再次确认列表/字段恢复成功

## 配置检查红黄绿
- [ ] 在 `Project Workbench` 填齐/确认 `project path/scheme/configuration/bundle id/version/build/team id`
- [ ] 点击 `Run Checks`
- [ ] 验证红黄绿结果：
  - 红色（red）：阻断上传，例如 Xcode 不可用、Bundle ID 不存在、缺失 Build Number、构建号重复
  - 黄色（yellow）：`Team ID 无法完全确认` 等提示，仅阻止自动继续上传
  - 绿色（green）：Xcode 可用、Bundle ID/App 找到、Build Number 可用
- [ ] 验证 `checksAreCurrent` 的行为：
  - 修改项目或账号字段后，上传前需再次运行检查
  - 黄色存在时点击 `Upload to TestFlight` 会弹出确认；点击 `Upload` 后才允许继续

## 上传流程
- [ ] 上传前确认配置检查无红色阻断项（如有黄色，先确认确认框）
- [ ] 点击 `Upload to TestFlight`
- [ ] 在 `Upload Console` 观察至少包含以下事件：
  - `archive`
  - `exportIPA`
  - `upload`
  - 每个事件状态有成功/失败标记且日志文本可回看
- [ ] 成功路径：
  - `Upload finished successfully.`
  - 项目卡片最近上传状态变为“最近上传成功”
  - 项目 summary 更新为当前 version/build + 时间
- [ ] 失败路径：
  - 观察 `Upload failed: ...` 和事件错误消息，能定位是哪个 step 失败
  - `UploadState` 维持失败信息，日志可用于复现修复
- [ ] 记录本地构建副产物是否可定位（`build/` 下 archive/export/ipa）供问题复核

## TestFlight 后续网页确认/待自动化
> 核心客户端已具备 App Store Connect 组和 public link API 方法（`fetchBetaGroups` / `addBuild` / `enablePublicLink`），但当前 UI 侧面板主要是占位提示，未完成一键自动化链路。

- [ ] 使用真实 App Store Connect 帐号登录 App Store Connect 网页
- [ ] 打开对应 App 的 TestFlight -> Builds，确认该版本 build 已出现（或在 processing）
- [ ] 手动按组织真实账号权限确认内部/外部可见范围
- [ ] 如果已配置内部/外部群组，手工执行：
  - 分配 build 到测试组
  - 对外部组开启并复制 public link（如需要）
- [ ] 将此部分行为补充为后续自动化验收项（V1 Follow-up）

## 安全与本地数据检查
- [ ] 本地账户元数据（`accounts.json` / `projects.json`）不应包含私钥明文
- [ ] 私钥仅保存在 Keychain（服务标识 `com.projpost.appstoreconnect`）
  - 可在系统钥匙串检索确认：查找匹配服务名项
  - 导出前台日志不应出现 `.p8` 原文
- [ ] 不要在代码库或仓库内新增 `.p8` 或真实账号密钥样例
- [ ] 在完成验证后手工确认 `swift test` 仍能通过，避免引入本地环境依赖性回归

## 已知限制 / V1 后续
- [ ] 项目变更能力（`ProjectMutator`）当前存在于 Core 层，但目前 UI 未暴露“变更摘要 + apply”独立按钮；本轮仅在文档中记录为手工验证后续项
- [ ] 上传阶段为本地打包/上传流程，未内建自动等待 Apple Processing / 自动分发验证 UI
- [ ] TestFlight 分组、外部 public link 的一键化目前是待自动化目标，不作为 MVP 必达项
- [ ] App Store 正式提审、组织权限细化、CI 分发流水线、iOS 设备端模拟安装等属于后续版本范围
