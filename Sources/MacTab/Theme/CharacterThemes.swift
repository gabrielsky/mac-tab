import AppKit
import QuartzCore

/// 角色主题共用：32pt 的像素精灵图层（16×16 像素放大 2 倍）
private enum SpriteLayer {
    static let size: CGFloat = 32
    /// 走路动画时长：角色从一个格子走到另一个格子
    static let walkDuration: CFTimeInterval = 0.3

    static func make() -> CALayer {
        let layer = CALayer()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.bounds = CGRect(x: 0, y: 0, width: size, height: size)
        layer.magnificationFilter = .nearest
        layer.contentsGravity = .resize
        CATransaction.commit()
        return layer
    }

    /// 停止逐帧动画，静止显示一帧
    static func still(_ layer: CALayer, _ image: CGImage) {
        layer.removeAnimation(forKey: "frames")
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.contents = image
        CATransaction.commit()
    }

    /// 逐帧循环播放；reduceMotion 时只显示第一帧
    static func loop(_ layer: CALayer, _ frames: [CGImage], keyTimes: [NSNumber]? = nil,
                     duration: CFTimeInterval, reduceMotion: Bool) {
        still(layer, frames[0])
        guard !reduceMotion else { return }
        let animation = CAKeyframeAnimation(keyPath: "contents")
        animation.values = frames
        animation.keyTimes = keyTimes ?? (0...frames.count).map { NSNumber(value: Double($0) / Double(frames.count)) }
        animation.calculationMode = .discrete
        animation.duration = duration
        animation.repeatCount = .infinity
        layer.add(animation, forKey: "frames")
    }
}

/// 搬运小人：小人站在选中框的左下方，切换时走过去，把框拖到新图标
final class PorterTheme: SelectionTheme {
    let extraBottom: CGFloat = 28
    private let frame = CALayer()
    private let person = SpriteLayer.make()
    private var host: ThemeHost?
    /// 每次选中加一；走完时编号对不上说明中途又换了目标，不切回待机
    private var walkToken = 0

    func install(on host: ThemeHost) {
        self.host = host
        guard let first = host.cellFrames.first else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        frame.bounds = CGRect(origin: .zero, size: first.size)
        frame.cornerRadius = 12
        frame.backgroundColor = NSColor.white.withAlphaComponent(0.12).cgColor
        host.under.addSublayer(frame)
        host.over.addSublayer(person)
        CATransaction.commit()
        idle()
    }

    func select(_ index: Int, animated: Bool) {
        guard let host, host.cellFrames.indices.contains(index) else { return }
        let cell = host.cellFrames[index]
        let move = animated && !host.reduceMotion
        ThemeMotion.move(frame, to: CGPoint(x: cell.midX, y: cell.midY), duration: SpriteLayer.walkDuration, animated: move)
        // 小人站在格子左下角的下方
        ThemeMotion.move(person, to: CGPoint(x: cell.minX + 14, y: cell.minY - 12), duration: SpriteLayer.walkDuration, animated: move)
        walkToken += 1 // 任何新的选中都作废之前没走完的回调
        let token = walkToken
        guard move else {
            idle() // 瞬移：没有走路回调来切回待机，这里直接切
            return
        }
        SpriteLayer.loop(person, Sprites.walkImages, duration: 0.4, reduceMotion: false)
        DispatchQueue.main.asyncAfter(deadline: .now() + SpriteLayer.walkDuration) { [weak self] in
            guard let self, self.walkToken == token else { return }
            self.idle()
        }
    }

    func uninstall() {
        walkToken += 1
        frame.removeFromSuperlayer()
        person.removeFromSuperlayer()
        frame.removeAllAnimations()
        person.removeAllAnimations()
        host = nil
    }

    /// 待机：大部分时间睁眼，每 2 秒眨一下
    private func idle() {
        guard let host else { return }
        SpriteLayer.loop(person, Sprites.idleImages, keyTimes: [0, 0.92, 1], duration: 2, reduceMotion: host.reduceMotion)
    }
}

