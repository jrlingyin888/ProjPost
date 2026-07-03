import XCTest
@testable import ProjPostCore

final class CommandRunnerTests: XCTestCase {
    func testProcessCommandRunnerCapturesLargeOutputWithoutDeadlocking() async throws {
        let runner = ProcessCommandRunner()
        let command = Command(
            executableURL: URL(fileURLWithPath: "/usr/bin/python3"),
            arguments: [
                "-c",
                "import sys; sys.stdout.write('x' * 1_000_000); sys.stderr.write('y' * 1_000_000)"
            ]
        )

        let result = try await runner.run(command)

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.stdout.count, 1_000_000)
        XCTAssertEqual(result.stderr.count, 1_000_000)
    }

    func testProcessCommandRunnerAddsSystemPathForChildTools() async throws {
        let runner = ProcessCommandRunner()
        let command = Command(
            executableURL: URL(fileURLWithPath: "/usr/bin/python3"),
            arguments: ["-c", "import os; print(os.environ.get('PATH', ''))"],
            environment: ["PATH": "/custom/bin"]
        )

        let result = try await runner.run(command)

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.stdout.contains("/custom/bin"))
        XCTAssertTrue(result.stdout.contains("/usr/bin"))
    }
}
