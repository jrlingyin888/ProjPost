# iOS TestFlight 上传工具 Mac App 设计

日期：2026-07-02

## 目标

做一个 macOS 可视化工具，让产品或运营同事可以在不打开 Xcode、不手动跑脚本、不反复进 App Store Connect 网页的情况下，把 iOS 项目打包上传到 App Store Connect，并分发到 TestFlight 测试组。

第一版聚焦 TestFlight 上传和分发，不做 App Store 正式提审自动化。正式提审涉及隐私表单、出口合规、审核信息、发布策略等内容，适合后续单独做一层功能。

## 目标用户

- 产品或运营同事：拿到 iOS 项目后，需要负责上传 TestFlight。
- 开发同事：希望把已有脚本包装成更安全、更可控的 GUI。
- 未来远程使用者：可以从网页或手机触发任务，但真正打包仍由配置好的 Mac 执行。

## 第一版范围

### 包含

- 管理多个本地 iOS 项目。
- 导入 App Store Connect API 凭证：`.p8`、Key ID、Issuer ID。
- 将敏感凭证保存到 macOS Keychain。
- 自动识别项目常见配置：
  - 项目路径
  - `.xcworkspace` 或 `.xcodeproj`
  - Scheme 候选
  - Bundle ID
  - Version
  - Build Number
  - 可识别时读取 Team ID
- 允许用户在界面中修改 Bundle ID、Version、Build Number。
- 修改项目文件前自动备份。
- 如果项目是 Git 仓库，显示 Git 状态作为高级提示，但不要求产品人员理解或处理 Git。
- 调用 App Store Connect API 检查账号和项目匹配情况。
- 执行 archive、export、validate、upload。
- 上传后轮询 Apple 处理状态。
- 将处理完成的 build 加入选择的 TestFlight 测试组。
- 读取或开启外部测试组 public link。
- 展示产品可读的进度，同时保留详细命令日志。

### 不包含

- App Store 正式提审自动化。
- 云端保存 Apple 凭证。
- 直接在 iPhone 或 iPad 上打包。
- CI/CD 多机器构建集群。
- 复杂证书和描述文件管理系统。
- 对非常规 Xcode 工程做深度迁移。

## 技术方案

采用 **SwiftUI Mac App + 本地上传服务**。

SwiftUI App 负责：

- 项目列表和项目详情界面。
- Apple 账号导入和选择。
- 配置检查结果展示。
- 修改确认、上传确认和错误提示。
- 上传进度、日志、TestFlight 链接展示。

本地上传服务负责：

- 扫描项目配置。
- 修改项目文件。
- 从 Keychain 读取凭证。
- 生成 App Store Connect JWT。
- 调用 App Store Connect API。
- 执行 `xcodebuild`、导出 IPA、校验、上传。
- 管理长任务状态、日志流和取消任务。

这个方案对产品人员表现为一个普通 Mac 软件；对后续扩展来说，上传核心可以被网页或手机端复用。未来手机端只负责触发和查看状态，不复制 `.p8` 或其他 Apple 凭证到手机。

## 主界面设计

界面基于你提供的草图，采用左右两栏。

### 左侧：项目列表

左侧显示添加过的项目：

- 项目卡片。
- 添加项目卡片。
- 项目状态：
  - 未配置
  - 配置异常
  - 可上传
  - 上传中
  - 最近上传成功
  - 最近上传失败
- 最近一次上传版本，例如 `v1.0.0 (12)`。
- 删除项目放在右键菜单或更多按钮里，避免误删。

### 右侧：项目详情

右侧显示当前项目的完整上传工作台：

- 项目名称和路径。
- 项目基础配置。
- Apple 账号配置。
- 配置检查结果。
- TestFlight 分发设置。
- 上传进度和详细日志。

## 项目基础配置

项目配置区展示“当前读取到的值”和“准备应用的值”。

字段包括：

- Bundle ID
- Version
- Build Number
- Workspace 或 Project
- Scheme
- Configuration，默认 `Release`
- Team ID

Bundle ID、Version、Build Number 允许用户编辑。编辑后不会立即写入项目，用户需要点击“应用修改”。点击前展示变更摘要，点击后先备份相关文件，再修改项目。

