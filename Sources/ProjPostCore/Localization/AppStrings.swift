import Foundation

public struct AppStrings: Equatable {
    public var language: AppLanguage

    public init(language: AppLanguage) {
        self.language = language
    }

    private func text(_ english: String, _ simplifiedChinese: String) -> String {
        switch language {
        case .english:
            return english
        case .simplifiedChinese:
            return simplifiedChinese
        }
    }

    public var languageTitle: String { text("Language", "语言") }
    public var projectsTitle: String { text("Projects", "项目") }
    public var selectProjectsTitle: String { text("Select Projects", "选择项目") }
    public var projectsSubtitle: String { text("Choose a workbench or add a new upload target.", "选择工作台，或添加新的上传目标。") }
    public var selectProjectsSubtitle: String { text("Choose projects to remove.", "选择要移除的项目。") }
    public var deleteProjects: String { text("Delete Projects", "删除项目") }
    public var more: String { text("More", "更多") }
    public var addProject: String { text("Add Project", "添加项目") }
    public var chooseFolder: String { text("Choose Folder", "选择文件夹") }
    public var scanning: String { text("Scanning", "扫描中") }
    public var chooseOrDropProjectFolderHelp: String { text("Choose or drop a project folder", "选择或拖入项目文件夹") }
    public var cancel: String { text("Cancel", "取消") }
    public var close: String { text("Close", "关闭") }
    public var delete: String { text("Delete", "删除") }
    public var deleteSelectedProjectsTitle: String { text("Delete Selected Projects?", "删除选中的项目？") }
    public var selectAProject: String { text("Select a project", "选择项目") }
    public var selectProjectPrompt: String { text("Choose a project from the sidebar or add one.", "从侧边栏选择项目，或添加一个项目。") }
    public var load: String { text("Load", "加载") }
    public var save: String { text("Save", "保存") }
    public var later: String { text("Later", "稍后") }
    public var updateAvailableTitle: String { text("Update Available", "发现新版本") }
    public var downloadUpdate: String { text("Download Update", "下载更新") }

    public func updateAvailableMessage(currentVersion: String, latestVersion: String) -> String {
        text(
            """
            JJPost \(latestVersion) is available. You are using \(currentVersion).

            Installation is manual: quit JJPost, download the zip, unzip it, replace the old JJPost.app, then reopen JJPost.
            """,
            """
            JJPost \(latestVersion) 已可用。当前版本是 \(currentVersion)。

            安装需要手动完成：退出 JJPost，下载 zip，解压后替换旧的 JJPost.app，然后重新打开 JJPost。
            """
        )
    }

    public var projectWorkbench: String { text("Project Workbench", "项目工作台") }
    public var name: String { text("Name", "名称") }
    public var projectPath: String { text("Project Path", "项目路径") }
    public var bundleID: String { text("Bundle ID", "Bundle ID") }
    public var version: String { text("Version", "版本") }
    public var build: String { text("Build", "构建号") }
    public var teamID: String { text("Team ID", "Team ID") }
    public var scheme: String { text("Scheme", "Scheme") }
    public var configuration: String { text("Configuration", "Configuration") }
    public var projectChangesNotApplied: String { text("Project changes are not applied to disk yet.", "项目变更还没有写入磁盘。") }
    public var applyProjectChanges: String { text("Apply Project Changes", "应用项目变更") }
    public var scanProject: String { text("Scan Project", "扫描项目") }

    public var appleAccount: String { text("Apple Account", "Apple 账号") }
    public var guide: String { text("Guide", "指引") }
    public var appleAccountGuideHelp: String {
        text("How to find .p8, Key ID, Issuer ID, and Team ID", "如何找到 .p8、Key ID、Issuer ID 和 Team ID")
    }
    public var savedAccount: String { text("Saved Account", "已保存账号") }
    public var none: String { text("None", "无") }
    public var currentAccount: String { text("Current Account", "当前账号") }
    public var account: String { text("Account", "账号") }
    public var keyID: String { text("Key ID", "Key ID") }
    public var issuerID: String { text("Issuer ID", "Issuer ID") }
    public var editAccount: String { text("Edit Account", "编辑账号") }
    public var saveAccount: String { text("Save Account", "保存账号") }
    public var importMetadata: String { text("Import Metadata", "导入元数据") }
    public var importP8: String { text("Import .p8", "导入 .p8") }
    public var keySaved: String { text("Key Saved", "密钥已保存") }
    public var keyMissing: String { text("Key Missing", "缺少密钥") }
    public var keyFailed: String { text("Key Failed", "密钥异常") }

