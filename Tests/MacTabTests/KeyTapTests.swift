import CoreGraphics
import XCTest
@testable import MacTab

final class KeyTapTests: XCTestCase {
    private let cmd: CGEventFlags = .maskCommand

    private func decide(_ type: CGEventType, _ keyCode: Int64, _ flags: CGEventFlags, active: Bool) -> TapDecision {
        KeyTap.decide(type: type, keyCode: keyCode, flags: flags, sessionActive: active)
    }

    func testCmdTabBeginsSession() {
        XCTAssertEqual(decide(.keyDown, 48, cmd, active: false), TapDecision(swallow: true, input: .begin(reverse: false)))
    }

    func testCmdShiftTabBeginsReversed() {
        XCTAssertEqual(decide(.keyDown, 48, [cmd, .maskShift], active: false), TapDecision(swallow: true, input: .begin(reverse: true)))
    }

    func testTabWithOptionOrControlPassesThrough() {
        XCTAssertEqual(decide(.keyDown, 48, [cmd, .maskAlternate], active: false), .passThrough)
        XCTAssertEqual(decide(.keyDown, 48, [cmd, .maskControl], active: false), .passThrough)
    }

    func testCmdTabWithCapsLockOrFnStillBegins() {
        // 只排除 Ctrl 和 Option；CapsLock、Fn 这类标志不影响开启会话
        XCTAssertEqual(decide(.keyDown, 48, [cmd, .maskAlphaShift], active: false), TapDecision(swallow: true, input: .begin(reverse: false)))
        XCTAssertEqual(decide(.keyDown, 48, [cmd, .maskSecondaryFn], active: false), TapDecision(swallow: true, input: .begin(reverse: false)))
    }

    func testIdleKeysOtherThanCmdTabPassThrough() {
        XCTAssertEqual(decide(.keyDown, 12, cmd, active: false), .passThrough)   // 平时的 Cmd+Q 不受影响
        XCTAssertEqual(decide(.keyDown, 48, [], active: false), .passThrough)    // 单独的 Tab
        XCTAssertEqual(decide(.keyUp, 48, cmd, active: false), .passThrough)
        XCTAssertEqual(decide(.flagsChanged, 55, [], active: false), .passThrough)
    }

    func testSessionKeyDownMapping() {
        let cases: [(Int64, CGEventFlags, SwitcherInput?)] = [
            (48, cmd, .next),
            (48, [cmd, .maskShift], .previous),
            (124, cmd, .next),      // →
            (123, cmd, .previous),  // ←
            (53, cmd, .cancel),     // Esc
            (12, cmd, .quit),       // Q
            (4, cmd, .hide),        // H
            (0, cmd, nil),          // 其他键：吞掉但不产生输入
        ]
        for (keyCode, flags, input) in cases {
            XCTAssertEqual(decide(.keyDown, keyCode, flags, active: true), TapDecision(swallow: true, input: input), "keyCode \(keyCode)")
        }
    }

    func testSessionSwallowsKeyUp() {
        XCTAssertEqual(decide(.keyUp, 48, cmd, active: true), TapDecision(swallow: true, input: nil))
    }

    func testSessionKeyWithoutCommandMeansMissedReleaseAndConfirms() {
        // tap 超时被禁用时可能漏掉松开 Cmd 的 flagsChanged：不带 Cmd 的按键视为已松开，放行并确认
        XCTAssertEqual(decide(.keyDown, 12, [], active: true), TapDecision(swallow: false, input: .confirm))  // 单独的 q 不能触发退出
        XCTAssertEqual(decide(.keyUp, 48, [], active: true), TapDecision(swallow: false, input: .confirm))
    }

    func testCommandReleaseConfirmsButIsNotSwallowed() {
        XCTAssertEqual(decide(.flagsChanged, 55, [], active: true), TapDecision(swallow: false, input: .confirm))
        // 按住 Cmd 时再按 Shift：修饰键事件放行，也不产生输入
        XCTAssertEqual(decide(.flagsChanged, 56, [cmd, .maskShift], active: true), .passThrough)
    }
}
