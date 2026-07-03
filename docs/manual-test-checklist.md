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
- [ ] 生成给产品用户使用的 App：`scripts/package_app.sh`
  - 预期输出：生成 `dist/ProjPost.app`
- [ ] 产品用户通过 Finder 或 `open dist/ProjPost.app` 打开应用
  - 预期输出：打开 macOS App 窗口（左侧项目列表、右侧项目详情）
- [ ] 开发者调试时可使用 `swift run ProjPostApp`；这不是产品用户交付路径

## Apple API Key / Keychain
- [ ] 在 App 内的 `Apple Account` 区域新增/选择一个账号草稿（Display Name、Key ID、Issuer ID；Team ID 可选）
- [ ] 点击 `Import Metadata` 导入包含 `Issuer ID` / `Key ID` / `Team ID` 的 `.txt` 或 `.rtf`
  - 预期：三个账号元数据字段被填充或更新，`.p8` 私钥状态不变化
- [ ] 点击 `Import .p8` 导入本地 `.p8`（按钮在账号字段完整时可用）
- [ ] 完成后确认：UI 仅显示 `Key Saved`，不会在文本框里直接展示私钥内容
- [ ] 切换到另一个账号后可见 `Key Missing`，并确认不会泄露旧私钥
- [ ] 使用错误 Key ID / Issuer ID 运行检查
  - 预期：配置检查出现红色结果，上传被阻断
- [ ] 使用真实可用凭据重新跑检查
  - 预期：Apple API 相关项从“红/黄”回到可接受状态（或出现其他真实项目层问题）

## 项目导入与字段检查
- [ ] 在左侧点击 `Choose Folder`，选择真实 iOS 项目目录
  - 预期：选择后自动扫描并把项目加入/选中到卡片列表
  - 预期：`workspacePath`/`projectFilePath` 自动识别（若存在）
  - 预期：`Scheme`、`Bundle ID`、`Version`、`Build`、`Team ID` 等字段被扫描填充
- [ ] 在详情页点击 `Scan Project`
  - 预期：重新扫描当前选中项目并刷新已识别字段
- [ ] 检查项目卡片 `v版本号 (build)` 与 `statusLabel` 能展示最近上传结果（首次为空时显示“未配置”）
- [ ] 修改字段后不要保存也能在内存中更新当前项目（并观察上传区提示需要先应用项目变更）
- [ ] 修改 Bundle ID / Version / Build 后确认出现变更摘要和 `Apply Project Changes`
- [ ] 不点击 `Apply Project Changes` 时运行检查或上传
  - 预期：检查和上传被阻止，提示先应用项目变更
- [ ] 点击 `Apply Project Changes`
  - 预期：先生成备份，再更新 Xcode project，变更摘要清空
- [ ] 点击 `Save` 持久化后重启 App，再次确认列表/字段恢复成功

## 配置检查红黄绿
- [ ] 在 `Project Workbench` 填齐/确认 `project path/scheme/configuration/bundle id/version/build/team id`
- [ ] 点击 `Upload to TestFlight` 后，在 `Upload Console` 验证配置检查摘要先输出：
  - 红色（red）：阻断上传，例如 Xcode 不可用、Bundle ID 不存在、缺失 Build Number、构建号重复
  - 黄色（yellow）：`Team ID 无法完全确认` 等提示，以 `[WARN]` 输出但继续上传
  - 绿色（green）：Xcode 可用、Bundle ID/App 找到、Build Number 可用，以 `[OK]` 输出
- [ ] 修改项目或账号字段后再次上传，确认上传会重新执行配置检查并更新 console

## 上传流程
- [ ] 点击 `Upload to TestFlight`
- [ ] 在 `Upload Console` 观察至少包含以下事件：
  - `checkBundleAndApp`
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

## TestFlight 外部测试组自动化
- [ ] 点击 `Refresh TF Status`
- [ ] 确认 `Internal Testing` 显示内部测试组
- [ ] 确认 `External Testing` 显示所有外部测试组
- [ ] 确认两个外部测试组显示各自 public link 或 pending 状态
- [ ] 保持 `Auto link approved build to external groups` 打开，等待/刷新到 `Approved` 后确认 app 自动关联所有外部组
- [ ] 关闭自动开关，点击 `Link External Groups`，确认无需打开网页即可关联外部测试组并启用 public link
- [ ] 确认失败的外部组会单独显示错误，成功的外部组链接仍保留

## 安全与本地数据检查
- [ ] 本地账户元数据（`accounts.json` / `projects.json`）不应包含私钥明文
- [ ] 私钥仅保存在 Keychain（服务标识 `com.projpost.appstoreconnect`）
  - 可在系统钥匙串检索确认：查找匹配服务名项
  - 导出前台日志不应出现 `.p8` 原文
- [ ] 不要在代码库或仓库内新增 `.p8` 或真实账号密钥样例
- [ ] 在完成验证后手工确认 `swift test` 仍能通过，避免引入本地环境依赖性回归

## 已知限制 / V1 后续
- [ ] `dist/ProjPost.app` 由开发者/运营人员运行 `scripts/package_app.sh` 产出后交付给产品用户；自动签名、公证、DMG/PKG 安装器属于后续版本范围
- [ ] 上传阶段为本地打包/上传流程，仍由用户点击刷新确认 Apple Processing / TF 审核状态
- [ ] App Store 正式提审、组织权限细化、CI 分发流水线、iOS 设备端模拟安装等属于后续版本范围
