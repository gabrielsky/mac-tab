import AppKit
import QuartzCore

extension FrameTheme {
    /// 花框：金色 3pt 双线边框（1pt 线 + 1pt 空 + 1pt 线），外圈 1pt 点线偏移 3pt，四角各一个小菱形
    static func ornate() -> FrameTheme {
        FrameTheme { frame, _ in
            let gold = NSColor(hex: 0xEF9F27).cgColor
            let light = NSColor(hex: 0xFAC775).cgColor
            let bounds = frame.bounds
            frame.cornerRadius = 12
            frame.borderWidth = 1
            frame.borderColor = gold

            let inner = CALayer()
            inner.frame = bounds.insetBy(dx: 2, dy: 2)
            inner.cornerRadius = 10
            inner.borderWidth = 1
            inner.borderColor = gold
            frame.addSublayer(inner)

            let outer = bounds.insetBy(dx: -3, dy: -3)
            let dotted = CAShapeLayer()
            dotted.path = CGPath(roundedRect: outer, cornerWidth: 15, cornerHeight: 15, transform: nil)
            dotted.fillColor = nil
            dotted.strokeColor = light
            dotted.lineWidth = 1
            dotted.lineDashPattern = [1, 2]
            frame.addSublayer(dotted)

            let corners = [CGPoint(x: outer.minX, y: outer.minY), CGPoint(x: outer.maxX, y: outer.minY),
                           CGPoint(x: outer.minX, y: outer.maxY), CGPoint(x: outer.maxX, y: outer.maxY)]
            for corner in corners {
                let path = CGMutablePath()
                path.move(to: CGPoint(x: corner.x, y: corner.y + 4))
                path.addLine(to: CGPoint(x: corner.x + 4, y: corner.y))
                path.addLine(to: CGPoint(x: corner.x, y: corner.y - 4))
                path.addLine(to: CGPoint(x: corner.x - 4, y: corner.y))
                path.closeSubpath()
                let diamond = CAShapeLayer()
                diamond.path = path
                diamond.fillColor = gold
                frame.addSublayer(diamond)
            }
        }
    }

    /// 霓虹：粉色 2pt 描边加外发光；发光半径 3↔12pt 呼吸，1.6 秒一轮，每轮末尾闪一下
    static func neon() -> FrameTheme {
        FrameTheme { frame, reduceMotion in
            frame.cornerRadius = 12
            frame.borderWidth = 2
            frame.borderColor = NSColor(hex: 0xED93B1).cgColor
            frame.shadowColor = NSColor(hex: 0xD4537E).cgColor
            frame.shadowOpacity = 1
            frame.shadowOffset = .zero
            frame.shadowRadius = 3
            guard !reduceMotion else { return }

            let glow = CAKeyframeAnimation(keyPath: "shadowRadius")
            glow.values = [3, 12, 3, 1, 3]
            glow.keyTimes = [0, 0.5, 0.9, 0.93, 1]
            glow.duration = 1.6
            glow.repeatCount = .infinity
            frame.add(glow, forKey: "glow")

            let flicker = CAKeyframeAnimation(keyPath: "opacity")
            flicker.values = [1, 1, 0.4, 1]
            flicker.keyTimes = [0, 0.9, 0.93, 1]
            flicker.duration = 1.6
            flicker.repeatCount = .infinity
            frame.add(flicker, forKey: "flicker")
        }
    }

    /// 彩虹流光：3pt 宽的彩虹锥形渐变环，2 秒转一圈
    static func rainbow() -> FrameTheme {
        FrameTheme { frame, reduceMotion in
            let bounds = frame.bounds
            // 环形遮罩固定不动，只转里面的渐变，所以看起来是颜色沿边框流动
            let ring = CAShapeLayer()
            ring.path = CGPath(roundedRect: bounds.insetBy(dx: 1.5, dy: 1.5), cornerWidth: 11, cornerHeight: 11, transform: nil)
            ring.fillColor = nil
            ring.strokeColor = NSColor.black.cgColor
            ring.lineWidth = 3
            frame.mask = ring

            // 渐变层边长取框的对角线，旋转时四角始终有颜色
            let side = hypot(bounds.width, bounds.height)
            let gradient = CAGradientLayer()
            gradient.type = .conic
            gradient.bounds = CGRect(x: 0, y: 0, width: side, height: side)
            gradient.position = CGPoint(x: bounds.midX, y: bounds.midY)
            gradient.startPoint = CGPoint(x: 0.5, y: 0.5)
            gradient.endPoint = CGPoint(x: 0.5, y: 0)
            gradient.colors = [0xE24B4A, 0xEF9F27, 0x97C459, 0x5DCAA5, 0x378ADD, 0x7F77DD, 0xD4537E, 0xE24B4A]
                .map { NSColor(hex: $0).cgColor }
            frame.addSublayer(gradient)
            guard !reduceMotion else { return }

            let spin = CABasicAnimation(keyPath: "transform.rotation.z")
            spin.fromValue = 0
            spin.toValue = -2 * Double.pi
            spin.duration = 2
            spin.repeatCount = .infinity
            gradient.add(spin, forKey: "spin")
        }
    }

    /// 跑马灯：薄荷绿 2pt 虚线框（5/3），虚线沿边框行进，0.6 秒一周期
    static func marchingAnts() -> FrameTheme {
        FrameTheme { frame, reduceMotion in
            let ants = CAShapeLayer()
            ants.path = CGPath(roundedRect: frame.bounds.insetBy(dx: 1, dy: 1), cornerWidth: 11, cornerHeight: 11, transform: nil)
            ants.fillColor = nil
            ants.strokeColor = NSColor(hex: 0x9FE1CB).cgColor
            ants.lineWidth = 2
            ants.lineDashPattern = [5, 3]
            frame.addSublayer(ants)
            guard !reduceMotion else { return }

            let march = CABasicAnimation(keyPath: "lineDashPhase")
            march.fromValue = 0
            march.toValue = -8 // 5 + 3，正好走完一个虚线周期，循环无跳变
            march.duration = 0.6
            march.repeatCount = .infinity
            ants.add(march, forKey: "march")
        }
    }
}
