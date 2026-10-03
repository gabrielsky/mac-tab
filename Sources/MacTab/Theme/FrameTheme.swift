import AppKit
import QuartzCore

/// 非角色主题的共同骨架：一个跟着选中格子滑动的框，外观由 style 决定
final class FrameTheme: SelectionTheme {
    private let style: (_ frame: CALayer, _ reduceMotion: Bool) -> Void
    private let frame = CALayer()
    private var host: ThemeHost?

    init(style: @escaping (_ frame: CALayer, _ reduceMotion: Bool) -> Void) {
        self.style = style
    }

    func install(on host: ThemeHost) {
        self.host = host
        guard let first = host.cellFrames.first else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        frame.bounds = CGRect(origin: .zero, size: first.size)
        style(frame, host.reduceMotion)
        host.under.addSublayer(frame)
        CATransaction.commit()
    }

    func select(_ index: Int, animated: Bool) {
        guard let host, host.cellFrames.indices.contains(index) else { return }
        let cell = host.cellFrames[index]
        ThemeMotion.move(frame, to: CGPoint(x: cell.midX, y: cell.midY), duration: ThemeMotion.slide,
                         animated: animated && !host.reduceMotion)
    }

    func uninstall() {
        frame.removeFromSuperlayer()
        // 循环动画可能挂在 style 加的子图层上（彩虹的 spin、跑马灯的 march），要一起停
        ([frame] + (frame.sublayers ?? [])).forEach { $0.removeAllAnimations() }
        host = nil
    }
}

extension FrameTheme {
    /// 经典：仿 macOS 26 原生切换器，一圈深色描边紧贴图标的可见部分
    static func classic() -> FrameTheme {
        FrameTheme { frame, _ in
            // 系统图标的圆角方块只占画布的 824/1024，四周是透明外圈；描边要包住圆角方块而不是画布
            let icon = frame.bounds.width / (1 + 2 * SwitcherLayout.insetRatio)
            let body = icon * 824 / 1024
            let ring = icon * 0.075
            frame.bounds = CGRect(x: 0, y: 0, width: body + 2 * ring, height: body + 2 * ring)
            frame.cornerCurve = .continuous
            frame.cornerRadius = body * 0.225 + ring
            frame.borderWidth = ring
            let dark = NSAppearance.currentDrawing().bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            frame.borderColor = (dark ? NSColor.white.withAlphaComponent(0.45) : NSColor.black.withAlphaComponent(0.6)).cgColor
        }
    }

    /// 强调色：系统强调色实色底；每次面板弹出都会新建主题，所以总是读到最新的强调色
    static func accent() -> FrameTheme {
        FrameTheme { frame, _ in
            frame.cornerRadius = 12
            frame.backgroundColor = NSColor.controlAccentColor.cgColor
        }
    }
}