/// 举重小人：小人在选中图标下方托举，图标上移 8pt、放大到 1.12 倍
final class LifterTheme: SelectionTheme {
    static let liftTransform = CATransform3DConcat(CATransform3DMakeScale(1.12, 1.12, 1), CATransform3DMakeTranslation(0, 8, 0))

    let extraBottom: CGFloat = 28
    private let person = SpriteLayer.make()
    private var host: ThemeHost?
    private var lifted: Int?
    private var walkToken = 0

    func install(on host: ThemeHost) {
        self.host = host
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        host.over.addSublayer(person)
        CATransaction.commit()
        SpriteLayer.still(person, Sprites.liftImage)
    }

    func select(_ index: Int, animated: Bool) {
        guard let host, host.cellFrames.indices.contains(index) else { return }
        let cell = host.cellFrames[index]
        let move = animated && !host.reduceMotion
        setIcon(lifted, raised: false, animated: move) // 旧图标先落回原位
        lifted = nil
        ThemeMotion.move(person, to: CGPoint(x: cell.midX, y: cell.minY - 12), duration: SpriteLayer.walkDuration, animated: move)
        walkToken += 1 // 任何新的选中都作废之前没走完的回调
        let token = walkToken
        guard move else {
            lift(index)
            return
        }
        SpriteLayer.loop(person, Sprites.walkImages, duration: 0.4, reduceMotion: false)
        // 走到新图标下面再把它举起来
        DispatchQueue.main.asyncAfter(deadline: .now() + SpriteLayer.walkDuration) { [weak self] in
            guard let self, self.walkToken == token else { return }
            self.lift(index, animated: true)
        }
    }

    func uninstall() {
        walkToken += 1
        person.removeFromSuperlayer()
        person.removeAllAnimations()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        host?.iconLayers.forEach {
            $0.removeAllAnimations()
            $0.transform = CATransform3DIdentity
        }
        CATransaction.commit()
        lifted = nil
        host = nil
    }

    private func lift(_ index: Int, animated: Bool = false) {
        SpriteLayer.still(person, Sprites.liftImage)
        setIcon(index, raised: true, animated: animated)
        lifted = index
    }

    private func setIcon(_ index: Int?, raised: Bool, animated: Bool) {
        guard let index, let host, host.iconLayers.indices.contains(index) else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(!animated)
        CATransaction.setAnimationDuration(ThemeMotion.slide)
        host.iconLayers[index].transform = raised ? Self.liftTransform : CATransform3DIdentity
        CATransaction.commit()
    }
}

/// 跳跳猫：像素猫蹲在选中图标顶上，切换时沿抛物线跳过去，待机时摆尾巴
final class CatTheme: SelectionTheme {
    let extraTop: CGFloat = 24
    private let cat = SpriteLayer.make()
    private var host: ThemeHost?
    private static let hopDuration: CFTimeInterval = 0.35

    func install(on host: ThemeHost) {
        self.host = host
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        host.over.addSublayer(cat)
        CATransaction.commit()
        SpriteLayer.loop(cat, Sprites.catImages, duration: 1.2, reduceMotion: host.reduceMotion)
    }

    func select(_ index: Int, animated: Bool) {
        guard let host, host.cellFrames.indices.contains(index) else { return }
        let cell = host.cellFrames[index]
        // 精灵底边比格子顶边低 8pt，落在系统图标自带的透明外圈里，看起来正好蹲在图标上
        let target = CGPoint(x: cell.midX, y: cell.maxY + 8)
        let from = cat.presentation()?.position ?? cat.position
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        cat.position = target
        CATransaction.commit()
        guard animated && !host.reduceMotion else {
            cat.removeAnimation(forKey: "hop")
            return
        }
        let path = CGMutablePath()
        path.move(to: from)
        path.addQuadCurve(to: target, control: CGPoint(x: (from.x + target.x) / 2, y: max(from.y, target.y) + 30))
        let hop = CAKeyframeAnimation(keyPath: "position")
        hop.path = path
        hop.duration = Self.hopDuration
        hop.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        cat.add(hop, forKey: "hop")
    }

    func uninstall() {
        cat.removeFromSuperlayer()
        cat.removeAllAnimations()
        host = nil
    }
}
