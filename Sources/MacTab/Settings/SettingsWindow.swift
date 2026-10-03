import AppKit
import SwiftUI

/// 设置窗口的外壳：只创建一次，关闭只是隐藏
final class SettingsWindowController {
    private let state: AppState
    private var window: NSWindow?

    init(state: AppState) {
        self.state = state
    }

    func show() {
        if window == nil {
            let window = SettingsWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 420),
                                        styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "MacTab 设置"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView(state: state))
            window.center()
            self.window = window
        }
        state.refreshLogin()
        // MacTab 是 LSUIElement，不会出现在 Dock；打开设置时临时把自己带到前台。
        // macOS 14 起 activate() 是协商式的，系统可能拒绝；被拒时 makeKeyAndOrderFront 只会把窗口排在前台应用的窗口后面，
        // 所以再 orderFrontRegardless 一次，保证窗口总在最前（此时不是 key 窗口，用户点一下即激活）
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
    }
}

/// agent 应用没有主菜单，Cmd+W 要自己接
private final class SettingsWindow: NSWindow {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // 只看这四个修饰键：deviceIndependentFlagsMask 含 Caps Lock，开着大写锁定时 Cmd+W 会失效
        if event.modifierFlags.intersection([.command, .shift, .option, .control]) == .command,
           event.charactersIgnoringModifiers == "w" {
            performClose(nil)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

private struct SettingsView: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                List(ThemeID.allCases, id: \.self, selection: themeSelection) { id in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(id.title)
                        Text(id.subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
                .frame(width: 210)
                ThemePreview(theme: state.theme)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Divider()
            HStack {
                Toggle("开机自动启动", isOn: Binding(get: { state.loginEnabled }, set: { state.setLogin($0) }))
                Spacer()
                permissionStatus
            }
            .padding(16)
        }
        .frame(width: 640, height: 420)
    }

    /// List 的单选绑定要求 Optional；取消选中时保持原主题
    private var themeSelection: Binding<ThemeID?> {
        Binding(get: { state.theme }, set: { if let id = $0 { state.theme = id } })
    }

    @ViewBuilder
    private var permissionStatus: some View {
        switch state.permission {
        case .granted:
            Label("辅助功能：已授权", systemImage: "checkmark.circle")
                .foregroundStyle(.green)
        case .missing:
            HStack {
                Label("辅助功能：未授权", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                Button("打开系统设置") { state.openAccessibilitySettings() }
            }
        case .tapFailed:
            HStack {
                Label("事件拦截创建失败", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                Button("打开系统设置") { state.openAccessibilitySettings() }
            }
        }
    }
}

private struct ThemePreview: NSViewRepresentable {
    let theme: ThemeID

    func makeNSView(context: Context) -> ThemePreviewView {
        ThemePreviewView()
    }

    func updateNSView(_ view: ThemePreviewView, context: Context) {
        view.theme = theme
    }
}
