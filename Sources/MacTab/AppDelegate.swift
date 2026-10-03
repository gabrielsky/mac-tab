import AppKit
import ApplicationServices
import os

let logger = Logger(subsystem: "local.mactab", category: "app")

final class AppDelegate: NSObject, NSApplicationDelegate {
    private lazy var statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    // 整个进程只创建一次；lazy 是为了等 NSApplication 启动后再建面板
    private lazy var controller = SwitcherController()
    private let state = AppState()
    private lazy var settings = SettingsWindowController(state: state)

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 所有 AX 调用最多等 0.2s，避免卡死在无响应的应用上
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 0.2)
        let menu = NSMenu()
        let settingsItem = NSMenuItem(title: "设置…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出 MacTab", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu

        // 授权提示只在启动时弹一次；之后靠每秒轮询感知授权和撤销，都立即生效，不用重启
        let trusted = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        update(.missing)
        syncWithPermission()
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.syncWithPermission() }
        // 菜单里已经没有状态行：没有授权时打开设置窗口作为引导
        if !trusted { settings.show() }
    }

    @objc private func openSettings() {
        settings.show()
    }

    /// 只在授权状态和事件拦截的运行状态不一致时动作，状态没变就什么也不做
    private func syncWithPermission() {
        let trusted = AXIsProcessTrusted()
        guard trusted != controller.isRunning else { return }
        if trusted {
            // 首次授权、重新授权、上次创建失败都走这里；失败就等下个 tick 再试
            logger.notice("accessibility granted")
            if controller.start() {
                update(.granted)
            } else {
                logger.error("tapCreate failed")
                update(.tapFailed)
            }
        } else {
            // 撤销后 tap 还挂在主 runloop 上，要主动拆掉，Cmd+Tab 才会回到系统切换器
            logger.notice("accessibility revoked")
            controller.stop()
            update(.missing)
        }
    }

    private func update(_ permission: AppState.Permission) {
        state.permission = permission
        let symbol = permission == .granted ? "rectangle.stack" : "exclamationmark.triangle"
        statusItem.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "MacTab")
    }
}
