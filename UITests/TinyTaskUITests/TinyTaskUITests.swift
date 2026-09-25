import Foundation
import XCTest

final class TinyTaskUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunchesWithFixtureAndShowsTaskCounts() {
        let fixturePath = fixturePath(named: "sample.todo")
        let app = XCUIApplication()
        app.launchArguments += ["--ui-testing", "--disable-ai", "--disable-spotlight", "--disable-file-watchers"]
        app.launchEnvironment["TINY_FIXTURE_PATH"] = fixturePath
        app.launchEnvironment["TINY_FIXED_TODAY"] = "2026-04-03"

        app.launch()

        let probe = app.staticTexts["ui-smoke-status"]
        XCTAssertTrue(probe.waitForExistence(timeout: 10))
        XCTAssertTrue(probe.label.contains("sample.todo"))
        XCTAssertTrue(probe.label.contains("tasks:2"))
        XCTAssertTrue(probe.label.contains("done:1"))
    }

    private func fixturePath(named name: String) -> String {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/\(name)")
            .path
    }
}
