import AppKit
import ApplicationServices
import os

/// 切换到应用：隐藏的先取消隐藏；候选窗口（标准窗口或已最小化的窗口）全部最小化时，恢复第一个；最后激活
enum Activator {
    static func activate(_ app: NSRunningApplication) {
        if app.isHidden { app.unhide() }
        restoreIfAllMinimized(pid: app.processIdentifier)
        app.activate(options: .activateAllWindows)
    }

    /// ponytail: AX 不提供最小化时间，所以取第一个最小化窗口，而不是「最近最小化」的那个
    private static func restoreIfAllMinimized(pid: pid_t) {
        guard let windows = attribute(AXUIElementCreateApplication(pid), kAXWindowsAttribute) as? [AXUIElement] else { return }
        // 每个窗口的 AX 属性只读一次
        let infos = windows.map { (element: $0,
                                   standard: attribute($0, kAXSubroleAttribute) as? String == kAXStandardWindowSubrole,
                                   minimized: attribute($0, kAXMinimizedAttribute) as? Bool == true) }
        // macOS 26 上窗口最小化后 subrole 会报成 AXDialog，所以最小化的窗口也算候选
        let candidates = infos.filter { $0.standard || $0.minimized }
        guard let first = candidates.first, candidates.allSatisfy({ $0.minimized }) else { return }
        let error = AXUIElementSetAttributeValue(first.element, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        if error != .success { logger.error("restore minimized window failed: AXError \(error.rawValue, privacy: .public)") }
    }

    private static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
    }
}
