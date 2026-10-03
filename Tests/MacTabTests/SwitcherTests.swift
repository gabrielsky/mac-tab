import XCTest
@testable import MacTab

final class SwitcherTests: XCTestCase {
    func testStartsOnSecondWhenFrontmostIsFirst() {
        XCTAssertEqual(Switcher(apps: [1, 2, 3], frontmost: 1, reverse: false)?.selected, 1)
    }

    func testStartsOnFirstWhenFrontmostHasNoWindows() {
        // 前台应用（比如点了桌面后的访达）没有窗口，所以不在列表里
        XCTAssertEqual(Switcher(apps: [2, 3], frontmost: 1, reverse: false)?.selected, 0)
    }

    func testStartsOnFirstWhenNoFrontmost() {
        XCTAssertEqual(Switcher(apps: [1, 2], frontmost: nil, reverse: false)?.selected, 0)
    }

    func testSingleAppIsSelected() {
        XCTAssertEqual(Switcher(apps: [1], frontmost: 1, reverse: false)?.selected, 0)
    }

    func testReverseStartsOnLast() {
        XCTAssertEqual(Switcher(apps: [1, 2, 3], frontmost: 1, reverse: true)?.selected, 2)
    }

    func testEmptyListHasNoSession() {
        XCTAssertNil(Switcher(apps: [], frontmost: 1, reverse: false))
    }

    func testNextAndPreviousWrapAround() throws {
        var s = try XCTUnwrap(Switcher(apps: [1, 2, 3], frontmost: 1, reverse: false))
        XCTAssertEqual(s.handle(.next), .stay)
        XCTAssertEqual(s.selected, 2)
        XCTAssertEqual(s.handle(.next), .stay)
        XCTAssertEqual(s.selected, 0)
        XCTAssertEqual(s.handle(.previous), .stay)
        XCTAssertEqual(s.selected, 2)
    }

    func testConfirmActivatesSelected() throws {
        var s = try XCTUnwrap(Switcher(apps: [1, 2, 3], frontmost: 1, reverse: false))
        XCTAssertEqual(s.handle(.confirm), .activate(2))
    }

    func testCancel() throws {
        var s = try XCTUnwrap(Switcher(apps: [1, 2], frontmost: 1, reverse: false))
        XCTAssertEqual(s.handle(.cancel), .cancel)
    }

    func testHideKeepsAppInList() throws {
        var s = try XCTUnwrap(Switcher(apps: [1, 2, 3], frontmost: 1, reverse: false))
        XCTAssertEqual(s.handle(.hide), .hide(2))
        XCTAssertEqual(s.apps, [1, 2, 3])
        XCTAssertEqual(s.selected, 1)
    }

    func testQuitRemovesSelectedAndClampsSelection() throws {
        var s = try XCTUnwrap(Switcher(apps: [1, 2, 3], frontmost: 9, reverse: true)) // 选中 pid 3
        XCTAssertEqual(s.handle(.quit), .quit(3))
        XCTAssertEqual(s.apps, [1, 2])
        XCTAssertEqual(s.selected, 1)
    }

    func testQuittingMiddleSelectedMovesToNextApp() throws {
        var s = try XCTUnwrap(Switcher(apps: [1, 2, 3], frontmost: 1, reverse: false)) // 选中 pid 2
        XCTAssertEqual(s.handle(.quit), .quit(2))
        XCTAssertEqual(s.apps, [1, 3])
        XCTAssertEqual(s.apps[s.selected], 3)
    }

    func testQuittingOnlyAppEmptiesList() throws {
        var s = try XCTUnwrap(Switcher(apps: [1], frontmost: 9, reverse: false))
        XCTAssertEqual(s.handle(.quit), .quit(1))
        XCTAssertTrue(s.isEmpty)
    }

    func testRemovingEarlierAppKeepsSameAppSelected() throws {
        var s = try XCTUnwrap(Switcher(apps: [1, 2, 3], frontmost: 1, reverse: false)) // 选中 pid 2
        XCTAssertTrue(s.remove(1))
        XCTAssertEqual(s.apps[s.selected], 2)
        XCTAssertFalse(s.remove(42))
    }

    func testSelectIgnoresOutOfRange() throws {
        var s = try XCTUnwrap(Switcher(apps: [1, 2, 3], frontmost: 1, reverse: false))
        s.select(5)
        XCTAssertEqual(s.selected, 1)
        s.select(0)
        XCTAssertEqual(s.selected, 0)
    }
}
