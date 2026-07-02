import XCTest
import PathKit
import XcodeProj
@testable import ProjPostCore

final class ProjectMutatorTests: XCTestCase {
    func testPlanFromProjectProfileIncludesBackupAndReadableSummary() throws {
        let projectRoot = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let pbxproj = projectRoot.appendingPathComponent("Demo.xcodeproj/project.pbxproj")
        let info = projectRoot.appendingPathComponent("Demo/Info.plist")
        let fileSystem = RecordingFileSystem(existingFiles: [pbxproj.path, info.path])
        let mutator = ProjectMutator(fileSystem: fileSystem, backupRoot: projectRoot.appendingPathComponent(".projpost-backups"))

        let project = ProjectProfile(
            name: "Demo",
            projectPath: projectRoot.path,
            workspacePath: nil,
            projectFilePath: projectRoot.appendingPathComponent("Demo.xcodeproj").path,
            scheme: "Demo",
            configuration: "Release",
            bundleID: "com.old.demo",
            version: "1.0.0",
            buildNumber: "1",
            teamID: nil,
            selectedAccountID: nil,
            lastUpload: nil
        )

        let plan = try mutator.plan(
            project: project,
            targetBundleID: "com.example.demo",
            targetVersion: "1.0.1",
            targetBuildNumber: "2",
            infoPlistURL: info
        )

        XCTAssertEqual(plan.changes.map(\.summary), [
            "Bundle ID: com.old.demo -> com.example.demo",
            "Version: 1.0.0 -> 1.0.1",
            "Build Number: 1 -> 2"
        ])
        XCTAssertEqual(plan.filesToBackup, [pbxproj, info])
    }

    func testPlanThrowsWhenTargetVersionExistsButCurrentVersionIsMissing() throws {
        let projectRoot = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let pbxproj = projectRoot.appendingPathComponent("Demo.xcodeproj/project.pbxproj")
        let fileSystem = RecordingFileSystem(existingFiles: [pbxproj.path])
        let mutator = ProjectMutator(fileSystem: fileSystem, backupRoot: projectRoot.appendingPathComponent(".projpost-backups"))

        let project = ProjectProfile(
            name: "Demo",
            projectPath: projectRoot.path,
            workspacePath: nil,
            projectFilePath: projectRoot.appendingPathComponent("Demo.xcodeproj").path,
            scheme: "Demo",
            configuration: "Release",
            bundleID: "com.old.demo",
            version: nil,
            buildNumber: "1",
            teamID: nil,
            selectedAccountID: nil,
            lastUpload: nil
        )

        XCTAssertThrowsError(
            try mutator.plan(
                project: project,
                targetBundleID: nil,
                targetVersion: "1.0.1",
                targetBuildNumber: nil,
                infoPlistURL: nil
            )
        ) { error in
            guard case ProjectMutatorError.missingCurrentValue(let label) = error else {
                return XCTFail("Expected missingCurrentValue, got \(error)")
            }

            XCTAssertEqual(label, "Version")
        }
    }

    func testPlansCreatedBackToBackUseDistinctBackupDirectories() throws {
        let projectRoot = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let pbxproj = projectRoot.appendingPathComponent("Demo.xcodeproj/project.pbxproj")
        let fileSystem = RecordingFileSystem(existingFiles: [pbxproj.path])
        let mutator = ProjectMutator(fileSystem: fileSystem, backupRoot: projectRoot.appendingPathComponent(".projpost-backups"))

        let request = ProjectMutationRequest(
            projectRoot: projectRoot,
            pbxprojURL: pbxproj,
            infoPlistURL: nil,
            targetName: "Demo",
            currentBundleID: "com.old.demo",
            newBundleID: "com.example.demo",
            currentVersion: "1.0.0",
            newVersion: "1.0.1",
            currentBuildNumber: "1",
            newBuildNumber: "2"
        )

        let firstPlan = try mutator.plan(request: request)
        let secondPlan = try mutator.plan(request: request)

        XCTAssertNotEqual(firstPlan.backupDirectory, secondPlan.backupDirectory)
        XCTAssertTrue(firstPlan.backupDirectory.lastPathComponent.hasPrefix("202"))
        XCTAssertTrue(secondPlan.backupDirectory.lastPathComponent.hasPrefix("202"))
    }

    func testApplyUpdatesOnlyTheIntendedNativeTarget() throws {
        let projectRoot = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let xcodeproj = projectRoot.appendingPathComponent("Demo.xcodeproj")
        try makeXcodeProject(
            at: xcodeproj,
            targets: [
                targetFixture(name: "Demo", bundleID: "com.old.demo", version: "1.0.0", build: "1"),
                targetFixture(name: "DemoTests", bundleID: "com.old.demo.tests", version: "1.0.0", build: "1")
            ]
        )
        let mutator = ProjectMutator(fileSystem: LocalFileSystem(), backupRoot: projectRoot.appendingPathComponent(".projpost-backups"))

        let request = ProjectMutationRequest(
            projectRoot: projectRoot,
            pbxprojURL: xcodeproj.appendingPathComponent("project.pbxproj"),
            infoPlistURL: nil,
            targetName: "Demo",
            currentBundleID: "com.old.demo",
            newBundleID: "com.example.demo",
            currentVersion: "1.0.0",
            newVersion: "1.0.1",
            currentBuildNumber: "1",
            newBuildNumber: "2"
        )

        let plan = try mutator.plan(request: request)
        try mutator.apply(plan)

        let updated = try XcodeProj(path: Path(xcodeproj.path))
        let appSettings = try XCTUnwrap(settings(in: updated, targetName: "Demo"))
        let testSettings = try XCTUnwrap(settings(in: updated, targetName: "DemoTests"))

        XCTAssertEqual(appSettings["PRODUCT_BUNDLE_IDENTIFIER"] as? String, "com.example.demo")
        XCTAssertEqual(appSettings["MARKETING_VERSION"] as? String, "1.0.1")
        XCTAssertEqual(appSettings["CURRENT_PROJECT_VERSION"] as? String, "2")
        XCTAssertEqual(testSettings["PRODUCT_BUNDLE_IDENTIFIER"] as? String, "com.old.demo.tests")
        XCTAssertEqual(testSettings["MARKETING_VERSION"] as? String, "1.0.0")
        XCTAssertEqual(testSettings["CURRENT_PROJECT_VERSION"] as? String, "1")
        XCTAssertTrue(FileManager.default.fileExists(atPath: plan.backupDirectory.appendingPathComponent("project.pbxproj").path))
    }

