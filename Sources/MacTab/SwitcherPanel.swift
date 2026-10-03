import AppKit

/// 仿系统 Cmd+Tab 的浮动面板：不抢焦点，只负责定位和显示；内容由 SwitcherView 负责
final class SwitcherPanel {
    var onHover: ((Int) -> Void)? {
        get { content.onHover }
        set { content.onHover = newValue }
    }
    var onClick: ((Int) -> Void)? {
        get { content.onClick }
        set { content.onClick = newValue }
    }

    private let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
    private let background = SwitcherBackground()
    private let content = SwitcherView()

    init() {
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.acceptsMouseMovedEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        background.blendingMode = .behindWindow
        panel.contentView = background
        background.addSubview(content)
    }

    /// 在鼠标所在屏幕的中央显示
    func show(apps: [NSRunningApplication], selected: Int, theme: SelectionTheme) {
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        guard let screen, !apps.isEmpty else { return }
        let layout = content.show(icons: apps.map(\.icon), names: apps.map { $0.localizedName ?? "" },
                                  selected: selected, theme: theme, availableWidth: screen.visibleFrame.width)
        let size = layout.size
        background.cornerRadius = layout.cornerRadius
        content.setFrameOrigin(.zero)
        panel.setFrame(NSRect(x: screen.frame.midX - size.width / 2, y: screen.frame.midY - size.height / 2,
                              width: size.width, height: size.height), display: false)
        panel.orderFrontRegardless()
    }

    func select(_ index: Int) {
        content.select(index)
    }

    /// 收起面板并卸载主题，保证后台没有动画在跑
    func dismiss() {
        panel.orderOut(nil)
        content.teardown()
    }
}