    public var testFlightUpload: String { text("TestFlight Upload", "TestFlight 上传") }
    public var uploadToTestFlight: String { text("Upload to TestFlight", "上传到 TestFlight") }
    public var uploading: String { text("Uploading...", "上传中...") }
    public var working: String { text("Working...", "处理中...") }
    public var refreshTFStatus: String { text("Refresh TF Status", "刷新 TF 状态") }
    public var submitToBetaReview: String { text("Submit to Beta Review", "提交 Beta 审核") }
    public var configurationChecksRunAutomatically: String {
        text("Configuration checks run automatically when upload starts.", "点击上传后会自动执行配置检查。")
    }
    public var applyProjectChangesBeforeChecksOrUploading: String {
        text("Apply project changes before running checks or uploading.", "请先应用项目变更，再执行检查或上传。")
    }
    public var runChecksAgainAfterChanges: String {
        text("Run checks again after any project, account, or key change.", "项目、账号或密钥变更后请重新检查。")
    }
    public var checksCurrent: String { text("Checks are current for this project and Apple account.", "当前项目和 Apple 账号的检查已是最新。") }
    public var noChecksRun: String { text("No checks run yet.", "还没有执行检查。") }
    public var internalTesters: String { text("Internal testers", "内部测试员") }
    public var availableAfterNextUpload: String { text("Available after the next successful upload", "下次成功上传后可用") }
    public var publicTestFlightLink: String { text("Public TestFlight link", "公开 TestFlight 链接") }
    public var createPublicLinkAfterProcessing: String {
        text("Create a public link after Apple finishes processing", "Apple 处理完成后创建公开链接")
    }
    public var testFlightDistribution: String { text("TestFlight Distribution", "TestFlight 分发") }
    public var refreshTFStatusToLoadTesterGroups: String {
        text("Refresh TF Status to load tester groups.", "刷新 TF 状态以加载测试组。")
    }
    public var loadingTestFlightGroups: String { text("Loading TestFlight groups...", "正在加载 TestFlight 测试组...") }
    public var linkingExternalTestFlightGroups: String { text("Linking external TestFlight groups...", "正在关联外部 TestFlight 测试组...") }
    public var currentBuild: String { text("Current build", "当前构建版本") }
    public var internalTesting: String { text("Internal Testing", "内部测试") }
    public var externalTesting: String { text("External Testing", "外部测试") }
    public var externalGroups: String { text("External groups", "外部测试组") }
    public var noInternalGroups: String { text("No internal groups found.", "未找到内部测试组。") }
    public var noExternalGroups: String { text("No external TestFlight groups found.", "未找到外部 TestFlight 测试组。") }
    public var linkBuild: String { text("Link Build", "关联构建") }
    public var autoAfterApproval: String { text("Auto after approval", "审核通过后自动关联") }
    public var internalGroupStatus: String { text("Internal", "内部") }
    public var linkOn: String { text("Link On", "已开启链接") }
    public var linkOff: String { text("Link Off", "未开启链接") }
    public var linked: String { text("Linked", "已关联") }
    public var notLinked: String { text("Not Linked", "未关联") }
    public var publicLinkPendingFromApple: String { text("Public link pending from Apple.", "公开链接等待 Apple 生成。") }
    public var publicLinkNotEnabled: String { text("Public link not enabled.", "公开链接未开启。") }

