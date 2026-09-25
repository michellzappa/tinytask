import XCTest
@testable import TinyTask

final class AppStateTests: XCTestCase {
    override func setUp() {
        super.setUp()
        AppState.todayString = { "2026-04-03" }
    }

    func testParseContentReadsSectionsTasksChecklistAndNotes() {
        let state = AppState()
        state.content = """
        # Work
        - [ ] Ship release @start(2026-04-01) @due(2026-04-05)
            - [x] Check CI
            > Need release notes
        - [-] Cancel old plan @cancelled(2026-04-03)
        """

        state.parseContent()

        XCTAssertEqual(state.items.count, 5)
        XCTAssertEqual(state.sectionCount, 1)
        XCTAssertEqual(state.totalTasks, 2)
        XCTAssertEqual(state.items[1].startDate, "2026-04-01")
        XCTAssertEqual(state.items[1].dueDate, "2026-04-05")
        XCTAssertTrue(state.items[2].isChecklist)
        XCTAssertTrue(state.items[4].isCancelled)
    }

    func testToggleAndCancelUseDeterministicDate() {
        let state = AppState()
        state.items = [
            ListItem(kind: .task("Ship release", .pending)),
            ListItem(kind: .task("Cancel plan", .pending)),
        ]

        state.toggleTask(at: 0)
        state.cancelTask(at: 1)

        XCTAssertEqual(state.items[0].completionDate, "2026-04-03")
        if case .task(_, .cancelled(let date)) = state.items[1].kind {
            XCTAssertEqual(date, "2026-04-03")
        } else {
            XCTFail("Expected cancelled task")
        }
    }

    func testSectionProgressAndOverdueCounts() {
        let state = AppState()
        state.items = [
            ListItem(kind: .section("Work")),
            ListItem(kind: .task("Ship release", .pending), dueDate: "2026-04-02"),
            ListItem(kind: .task("Write notes", .done("2026-04-03")), dueDate: "2026-04-05"),
            ListItem(kind: .section("Later")),
            ListItem(kind: .task("Archive tasks", .pending), dueDate: "2026-04-10"),
        ]

        XCTAssertEqual(state.overdueTasks, 1)
        XCTAssertEqual(state.sectionProgress(at: 0).0, 1)
        XCTAssertEqual(state.sectionProgress(at: 0).1, 2)
    }
}
