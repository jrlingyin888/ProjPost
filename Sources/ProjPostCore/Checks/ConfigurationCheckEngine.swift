import Foundation

public protocol EnvironmentChecking {
    func checkXcode() async -> CheckResult
}

public struct XcodeEnvironmentChecker: EnvironmentChecking {
    private let commandRunner: CommandRunning
    private let language: AppLanguage

    public init(commandRunner: CommandRunning = ProcessCommandRunner(), language: AppLanguage = .english) {
        self.commandRunner = commandRunner
        self.language = language
    }

    public func checkXcode() async -> CheckResult {
        let strings = AppStrings(language: language)
        do {
            let result = try await commandRunner.run(Command(executableURL: URL(fileURLWithPath: "/usr/bin/xcodebuild"), arguments: ["-version"]))
            guard result.exitCode == 0 else {
                return CheckResult(id: "xcode", title: strings.configurationCheckXcodeUnavailableTitle, message: result.stderr.isEmpty ? strings.configurationCheckInstallOrSelectXcodeMessage : result.stderr, severity: .red)
            }
            let rsyncResult = try await commandRunner.run(Command(executableURL: URL(fileURLWithPath: "/usr/bin/env"), arguments: ["rsync", "--version"]))
            guard rsyncResult.exitCode == 0 else {
                let message = rsyncResult.stderr.isEmpty ? strings.configurationCheckRsyncRequiredMessage : rsyncResult.stderr
                return CheckResult(id: "rsync", title: strings.configurationCheckRsyncUnavailableTitle, message: message, severity: .red)
            }
            return CheckResult(id: "xcode", title: strings.configurationCheckXcodeAvailableTitle, message: result.stdout.trimmingCharacters(in: .whitespacesAndNewlines), severity: .green)
        } catch {
            return CheckResult(id: "xcode", title: strings.configurationCheckXcodeUnavailableTitle, message: strings.configurationCheckXcodeCommandLineMessage, severity: .red)
        }
    }
}

public final class ConfigurationCheckEngine {
    private let environment: EnvironmentChecking
    private let appStoreConnect: AppStoreConnectClientProtocol
    private let language: AppLanguage

    public init(environment: EnvironmentChecking, appStoreConnect: AppStoreConnectClientProtocol, language: AppLanguage = .english) {
        self.environment = environment
        self.appStoreConnect = appStoreConnect
        self.language = language
    }

    public func run(project: ProjectProfile, account: AppleAccountProfile) async -> [CheckResult] {
        let strings = AppStrings(language: language)
        var results: [CheckResult] = []
        results.append(await environment.checkXcode())

        guard let bundleID = project.bundleID, !bundleID.isEmpty else {
            results.append(CheckResult(id: "bundle-id", title: strings.configurationCheckBundleIDMissingTitle, message: strings.configurationCheckBundleIDMissingMessage, severity: .red))
            return results
        }

        do {
            let bundle = try await appStoreConnect.fetchBundleID(identifier: bundleID)
            results.append(bundle == nil
                ? CheckResult(id: "bundle-id", title: strings.configurationCheckBundleIDNotFoundTitle, message: strings.configurationCheckBundleIDNotFoundMessage(bundleID), severity: .red)
                : CheckResult(id: "bundle-id", title: strings.configurationCheckBundleIDFoundTitle, message: bundleID, severity: .green)
            )

            guard let app = try await appStoreConnect.fetchApp(bundleID: bundleID) else {
                results.append(CheckResult(id: "app", title: strings.configurationCheckAppNotFoundTitle, message: strings.configurationCheckAppNotFoundMessage, severity: .red))
                return results
            }
            results.append(CheckResult(id: "app", title: strings.configurationCheckAppMatchedTitle, message: app.name, severity: .green))

            if let teamID = project.teamID, let accountTeamID = account.teamID, teamID != accountTeamID {
                results.append(CheckResult(id: "team", title: strings.configurationCheckTeamIDMismatchTitle, message: strings.configurationCheckTeamIDMismatchMessage(projectTeamID: teamID, accountTeamID: accountTeamID), severity: .red))
            } else if project.teamID == nil || account.teamID == nil {
                results.append(CheckResult(id: "team", title: strings.configurationCheckTeamIDUnconfirmedTitle, message: strings.configurationCheckTeamIDUnconfirmedMessage, severity: .yellow))
            } else {
                results.append(CheckResult(id: "team", title: strings.configurationCheckTeamIDMatchedTitle, message: project.teamID ?? "", severity: .green))
            }

            if let buildNumber = project.buildNumber, !buildNumber.isEmpty {
                let trimmedVersion = project.version?.trimmingCharacters(in: .whitespacesAndNewlines)
                let appVersion = trimmedVersion?.isEmpty == false ? trimmedVersion : nil
                let builds = try await appStoreConnect.fetchBuilds(appID: app.id, appVersion: appVersion, buildNumber: buildNumber)
                let buildLabel = appVersion.map { "\($0) (\(buildNumber))" } ?? "build \(buildNumber)"
                results.append(builds.isEmpty
                    ? CheckResult(id: "build-number", title: strings.configurationCheckBuildNumberAvailableTitle, message: buildLabel, severity: .green)
                    : CheckResult(id: "build-number", title: strings.configurationCheckBuildNumberMayDuplicateTitle, message: strings.configurationCheckBuildNumberDuplicateMessage(buildLabel), severity: .red)
                )
            } else {
                results.append(CheckResult(id: "build-number", title: strings.configurationCheckBuildNumberMissingTitle, message: strings.configurationCheckBuildNumberMissingMessage, severity: .red))
            }
        } catch {
            results.append(CheckResult(id: "asc-api", title: strings.configurationCheckAppleAccountFailedTitle, message: String(describing: error), severity: .red))
        }

        return results
    }
}