    public var appStoreReview: String { text("App Store Review", "App Store 提审") }
    public var refreshStoreStatus: String { text("Refresh Store Status", "刷新商店状态") }
    public var prepareStoreVersion: String { text("Create/Load Version", "创建/载入版本") }
    public var bindSelectedBuild: String { text("Bind Selected Build", "绑定所选 Build") }
    public var submitStoreReview: String { text("Submit Store Review", "提交商店审核") }
    public var storeVersion: String { text("Store version", "商店版本") }
    public var selectedBuild: String { text("Selected Build", "选择 Build") }
    public var releaseStrategy: String { text("Release strategy", "发布策略") }
    public var manualRelease: String { text("Manual", "手动") }
    public var afterApprovalRelease: String { text("After Approval", "通过后自动") }
    public var scheduledRelease: String { text("Scheduled", "定时") }
    public var buildBound: String { text("Build bound", "构建已绑定") }
    public var buildNotBound: String { text("Build not bound", "构建未绑定") }
    public var appStoreReviewInfo: String { text("Review Information", "审核信息") }
    public var editReviewInfo: String { text("Edit Review Info", "编辑审核信息") }
    public var storeLocalizations: String { text("Store Localizations", "商店语言") }
    public var storeLocalizationsSubtitle: String {
        text("App Store-facing localizations, separate from in-app languages", "App Store 对外多语言，不影响 App 内语言")
    }
    public var manageLanguages: String { text("Manage Languages", "管理语言") }
    public var whatsNew: String { text("What's New", "版本更新说明") }
    public var needsUpdate: String { text("Needs Update", "需更新") }
    public var filled: String { text("Filled", "已填") }
    public var advancedStoreFields: String { text("Advanced: description / keywords / screenshots", "高级：描述 / 关键词 / 截图") }
    public var appStoreDescription: String { text("Description", "描述") }
    public var appStoreKeywords: String { text("Keywords", "关键词") }
    public var appStorePromotionalText: String { text("Promotional Text", "宣传文本") }
    public var appStoreSupportURL: String { text("Support URL", "支持 URL") }
    public var appStoreMarketingURL: String { text("Marketing URL", "营销 URL") }
    public var appStoreScreenshots: String { text("Screenshots", "截图") }
    public var chooseScreenshots: String { text("Choose Screenshots", "选择截图") }
    public var existingScreenshots: String { text("Existing Screenshots", "已有截图") }
    public var noScreenshots: String { text("No screenshots", "暂无截图") }
    public var localDraft: String { text("Local Draft", "本地草稿") }
    public var contactInfo: String { text("Contact", "联系信息") }
    public var demoAccount: String { text("Demo Account", "Demo 账号") }
    public var reviewNotes: String { text("Review Notes", "审核备注") }
    public var requiresLogin: String { text("Requires Login", "需要登录") }
    public var firstName: String { text("First Name", "名字") }
    public var lastName: String { text("Last Name", "姓氏") }
    public var phone: String { text("Phone", "电话") }
    public var email: String { text("Email", "邮箱") }
    public var password: String { text("Password", "密码") }
    public var showPassword: String { text("Show Password", "显示密码") }
    public var hidePassword: String { text("Hide Password", "隐藏密码") }
    public var appStoreReviewNoVersionLoaded: String {
        text("Refresh status or create/load a store version first.", "请先刷新状态，或创建/载入商店版本。")
    }
    public var appStoreReviewSafeActionHint: String {
        text("The first two actions update App Store Connect version data, but do not submit for review.", "前两步会更新 App Store Connect 版本资料，但不会提交审核。")
    }
    public var appStoreReviewStatusSubmitted: String { text("Submitted", "已提交") }

    public var uploadConsole: String { text("Upload Console", "上传控制台") }
    public var noUploadEvents: String { text("No upload events yet.", "还没有上传事件。") }
    public var idle: String { text("Idle", "空闲") }
    public var cancelled: String { text("Cancelled", "已取消") }
    public var updatingTestFlightStatus: String { text("Updating TestFlight status...", "正在更新 TestFlight 状态...") }

    public var projectStatusNotConfigured: String { text("Not Configured", "未配置") }
    public var projectStatusLastUploadSucceeded: String { text("Last Upload Succeeded", "最近上传成功") }
    public var projectStatusLastUploadFailed: String { text("Last Upload Failed", "最近上传失败") }

