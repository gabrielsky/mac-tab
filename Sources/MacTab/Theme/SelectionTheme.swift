import AppKit
import QuartzCore

/// 主题安装时拿到的宿主信息；坐标系与 SwitcherView 相同（原点在左下）
struct ThemeHost {
    /// 图标下方的图层：选中框放这里
    let under: CALayer
    /// 图标上方的图层：角色放这里
    let over: CALayer
    /// 每个图标格子的 frame
    let cellFrames: [CGRect]
    /// 每个图标的图层；举重小人会改它们的 transform，卸载时必须恢复 identity
    let iconLayers: [CALayer]
    /// 系统开了「减弱动态效果」：不滑动、不循环
    let reduceMotion: Bool
}

/// 选中效果主题：装到 SwitcherView 上，跟着选中项移动，收起时卸载
protocol SelectionTheme: AnyObject {
    /// 图标行上方、下方需要额外留出的高度（pt），角色主题用来放角色
    var extraTop: CGFloat { get }
    var extraBottom: CGFloat { get }
    func install(on host: ThemeHost)
    func select(_ index: Int, animated: Bool)
    /// 移除自己加的全部图层和动画，并把图标图层的 transform 恢复为 identity
    func uninstall()
}

extension SelectionTheme {
    var extraTop: CGFloat { 0 }
    var extraBottom: CGFloat { 0 }
}

enum ThemeMotion {
    /// 非角色主题选中框的滑动时长：短一点，连按 Tab 才跟手
    static let slide: CFTimeInterval = 0.15

    /// 把图层移到新位置；animated 时从当前显示位置（动画中途也算）平滑转向新目标，不排队
    static func move(_ layer: CALayer, to position: CGPoint, duration: CFTimeInterval, animated: Bool) {
        let from = layer.presentation()?.position ?? layer.position
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.position = position
        CATransaction.commit()
        guard animated else {
            layer.removeAnimation(forKey: "move")
            return
        }
        let animation = CABasicAnimation(keyPath: "position")
        animation.fromValue = NSValue(point: from)
        animation.toValue = NSValue(point: position)
        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer.add(animation, forKey: "move")
    }
}

extension NSColor {
    /// 0xRRGGBB，sRGB，不透明
    convenience init(hex: UInt32) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}