## Apple 账号配置

Apple 账号区域包含：

- 账号档案名，例如“公司主账号”。
- `.p8` 导入按钮。
- Key ID。
- Issuer ID。
- 凭证验证状态。
- 最近验证时间。
- 能读取到时展示 Team 或账号摘要。

`.p8` 导入后存到 Keychain。界面只显示“已安全保存”，不显示完整私钥内容。项目配置里只引用账号档案，不保存原始私钥。

## 配置检查区

上传前必须先做配置检查。结果分为三类：

- 绿色：可继续。
- 黄色：建议确认，但允许继续。
- 红色：必须修复，上传按钮置灰。

检查项包括：

- Xcode 是否安装。
- Xcode 命令行工具是否可用。
- App Store Connect API Key 是否可认证。
- Bundle ID 是否存在于当前 Apple 账号下。
- Bundle ID 是否关联到 App Store Connect App。
- Team ID 是否匹配，或是否无法确定。
- Build Number 是否疑似重复。
- ExportOptions 是否可生成。
- 项目文件是否可备份。

红色问题必须解决后才能上传。黄色问题要求用户确认后继续。

## TestFlight 分发设计

上传成功并等 Apple 处理完成后，用户可以选择分发目标。

界面用产品更容易理解的词：

- 内部测试人员：App Store Connect 组织成员和内部测试组。
- 公开测试链接：外部测试组的 TestFlight public link。

不使用“内测链接 / 外测链接”作为核心概念，因为 public link 实际属于外部测试组。某个用户能看到哪个 build，取决于该 build 被分配到了哪些测试组。

外部测试组展示：

- 测试组名称。
- public link 是否开启。
- public link。
- 链接人数上限。
- 审核状态，例如等待审核、可测试、审核失败。

说明文案保持保守：

- 内部测试人员通常不需要 TestFlight App Review。
- 外部测试可能需要 TestFlight App Review。
- 同版本后续 build 可能处理更快，但最终以 Apple 状态为准。

## 上传流程

1. 用户添加或选择项目。
2. App 扫描项目，填充当前配置。
3. 用户选择 Apple 账号，或导入新的 `.p8`。
4. 用户点击“检查配置”。
5. App 执行本地环境检查和 App Store Connect API 检查。
6. 如果发现不匹配，用户修改 Bundle ID、Version 或 Build Number。
7. 用户点击“应用修改”。
8. App 备份项目文件并写入修改。
9. 用户选择 TestFlight 分发目标。
10. 用户点击“开始上传”。
11. 本地服务执行 archive、export、validate、upload。
12. App 显示进度和实时日志。
13. 本地服务轮询 Apple build 处理状态。
14. App 将 build 加入选择的 TestFlight 测试组。
15. App 展示最终状态和 public link 复制按钮。

## 项目文件修改策略

第一版支持直接修改原项目，因为目标用户可能不理解 Git 或命令行。

安全规则：

- 每次修改前自动备份。
- 修改前展示可读的变更摘要。
- Git 脏状态只作为高级提示，不阻断产品人员操作。
- 能用结构化方式修改时，不做脆弱的纯字符串替换。
- 第一版只修改上传所需的字段：Bundle ID、Version、Build Number，以及必要的 Team/签名字段。
- 如果项目结构太特殊，工具停止并给出人工处理提示，不强行猜测。

备份保存在 App 管理目录，包含：

- 项目名称
- 时间戳
- 被修改文件列表
- 原文件副本
- 修改摘要

## App Store Connect API 能力

本地服务通过 App Store Connect API 做这些事：

- 使用 `.p8`、Key ID、Issuer ID 生成 JWT。
- 根据 Bundle ID 查询 App。
- 根据 identifier 查询 Bundle ID。
- 查询已有 builds，用于判断 build number 是否可能冲突。
- 查询 beta groups。
- 将 build 加入 beta group。
- 在权限允许时读取或更新 public link 设置。
- 轮询 build processing state。

API 调用封装到 `AppStoreConnectClient`，便于测试，也便于 Apple 接口变化时替换实现。

## 打包和上传工具