    public var betaReviewStatusWaitingForReview: String { text("Waiting for Review", "正在等待审核") }
    public var betaReviewStatusInReview: String { text("In Review", "审核中") }
    public var betaReviewStatusApproved: String { text("Approved", "已通过") }
    public var betaReviewStatusRejected: String { text("Rejected", "已拒绝") }
    public var betaReviewStatusSubmitted: String { text("Submitted", "已提交") }
    public var betaReviewStatusNotSubmitted: String { text("Not Submitted", "未提交") }

    public var configurationCheckXcodeAvailableTitle: String { text("Xcode Available", "Xcode 可用") }
    public var configurationCheckXcodeUnavailableTitle: String { text("Xcode Unavailable", "Xcode 不可用") }
    public var configurationCheckRsyncUnavailableTitle: String { text("rsync Unavailable", "rsync 不可用") }
    public var configurationCheckBundleIDMissingTitle: String { text("Bundle ID Missing", "Bundle ID 缺失") }
    public var configurationCheckBundleIDNotFoundTitle: String { text("Bundle ID Not Found", "Bundle ID 不存在") }
    public var configurationCheckBundleIDFoundTitle: String { text("Bundle ID Found", "Bundle ID 已找到") }
    public var configurationCheckAppNotFoundTitle: String { text("App Not Found", "App 不存在") }
    public var configurationCheckAppMatchedTitle: String { text("App Matched", "App 匹配") }
    public var configurationCheckTeamIDMismatchTitle: String { text("Team ID Mismatch", "Team ID 不匹配") }
    public var configurationCheckTeamIDUnconfirmedTitle: String { text("Team ID Not Fully Confirmed", "Team ID 无法完全确认") }
    public var configurationCheckTeamIDMatchedTitle: String { text("Team ID Matched", "Team ID 匹配") }
    public var configurationCheckBuildNumberAvailableTitle: String { text("Build Number Available", "Build Number 可用") }
    public var configurationCheckBuildNumberMayDuplicateTitle: String { text("Build Number May Duplicate", "Build Number 可能重复") }
    public var configurationCheckBuildNumberMissingTitle: String { text("Build Number Missing", "Build Number 缺失") }
    public var configurationCheckAppleAccountFailedTitle: String { text("Apple Account Check Failed", "Apple 账号检查失败") }

    public var configurationCheckInstallOrSelectXcodeMessage: String {
        text("Install or select Xcode.", "请安装或选择 Xcode")
    }

    public var configurationCheckRsyncRequiredMessage: String {
        text("xcodebuild exportArchive requires rsync. Confirm /usr/bin is available in PATH.", "xcodebuild exportArchive 需要 rsync，请确认 /usr/bin 在 PATH 中")
    }

    public var configurationCheckXcodeCommandLineMessage: String {
        text("Install Xcode and confirm command line tools are available.", "请安装 Xcode 并确认命令行工具可用")
    }

    public var configurationCheckBundleIDMissingMessage: String {
        text("Enter Bundle ID and check again.", "请填写 Bundle ID 后重新检查")
    }

    public func configurationCheckBundleIDNotFoundMessage(_ bundleID: String) -> String {
        text("No Bundle ID found for \(bundleID) under the current Apple account.", "当前 Apple 账号下没有找到 \(bundleID)")
    }

    public var configurationCheckAppNotFoundMessage: String {
        text("Bundle ID is not linked to an App Store Connect app.", "Bundle ID 未关联到 App Store Connect App")
    }

    public func configurationCheckTeamIDMismatchMessage(projectTeamID: String, accountTeamID: String) -> String {
        text("Project is \(projectTeamID), account is \(accountTeamID).", "项目为 \(projectTeamID)，账号为 \(accountTeamID)")
    }

    public var configurationCheckTeamIDUnconfirmedMessage: String {
        text("You can continue, but confirm the signing team is correct.", "可以继续，但建议确认签名团队正确")
    }

    public func configurationCheckBuildNumberDuplicateMessage(_ buildLabel: String) -> String {
        text("App Store Connect already has \(buildLabel). Increment it before uploading.", "App Store Connect 已存在 \(buildLabel)，请递增后再上传")
    }

