import CoreGraphics
import os

/// KeyTap 翻译出来的切换器输入
enum SwitcherInput: Equatable {
    case begin(reverse: Bool)
    case next, previous, confirm, cancel, quit, hide
}

/// 对一个键盘事件的处理决定：是否吞掉，以及产生什么输入
struct TapDecision: Equatable {
    var swallow: Bool
    var input: SwitcherInput?

    static let passThrough = TapDecision(swallow: false, input: nil)
}

private enum KeyCode {
    static let tab: Int64 = 48, escape: Int64 = 53, q: Int64 = 12, h: Int64 = 4, left: Int64 = 123, right: Int64 = 124
}

/// 用 CGEventTap 拦截 Cmd+Tab；切换会话期间吞掉所有按键，但放行修饰键事件
final class KeyTap {
    /// 由调用方维护：开启会话后设为 true，结束后设为 false
    var sessionActive = false
    private let onInput: (SwitcherInput) -> Void
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    var isRunning: Bool { tap != nil }

    init(onInput: @escaping (SwitcherInput) -> Void) {
        self.onInput = onInput
    }

    /// 创建事件拦截；返回 false 通常表示没有辅助功能权限。已在运行时直接返回 true，不会重复创建
    func start() -> Bool {
        guard tap == nil else { return true }
        let mask = [CGEventType.keyDown, .keyUp, .flagsChanged].reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                return Unmanaged<KeyTap>.fromOpaque(refcon).takeUnretainedValue().handle(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }
        self.tap = tap
        source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        logger.notice("event tap started")
        return true
    }

    /// 拆掉事件拦截；没在运行时什么也不做
    func stop() {
        guard let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        CFMachPortInvalidate(tap)
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        self.tap = nil
        source = nil
        logger.notice("event tap stopped")
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            logger.notice("event tap disabled by \(type == .tapDisabledByTimeout ? "timeout" : "userInput", privacy: .public), re-enabling")
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        let decision = KeyTap.decide(type: type,
                                     keyCode: event.getIntegerValueField(.keyboardEventKeycode),
                                     flags: event.flags,
                                     sessionActive: sessionActive)
        if let input = decision.input { onInput(input) }
        return decision.swallow ? nil : Unmanaged.passUnretained(event)
    }

    static func decide(type: CGEventType, keyCode: Int64, flags: CGEventFlags, sessionActive: Bool) -> TapDecision {
        guard sessionActive else {
            let isCmdTab = type == .keyDown && keyCode == KeyCode.tab
                && flags.contains(.maskCommand) && !flags.contains(.maskControl) && !flags.contains(.maskAlternate)
            return isCmdTab ? TapDecision(swallow: true, input: .begin(reverse: flags.contains(.maskShift))) : .passThrough
        }
        // 按键不带 Cmd，说明漏掉了松开 Cmd 的 flagsChanged（例如 tap 超时被禁用）：按松开处理，并放行这个键
        if (type == .keyDown || type == .keyUp) && !flags.contains(.maskCommand) {
            return TapDecision(swallow: false, input: .confirm)
        }
        switch type {
        case .flagsChanged:
            return TapDecision(swallow: false, input: flags.contains(.maskCommand) ? nil : .confirm)
        case .keyUp:
            return TapDecision(swallow: true, input: nil)
        case .keyDown:
            let input: SwitcherInput?
            switch keyCode {
            case KeyCode.tab: input = flags.contains(.maskShift) ? .previous : .next
            case KeyCode.right: input = .next
            case KeyCode.left: input = .previous
            case KeyCode.escape: input = .cancel
            case KeyCode.q: input = .quit
            case KeyCode.h: input = .hide
            default: input = nil
            }
            return TapDecision(swallow: true, input: input)
        default:
            return .passThrough
        }
    }
}
