import AppKit
import QuartzCore

/// 面板和设置预览共用的内容：图标行 + 名称标签 + 当前主题
final class SwitcherView: NSView {
    var onHover: ((Int) -> Void)?
    var onClick: ((Int) -> Void)?

    private let under = CALayer()
    private let over = CALayer()
    private let nameLabel = NSTextField(labelWithString: "")
    private var cells: [IconCell] = []
    private var names: [String] = []
    private var theme: SelectionTheme?
    private var layout: SwitcherLayout?
    private var selected = -1

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        // 选中框在图标下面，角色在图标上面
        under.zPosition = -1
        over.zPosition = 1
        layer?.addSublayer(under)
        layer?.addSublayer(over)
        nameLabel.alignment = .center
        nameLabel.lineBreakMode = .byTruncatingTail
        addSubview(nameLabel)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// 按给定主题重建内容，并把自己调整到布局尺寸；返回布局供调用方摆放窗口
    @discardableResult
    func show(icons: [NSImage?], names: [String], selected: Int, theme: SelectionTheme, availableWidth: CGFloat) -> SwitcherLayout {
        teardown()
        let layout = SwitcherLayout(count: icons.count, availableWidth: availableWidth,
                                    extraTop: theme.extraTop, extraBottom: theme.extraBottom)
        setFrameSize(layout.size)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        under.frame = bounds
        over.frame = bounds
        CATransaction.commit()

        cells = icons.enumerated().map { index, icon in
            let cell = IconCell(frame: layout.cellFrames[index], icon: icon, inset: layout.cellInset)
            cell.onHover = { [weak self] in self?.onHover?(index) }
            cell.onClick = { [weak self] in self?.onClick?(index) }
            addSubview(cell)
            return cell
        }
        self.names = names
        self.layout = layout
        nameLabel.font = .systemFont(ofSize: SwitcherLayout.fontSize, weight: .semibold)

        theme.install(on: ThemeHost(under: under, over: over, cellFrames: layout.cellFrames,
                                    iconLayers: cells.map(\.iconLayer),
                                    reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion))
        self.theme = theme
        select(selected, animated: false)
        return layout
    }

    func select(_ index: Int, animated: Bool = true) {
        // 悬停会反复报同一个下标，不重复触发动画
        guard index != selected else { return }
        selected = index
        theme?.select(index, animated: animated)
        nameLabel.stringValue = names.indices.contains(index) ? names[index] : ""
        // 和原生一样，名称跟着选中图标走（直接跳过去，不滑动）
        // cellSize 含文字单元两侧的内边距；intrinsicContentSize 不含，按它摆放末尾会被截成「…」
        if let layout, let text = nameLabel.cell?.cellSize {
            nameLabel.frame = layout.labelFrame(under: index, textSize: text)
        }
    }

    /// 卸载主题并清空图标；面板收起、预览不可见时调用，保证后台没有动画在跑
    func teardown() {
        theme?.uninstall()
        theme = nil
        cells.forEach { $0.removeFromSuperview() }
        cells = []
        names = []
        layout = nil
        selected = -1
        nameLabel.stringValue = ""
    }
}

/// 面板底：HUD 材质随系统外观；浅色外观下再压暗一层，贴近原生切换器的中灰
final class SwitcherBackground: NSVisualEffectView {
    /// layer 圆角只裁得到本进程画的内容（压暗层、图标）；窗口后方的材质由窗口服务器按长方形渲染，
    /// 开了「减少透明度」时是一块浅色实底，只有 maskImage 能把它的四角遮掉
    var cornerRadius: CGFloat = 0 {
        didSet {
            layer?.cornerRadius = cornerRadius
            maskImage = Self.roundedMask(radius: cornerRadius)
        }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        material = .hudWindow
        state = .active
        wantsLayer = true
        layer?.masksToBounds = true
        // NSBox 的填充色是动态色，系统切换外观时自动重画
        let tint = NSBox(frame: bounds)
        tint.boxType = .custom
        tint.borderWidth = 0
        tint.fillColor = NSColor(name: nil) {
            $0.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? .clear : NSColor.black.withAlphaComponent(0.18)
        }
        tint.autoresizingMask = [.width, .height]
        addSubview(tint)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// 可拉伸的圆角遮罩：四角按 capInsets 保持原样，中间拉伸
    private static func roundedMask(radius: CGFloat) -> NSImage {
        let edge = 2 * radius + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }
}

/// 一个图标格子：负责鼠标事件，图标画在 iconLayer 上
final class IconCell: NSView {
    var onHover: (() -> Void)?
    var onClick: (() -> Void)?
    /// 图标用独立图层显示：主题可以安全地改它的 transform（NSImageView 的图层会被 AppKit 布局覆盖）
    let iconLayer = CALayer()
    private let icon: NSImage?

    init(frame: NSRect, icon: NSImage?, inset: CGFloat) {
        self.icon = icon
        super.init(frame: frame)
        wantsLayer = true
        // iconLayer 是自建的子图层，默认有隐式动画；初始摆放不能动，否则每次弹出面板图标都会从原点「长」出来
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        iconLayer.frame = bounds.insetBy(dx: inset, dy: inset)
        iconLayer.contentsGravity = .resizeAspect
        layer?.addSublayer(iconLayer)
        CATransaction.commit()
        updateIconContents()
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .activeAlways, .inVisibleRect], owner: self))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    // 换到不同缩放比例的屏幕时，重新取合适分辨率的图标
    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        updateIconContents()
    }

    private func updateIconContents() {
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        iconLayer.contentsScale = scale
        iconLayer.contents = icon.flatMap { Self.bitmap(of: $0, pointSize: iconLayer.bounds.width, scale: scale) }
        CATransaction.commit()
    }

    /// 按图层的实际像素取图标位图（取不小于该尺寸的最小一张 rep）。
    /// 不能用 layerContents(forContentsScale:)：它按图标的名义尺寸（32pt）× 缩放栅格化，再拉伸到 96pt 的图层上就糊了
    static func bitmap(of icon: NSImage, pointSize: CGFloat, scale: CGFloat) -> CGImage? {
        var rect = CGRect(x: 0, y: 0, width: pointSize * scale, height: pointSize * scale)
        return icon.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }

    // 只响应真实的鼠标移动：面板刚好弹在光标下面时，不会改变选中项
    override func mouseMoved(with event: NSEvent) { onHover?() }
    override func mouseDown(with event: NSEvent) { onClick?() }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    // 点击落在图标上时，也由 cell 自己处理
    override func hitTest(_ point: NSPoint) -> NSView? { frame.contains(point) ? self : nil }
}