    public var configurationCheckBuildNumberMissingMessage: String {
        text("Enter Build Number.", "请填写 Build Number")
    }

    public var completeAppleAccountFieldsBeforeSaving: String {
        text("Complete the Apple account fields before saving.", "请先补全 Apple 账号字段再保存。")
    }

    public var failedToSaveAppleAccount: String {
        text("Failed to save Apple account.", "保存 Apple 账号失败。")
    }

    public var failedToReadPrivateKeyFile: String {
        text("Failed to read the App Store Connect private key file.", "读取 App Store Connect 私钥文件失败。")
    }

    public var invalidPrivateKeyFile: String {
        text("Imported file does not contain a valid App Store Connect private key.", "导入的文件不包含有效的 App Store Connect 私钥。")
    }

    public var completeAppleAccountBeforeImportingPrivateKey: String {
        text("Complete the Apple account fields before importing a private key.", "请先补全 Apple 账号字段再导入私钥。")
    }

    public var failedToSavePrivateKey: String {
        text("Failed to save the App Store Connect private key.", "保存 App Store Connect 私钥失败。")
    }

    public var selectProjectBeforeRunningChecks: String {
        text("Select a project before running checks.", "请先选择项目再执行检查。")
    }

    public var applyProjectChangesBeforeRunningChecks: String {
        text("Apply project changes before running checks.", "请先应用项目变更再执行检查。")
    }

    public var selectOrEnterAppleAccountBeforeRunningChecks: String {
        text("Select or enter an Apple account before running checks.", "请先选择或输入 Apple 账号再执行检查。")
    }

    public var configurationChecksFoundBlockingIssues: String {
        text("Configuration checks found blocking issues.", "配置检查发现阻断问题。")
    }

    public var selectProjectBeforeUpload: String {
        text("Select a project before starting upload.", "请先选择项目再开始上传。")
    }

    public var selectOrEnterAppleAccountBeforeUploading: String {
        text("Select or enter an Apple account before uploading.", "请先选择或输入 Apple 账号再上传。")
    }

    public var applyProjectChangesBeforeUploading: String {
        text("Apply project changes before uploading.", "请先应用项目变更再上传。")
    }

    public var uploadBlockedByConfigurationIssues: String {
        text("Upload blocked by configuration issues. Resolve red checks before uploading.", "上传被配置问题阻止。请先解决红色检查项再上传。")
    }

    public var uploadFinishedSuccessfully: String {
        text("Upload finished successfully.", "上传成功完成。")
    }

    public func uploadFailed(_ error: Error) -> String {
        text("Upload failed: \(error)", "上传失败：\(error)")
    }

    public var selectProjectBeforeSubmittingReview: String {
        text("Select a project before submitting TestFlight review.", "请先选择项目再提交 TestFlight 审核。")
    }

    public var selectAppleAccountBeforeSubmittingReview: String {
        text("Select an Apple account before submitting TestFlight review.", "请先选择 Apple 账号再提交 TestFlight 审核。")
    }

    public var bundleVersionBuildRequiredBeforeSubmittingReview: String {
        text("Bundle ID, version, and build number are required before submitting review.", "提交审核前需要 Bundle ID、版本和构建号。")
    }

    public func appStoreConnectAppNotFound(_ bundleID: String) -> String {
        text("App Store Connect app not found for \(bundleID).", "App Store Connect 中未找到 \(bundleID) 对应的 App。")
    }

    public func uploadedBuildNotFound(version: String, buildNumber: String) -> String {
        text("Uploaded build \(version) (\(buildNumber)) was not found in App Store Connect yet.", "App Store Connect 暂未找到已上传的构建 \(version) (\(buildNumber))。")
    }

    public func buildProcessingNotValid(version: String, buildNumber: String, processingState: String) -> String {
        text("Build \(version) (\(buildNumber)) is \(processingState). Wait until Apple processing is VALID.", "构建 \(version) (\(buildNumber)) 当前为 \(processingState)，请等待 Apple 处理为 VALID。")
    }

    public func submittedToTestFlightReview(state: String) -> String {
        text("Submitted to TestFlight review. State: \(state)", "已提交 TestFlight 审核。状态：\(state)")
    }