    func testApplyRejectsAmbiguousTargetsWhenMultipleTargetsMatchCurrentSettings() throws {
        let projectRoot = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let xcodeproj = projectRoot.appendingPathComponent("Demo.xcodeproj")
        try makeXcodeProject(
            at: xcodeproj,
            targets: [
                targetFixture(name: "AppOne", bundleID: "com.old.demo", version: "1.0.0", build: "1"),
                targetFixture(name: "AppTwo", bundleID: "com.old.demo", version: "1.0.0", build: "1")
            ]
        )
        let mutator = ProjectMutator(fileSystem: LocalFileSystem(), backupRoot: projectRoot.appendingPathComponent(".projpost-backups"))

        let request = ProjectMutationRequest(
            projectRoot: projectRoot,
            pbxprojURL: xcodeproj.appendingPathComponent("project.pbxproj"),
            infoPlistURL: nil,
            targetName: nil,
            currentBundleID: "com.old.demo",
            newBundleID: "com.example.demo",
            currentVersion: "1.0.0",
            newVersion: "1.0.1",
            currentBuildNumber: "1",
            newBuildNumber: "2"
        )
        let plan = try mutator.plan(request: request)

        XCTAssertThrowsError(try mutator.apply(plan)) { error in
            guard case ProjectMutatorError.ambiguousTarget(let names) = error else {
                return XCTFail("Expected ambiguousTarget, got \(error)")
            }

            XCTAssertEqual(names.sorted(), ["AppOne", "AppTwo"])
        }
    }
}

private func targetFixture(name: String, bundleID: String, version: String, build: String) -> (String, [String: String]) {
    (
        name,
        [
            "PRODUCT_BUNDLE_IDENTIFIER": bundleID,
            "MARKETING_VERSION": version,
            "CURRENT_PROJECT_VERSION": build
        ]
    )
}

private func makeXcodeProject(at url: URL, targets targetData: [(String, [String: String])]) throws {
    let targetFixtures = targetData.map { name, settings in
        let debug = XCBuildConfiguration(name: "Debug", buildSettings: settings)
        let release = XCBuildConfiguration(name: "Release", buildSettings: settings)
        let list = XCConfigurationList(buildConfigurations: [debug, release], defaultConfigurationName: "Release")
        let target = PBXNativeTarget(name: name, buildConfigurationList: list, productName: name, productType: .application)
        return (target: target, list: list, configs: [debug, release])
    }
    let targetObjects = targetFixtures.map(\.target)
    let projectDebug = XCBuildConfiguration(name: "Debug")
    let projectRelease = XCBuildConfiguration(name: "Release")
    let projectList = XCConfigurationList(buildConfigurations: [projectDebug, projectRelease], defaultConfigurationName: "Release")
    let mainGroup = PBXGroup(sourceTree: .group)
    let project = PBXProject(
        name: "Demo",
        buildConfigurationList: projectList,
        compatibilityVersion: "Xcode 15.0",
        preferredProjectObjectVersion: nil,
        minimizedProjectReferenceProxies: nil,
        mainGroup: mainGroup,
        targets: targetObjects
    )
    let objects: [PBXObject] = [project, mainGroup, projectList, projectDebug, projectRelease] + targetFixtures.flatMap { fixture -> [PBXObject] in
        [fixture.target, fixture.list] + fixture.configs
    }
    let xcodeProject = XcodeProj(workspace: XCWorkspace(), pbxproj: PBXProj(rootObject: project, objects: objects))
    try xcodeProject.write(path: Path(url.path), override: true)
}

private func settings(in project: XcodeProj, targetName: String) -> [String: Any]? {
    let target = project.pbxproj.nativeTargets.first { $0.name == targetName }
    return target?.buildConfigurationList?.configuration(name: "Release")?.buildSettings
}

private final class RecordingFileSystem: FileSysteming {
    let existingFiles: Set<String>
    let dataByURL: [URL: Data]
    var written: [URL: Data] = [:]

    init(existingFiles: [String], dataByURL: [URL: Data] = [:]) {
        self.existingFiles = Set(existingFiles)
        self.dataByURL = dataByURL
    }

    func fileExists(_ url: URL) -> Bool { existingFiles.contains(url.path) }
    func contentsOfDirectory(_ url: URL) throws -> [String] { [] }
    func createDirectory(_ url: URL) throws {}
    func readData(_ url: URL) throws -> Data { dataByURL[url] ?? Data("PRODUCT_BUNDLE_IDENTIFIER = com.old.demo;".utf8) }
    func writeData(_ data: Data, to url: URL) throws { written[url] = data }
    func removeItem(_ url: URL) throws {}
    func setPOSIXPermissions(_ permissions: Int, for url: URL) throws {}
}