本地服务使用 Xcode 工具链：

- `xcodebuild archive`
- `xcodebuild -exportArchive`
- 导出 IPA 时使用 App Store Connect API Key 参数。
- 上传阶段使用当前 Xcode 提供的 Apple 上传工具能力。

上传前检查：

- Xcode 路径。
- Xcode 版本。
- 命令行工具可用性。
- 项目路径存在。
- Scheme 可用。
- 签名和导出配置可用。

截至 2026-07-02，Apple 已要求 2026-04-28 之后上传到 App Store Connect 的 app 使用较新的 Xcode/SDK 构建。工具需要把 Xcode 版本放进环境检查，避免用户等到上传阶段才失败。

## 日志和进度

上传区域包含两层信息：

- 产品可读的步骤进度。
- 可折叠的详细命令日志。

进度步骤：

- 读取项目
- 验证账号
- 检查 Bundle ID 和 App
- 备份项目文件
- 应用项目修改
- Archive
- Export IPA
- Validate IPA
- Upload
- 等待 Apple 处理
- 加入 TestFlight 测试组
- 获取 public link

详细日志保留原始命令输出。发生错误时，主界面显示简短原因和下一步建议，详细日志自动定位到相关错误附近。

## 错误处理

常见错误要转换成可行动的 UI 状态：

- 未安装 Xcode：提示安装或选择 Xcode。
- API Key 无效：提示重新导入 `.p8`、Key ID 或 Issuer ID。
- Bundle ID 不存在：提示选择正确 Apple 账号或修改 Bundle ID。
- Bundle ID 未关联 App：提示去 App Store Connect 检查 App 是否存在。
- Build Number 已上传：提示递增 Build Number。
- 签名失败：展示 Team ID 和 provisioning 相关诊断。
- Archive 失败：展示摘要，并提供完整日志。
- Upload 失败：保留 IPA 路径，允许重试上传。
- TestFlight 审核中：显示等待状态，不当作失败。
- Public link 不可用：提示测试组可能未开启 public link，或 API Key 权限不足。

## 数据存储

非敏感数据：

- 项目档案。
- 最近上传历史。
- 最近选择的账号档案。
- UI 偏好。
- 备份元数据。

敏感数据：

- `.p8` 私钥内容。
- 未来可能产生的临时 token。

敏感数据必须保存在 macOS Keychain。JWT 按需生成，不持久化保存。

## 未来远程和移动端

本地服务后续可以开放一个需要授权的本地 HTTP API：

- 查看项目列表。
- 启动上传。
- 查看任务状态。
- 查看摘要日志。
- 获取 TestFlight public link。

远程或移动端必须遵守：

- Mac 仍是唯一构建机器。
- Mac 仍是唯一凭证持有方。
- 远程功能必须在 Mac App 中显式开启。
- 需要配对码或 token 授权。
- 默认先提供只读状态查看，上传操作需要额外确认。

## 测试策略

单元测试：

- 项目扫描。
- Version/Build 解析。
- 备份计划生成。
- App Store Connect JWT 生成。
- API 响应映射。
- 检查结果严重程度分类。

集成测试：

- Xcode 项目文件解析和修改。
- ExportOptions 生成。
- 使用 mock HTTP 测试 App Store Connect Client。
- 上传任务状态机。

真实手动测试：

- 导入真实 Apple API Key。
- 验证已知 Bundle ID。
- 上传一个小型真实项目到 TestFlight。
- 将 build 加入内部测试组。
- 将 build 加入外部测试组。
- 读取或开启 public link。
- 验证未加入组织的 Apple ID 只能看到外部测试组分配的 build。
- 验证组织/内部测试账号按 TestFlight 权限看到内部 build。

## 第一里程碑

第一里程碑是可用的本地 MVP：

- 项目档案。
- Keychain 账号档案。
- 配置检查。
- 带备份的项目直接修改。
- Archive/export/upload。
- Apple build processing 轮询。
- TestFlight 测试组分发。
- 外部测试组 public link 展示。

第一版 UI 可以先朴素，但必须让产品同事在不碰终端命令的情况下完成一次 TestFlight 上传和分发。