    public func submitToTestFlightReviewFailed(_ error: Error) -> String {
        text("Submit to TestFlight review failed: \(error)", "提交 TestFlight 审核失败：\(error)")
    }

    public var selectProjectBeforeRefreshingTestFlightStatus: String {
        text("Select a project before refreshing TestFlight status.", "请先选择项目再刷新 TestFlight 状态。")
    }

    public var selectAppleAccountBeforeRefreshingTestFlightStatus: String {
        text("Select an Apple account before refreshing TestFlight status.", "请先选择 Apple 账号再刷新 TestFlight 状态。")
    }

    public var bundleVersionBuildRequiredBeforeRefreshingStatus: String {
        text("Bundle ID, version, and build number are required before refreshing status.", "刷新状态前需要 Bundle ID、版本和构建号。")
    }

    public var bundleVersionBuildRequiredBeforeRefreshingDistribution: String {
        text(
            "Bundle ID, version, and build number are required before refreshing TestFlight distribution.",
            "刷新 TestFlight 分发信息前需要 Bundle ID、版本和构建号。"
        )
    }

    public func linkedExternalGroupsWithFailureCount(_ count: Int) -> String {
        text("Linked external groups with \(count) failure.", "关联外部测试组时出现 \(count) 个失败。")
    }

    public func testFlightStatus(_ status: String) -> String {
        text("TestFlight status: \(status)", "TestFlight 状态：\(status)")
    }

    public func testFlightStatus(_ status: String, processingState: String) -> String {
        text("TestFlight status: \(status). Build processing: \(processingState)", "TestFlight 状态：\(status)。构建处理状态：\(processingState)")
    }

    public func refreshTestFlightDistributionFailed(_ error: Error) -> String {
        text("Refresh TestFlight distribution failed: \(error)", "刷新 TestFlight 分发信息失败：\(error)")
    }

    public var bundleVersionRequiredBeforeAppStoreReview: String {
        text("Bundle ID and version are required before App Store review actions.", "执行 App Store 提审操作前需要 Bundle ID 和版本号。")
    }

    public func appStoreVersionNotFound(_ version: String) -> String {
        text("App Store version \(version) was not found. Create/load the version first.", "未找到商店版本 \(version)。请先创建/载入版本。")
    }

    public var selectBuildBeforeAppStoreReviewAction: String {
        text("Select a build before continuing.", "请先选择一个 Build。")
    }

    public var loadAppStoreVersionBeforeAction: String {
        text("Create or load an App Store version before continuing.", "请先创建或载入商店版本。")
    }

    public var bindSelectedBuildBeforeSubmittingAppStoreReview: String {
        text("Bind the selected build before submitting App Store review.", "提交商店审核前请先绑定所选 Build。")
    }

    public func refreshAppStoreReviewFailed(_ error: Error) -> String {
        text("Refresh App Store review status failed: \(error)", "刷新 App Store 提审状态失败：\(error)")
    }

    public func appStoreReviewBindBuildFailed(_ error: Error) -> String {
        text("Bind App Store build failed: \(error)", "绑定 App Store Build 失败：\(error)")
    }

    public func appStoreReviewSaveFailed(_ error: Error) -> String {
        text("Save App Store review metadata failed: \(error)", "保存 App Store 提审资料失败：\(error)")
    }

    public func appStoreReviewSubmitted(state: String) -> String {
        text("Submitted to App Store review. State: \(state)", "已提交商店审核。状态：\(state)")
    }

    public func appStoreReviewSubmitFailed(_ error: Error) -> String {
        text("Submit App Store review failed: \(error)", "提交商店审核失败：\(error)")
    }

    public func appStoreReviewCancelFailed(_ error: Error) -> String {
        text("Failed to withdraw the review submission: \(error)", "撤销审核提交失败：\(error)")
    }

    public func appStoreReviewReleaseTypeFailed(_ error: Error) -> String {
        text("Failed to update the release strategy: \(error)", "更新发布策略失败：\(error)")
    }

