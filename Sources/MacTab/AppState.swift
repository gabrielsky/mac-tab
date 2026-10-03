import AppKit
import ServiceManagement

/// 设置窗口观察的状态：授权、登录项、当前主题
final class AppState: ObservableObject {
    enum Permission {
        case granted   // 已授权，事件拦截在运行
        case missing   // 未授权
        case tapFailed // 已授权，但事件拦截创建失败
    }

    @Published var permission: Permission = .missing
    @Published var theme: ThemeID {
        didSet { store.current = theme }
    }
    @Published private(set) var loginEnabled = false

    private let store: ThemeStore

    init(store: ThemeStore = ThemeStore()) {
        self.store = store
        theme = store.current
    }

    /// 登录项可能在系统设置里被改掉，设置窗口每次出现时都重新读（SettingsWindowController.show）
    func refreshLogin() {
        loginEnabled = SMAppService.mainApp.status == .enabled
    }

    func setLogin(_ enabled: Bool) {
        let service = SMAppService.mainApp
        do {
            if enabled { try service.register() } else { try service.unregister() }
        } catch {
            logger.error("login item error: \(String(describing: error), privacy: .public)")
        }
        if service.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
        refreshLogin()
    }

    func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
}
