import Foundation

public protocol EnvironmentChecking {
    func checkXcode() async -> CheckResult
}

public struct XcodeEnvironmentChecker: EnvironmentChecking {
    private let commandRunner: CommandRunning

    public init(commandRunner: CommandRunning = ProcessCommandRunner()) {
        self.commandRunner = commandRunner
    }

    public func checkXcode() async -> CheckResult {
        do {
            let result = try await commandRunner.run(Command(executableURL: URL(fileURLWithPath: "/usr/bin/xcodebuild"), arguments: ["-version"]))
            guard result.exitCode == 0 else {
                return CheckResult(id: "xcode", title: "Xcode 不可用", message: result.stderr.isEmpty ? "请安装或选择 Xcode" : result.stderr, severity: .red)
            }
            return CheckResult(id: "xcode", title: "Xcode 可用", message: result.stdout.trimmingCharacters(in: .whitespacesAndNewlines), severity: .green)
        } catch {
            return CheckResult(id: "xcode", title: "Xcode 不可用", message: "请安装 Xcode 并确认命令行工具可用", severity: .red)
        }
    }
}

public final class ConfigurationCheckEngine {
    private let environment: EnvironmentChecking
    private let appStoreConnect: AppStoreConnectClientProtocol

    public init(environment: EnvironmentChecking, appStoreConnect: AppStoreConnectClientProtocol) {
        self.environment = environment
        self.appStoreConnect = appStoreConnect
    }

    public func run(project: ProjectProfile, account: AppleAccountProfile) async -> [CheckResult] {
        var results: [CheckResult] = []
        results.append(await environment.checkXcode())

        guard let bundleID = project.bundleID, !bundleID.isEmpty else {
            results.append(CheckResult(id: "bundle-id", title: "Bundle ID 缺失", message: "请填写 Bundle ID 后重新检查", severity: .red))
            return results
        }

        do {
            let bundle = try await appStoreConnect.fetchBundleID(identifier: bundleID)
            results.append(bundle == nil
                ? CheckResult(id: "bundle-id", title: "Bundle ID 不存在", message: "当前 Apple 账号下没有找到 \(bundleID)", severity: .red)
                : CheckResult(id: "bundle-id", title: "Bundle ID 已找到", message: bundleID, severity: .green)
            )

            guard let app = try await appStoreConnect.fetchApp(bundleID: bundleID) else {
                results.append(CheckResult(id: "app", title: "App 不存在", message: "Bundle ID 未关联到 App Store Connect App", severity: .red))
                return results
            }
            results.append(CheckResult(id: "app", title: "App 匹配", message: app.name, severity: .green))

            if let teamID = project.teamID, let accountTeamID = account.teamID, teamID != accountTeamID {
                results.append(CheckResult(id: "team", title: "Team ID 不匹配", message: "项目为 \(teamID)，账号为 \(accountTeamID)", severity: .red))
            } else if project.teamID == nil || account.teamID == nil {
                results.append(CheckResult(id: "team", title: "Team ID 无法完全确认", message: "可以继续，但建议确认签名团队正确", severity: .yellow))
            } else {
                results.append(CheckResult(id: "team", title: "Team ID 匹配", message: project.teamID ?? "", severity: .green))
            }

            if let buildNumber = project.buildNumber, !buildNumber.isEmpty {
                let builds = try await appStoreConnect.fetchBuilds(appID: app.id, buildNumber: buildNumber)
                results.append(builds.isEmpty
                    ? CheckResult(id: "build-number", title: "Build Number 可用", message: buildNumber, severity: .green)
                    : CheckResult(id: "build-number", title: "Build Number 可能重复", message: "App Store Connect 已存在 build \(buildNumber)，请递增后再上传", severity: .red)
                )
            } else {
                results.append(CheckResult(id: "build-number", title: "Build Number 缺失", message: "请填写 Build Number", severity: .red))
            }
        } catch {
            results.append(CheckResult(id: "asc-api", title: "Apple 账号检查失败", message: String(describing: error), severity: .red))
        }

        return results
    }
}