    public func appStoreReviewReleaseFailed(_ error: Error) -> String {
        text("Failed to release to the App Store: \(error)", "发布到 App Store 失败：\(error)")
    }

    public var selectProjectBeforeLinkingExternalGroups: String {
        text("Select a project before linking external groups.", "请先选择项目再关联外部测试组。")
    }

    public var selectAppleAccountBeforeLinkingExternalGroups: String {
        text("Select an Apple account before linking external groups.", "请先选择 Apple 账号再关联外部测试组。")
    }

    public var externalTestFlightGroupsLinked: String {
        text("External TestFlight groups linked.", "外部 TestFlight 测试组已关联。")
    }

    public var externalTestFlightGroupLinked: String {
        text("External TestFlight group linked.", "外部 TestFlight 测试组已关联。")
    }

    public var selectProjectBeforeApplyingProjectChanges: String {
        text("Select a project before applying project changes.", "请先选择项目再应用项目变更。")
    }

    public var configurationChecksCompletedNoIssues: String {
        text("[OK] Configuration checks completed with no issues.", "[OK] 配置检查完成，没有发现问题。")
    }

    public var failedToSaveChanges: String {
        text("Failed to save changes.", "保存变更失败。")
    }

    public var mutationLabelBuildNumber: String { text("Build Number", "Build Number") }

    public func selectedCount(_ count: Int) -> String {
        text("\(count) Selected", "已选择 \(count) 个")
    }

    public func deleteSelectedProjectsMessage(count: Int) -> String {
        text("This will remove \(count) project(s) from the sidebar.", "将从侧边栏移除 \(count) 个项目。")
    }

    public func screenshotResourceMissing(_ resourceName: String) -> String {
        text("Screenshot resource missing: \(resourceName)", "截图资源缺失：\(resourceName)")
    }

    public func loadSavedProjectsFailed(_ error: Error) -> String {
        text("Failed to load saved projects: \(error)", "加载已保存项目失败：\(error)")
    }

    public func loadProjectsFailed(_ error: Error) -> String {
        text("Failed to load projects: \(error)", "加载项目失败：\(error)")
    }

    public func saveProjectsFailed(_ error: Error) -> String {
        text("Failed to save projects: \(error)", "保存项目失败：\(error)")
    }

    public func scanFailed(_ error: Error) -> String {
        text("Scan failed: \(error)", "扫描失败：\(error)")
    }

    public func applyProjectChangesFailed(_ error: Error) -> String {
        text("Apply project changes failed: \(error)", "应用项目变更失败：\(error)")
    }

    public var enterProjectPathBeforeScanning: String {
        text("Enter a project path before scanning.", "请先输入项目路径再扫描。")
    }

    public func metadataImportFailed(_ error: Error) -> String {
        text("Metadata import failed: \(error)", "元数据导入失败：\(error)")
    }

    public func privateKeyImportFailed(_ error: Error) -> String {
        text("Private key import failed: \(error)", "私钥导入失败：\(error)")
    }

    public func runningUploadStep(_ step: UploadStep) -> String {
        text("Running \(uploadStep(step))", "正在执行\(uploadStep(step))")
    }

    public func uploadStep(_ step: UploadStep) -> String {
        switch step {
        case .readProject:
            return text("Read Project", "读取项目")
        case .validateAccount:
            return text("Validate Account", "验证账号")
        case .checkBundleAndApp:
            return text("Check Bundle and App", "检查 Bundle 和 App")
        case .backupProjectFiles:
            return text("Backup Project Files", "备份项目文件")
        case .applyProjectChanges:
            return text("Apply Project Changes", "应用项目变更")
        case .archive:
            return text("Archive", "归档")
        case .exportIPA:
            return text("Export IPA", "导出 IPA")
        case .validateIPA:
            return text("Validate IPA", "验证 IPA")
        case .upload:
            return text("Upload", "上传")
        case .waitForAppleProcessing:
            return text("Wait for Apple Processing", "等待 Apple 处理")
        case .assignTestFlightGroups:
            return text("Assign TestFlight Groups", "分配 TestFlight 测试组")
        case .fetchPublicLink:
            return text("Fetch Public Link", "获取公开链接")
        }
    }
}
