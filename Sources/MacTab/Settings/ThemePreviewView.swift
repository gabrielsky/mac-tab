import AppKit
import UniformTypeIdentifiers

/// 设置窗口右栏的实时预览：和真实面板一样的 HUD 底 + SwitcherView，选中项每 1.2 秒前进一格。
/// 窗口不可见时卸载主题、停掉计时器（spec T6）
final class ThemePreviewView: NSView {
    var theme: ThemeID = .classic {
        didSet { if theme != oldValue { rebuild() } }
    }

    /// 预览按这个宽度排版：5 个图标在右栏里放得下
    static let layoutWidth: CGFloat = 440
    /// 示例应用；README 效果图（ThemeShotsTests）也用这一组
    static let apps = [
        ("访达", "/System/Library/CoreServices/Finder.app"),
        ("Safari", "/Applications/Safari.app"),
        ("邮件", "/System/Applications/Mail.app"),
        ("备忘录", "/System/Applications/Notes.app"),
        ("终端", "/System/Applications/Utilities/Terminal.app"),
    ]

    private let background = SwitcherBackground()
    private let content = SwitcherView()
    private var timer: Timer?
    private var index = 1
    private var active = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        background.blendingMode = .withinWindow
        addSubview(background)
        background.addSubview(content)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        NotificationCenter.default.removeObserver(self)
        guard let window else {
            setActive(false)
            return
        }
        NotificationCenter.default.addObserver(self, selector: #selector(occlusionChanged),
                                               name: NSWindow.didChangeOcclusionStateNotification, object: window)
        occlusionChanged()
    }

    override func layout() {
        super.layout()
        centerContent()
    }

    /// 把 HUD 底按内容大小放在预览区正中
    private func centerContent() {
        let size = content.frame.size
        background.frame = CGRect(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2,
                                  width: size.width, height: size.height).integral
        content.setFrameOrigin(.zero)
    }

    @objc private func occlusionChanged() {
        setActive(window?.occlusionState.contains(.visible) == true)
    }

    private func setActive(_ on: Bool) {
        guard on != active else { return }
        active = on
        timer?.invalidate()
        timer = nil
        guard on else {
            content.teardown()
            return
        }
        // 减弱动态效果时不自动前进，停在第 2 个图标（index 跨显示周期保留，要重置）
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if reduceMotion { index = 1 }
        rebuild()
        guard !reduceMotion else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { [weak self] _ in self?.advance() }
    }

    private func rebuild() {
        guard active else { return }
        let layout = content.show(icons: Self.icons(), names: Self.apps.map(\.0), selected: index,
                                  theme: theme.make(), availableWidth: Self.layoutWidth)
        background.cornerRadius = layout.cornerRadius
        // 换主题可能改变面板高度（角色主题要额外空间），立即重新居中
        centerContent()
    }

    /// 示例应用的图标；应用不存在时用通用应用图标。
    /// 先解析软链接：Safari 在 /Applications 里是指向 Cryptexes 的软链接，直接取图标会带上替身箭头
    static func icons() -> [NSImage] {
        apps.map { _, path in
            FileManager.default.fileExists(atPath: path)
                ? NSWorkspace.shared.icon(forFile: URL(fileURLWithPath: path).resolvingSymlinksInPath().path)
                : NSWorkspace.shared.icon(for: .applicationBundle)
        }
    }

    private func advance() {
        index = (index + 1) % Self.apps.count
        content.select(index)
    }
}
