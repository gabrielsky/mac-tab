import AppKit
import ImageIO
import Metal
import QuartzCore
import UniformTypeIdentifiers
import XCTest
@testable import MacTab

/// 生成 README 的主题效果图帧；平时跳过，由 scripts/theme-shots.sh 设置 MACTAB_SHOTS_DIR 后运行，再合成 GIF。
/// 角色主题靠 asyncAfter 切换走路 / 待机，所以按真实时间推进 run loop；
/// 每帧用 CARenderer 离线渲染，遮罩、阴影等和屏幕上的合成一致，也不需要录屏权限。
/// 图层时钟由每帧的 timeOffset 驱动（见 Stage.time），不跟真实时钟走：动画的起始时刻取提交时的真实时间，
/// 总比按时间轴算的帧时刻晚一点，切换那一帧滑动还没开始、显示的是终点，下一帧又跳回起点
final class ThemeShotsTests: XCTestCase {
    /// 和 scripts/theme-shots.sh 里的 -framerate 一致
    static let fps = 20.0
    /// README 表格里每张图只有约 280pt 宽，1.5 倍在 Retina 屏上已经够清晰，GIF 也小一半
    static let scale: CGFloat = 1.5
    static let margin: CGFloat = 24
    /// 选中项右移两格再回到起点；最后一次切换后留 0.6 秒让动画落定，循环播放首尾相接
    static let steps: [(time: Double, index: Int)] = [(0.6, 2), (1.8, 3), (3.0, 2), (4.2, 1)]

    /// 一轮时长取循环动画周期的整数倍（霓虹 1.6 秒、跑马灯 0.6 秒、彩虹 2 秒），首尾不跳变
    static func duration(of theme: ThemeID) -> Double { theme == .rainbow ? 6 : 4.8 }

    func testRenderThemeFrames() throws {
        guard let out = ProcessInfo.processInfo.environment["MACTAB_SHOTS_DIR"] else {
            throw XCTSkip("只在 scripts/theme-shots.sh 里运行")
        }
        // 所有主题用同一画布尺寸，README 表格里对齐
        let sizes = ThemeID.allCases.map { id in
            let theme = id.make()
            return SwitcherLayout(count: ThemePreviewView.apps.count, availableWidth: ThemePreviewView.layoutWidth,
                                  extraTop: theme.extraTop, extraBottom: theme.extraBottom).size
        }
        let canvas = CGSize(width: sizes.map(\.width).max()! + 2 * Self.margin,
                            height: sizes.map(\.height).max()! + 2 * Self.margin)
        let renderer = try FrameRenderer(size: canvas, scale: Self.scale)

        for id in ThemeID.allCases {
            let stage = Stage(canvas: canvas)
            NSAppearance(named: .darkAqua)!.performAsCurrentDrawingAppearance { stage.show(id) }
            // CARenderer 换图层后，要等 run loop 转过一轮再画才生效（实测原地等待、重画、多次提交都不行），先空画一帧
            _ = try renderer.render(stage.root)
            Self.runLoop(until: CACurrentMediaTime() + 0.05)
            let start = CACurrentMediaTime()
            var pending = Self.steps[...]
            var frames: [CGImage] = []
            for k in 0..<Int(Self.duration(of: id) * Self.fps) {
                let t = Double(k) / Self.fps
                // 先跑 run loop 再拨时钟：两帧之间到点的回调，动画从上一帧的时刻开始，不会比该开始的时刻晚
                Self.runLoop(until: start + t)
                stage.time = t
                // 切换正好落在这一帧：滑动从这一帧的时刻开始，这一帧显示起点
                while let step = pending.first, step.time <= t {
                    stage.content.select(step.index)
                    pending.removeFirst()
                }
                frames.append(try renderer.render(stage.root))
            }
            stage.content.teardown()

            let dir = URL(fileURLWithPath: out).appendingPathComponent(id.rawValue)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            for (k, frame) in frames.enumerated() {
                try Self.writePNG(frame, to: dir.appendingPathComponent(String(format: "%03d.png", k)))
            }
        }
    }

    /// 跑 run loop 到指定时刻，期间触发主题的 asyncAfter 回调
    private static func runLoop(until time: CFTimeInterval) {
        while CACurrentMediaTime() < time {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: time - CACurrentMediaTime()))
        }
    }

    private static func writePNG(_ image: CGImage, to url: URL) throws {
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
    }
}

/// 效果图的场景：渐变背景上一块深色面板，里面是和设置预览一样的 SwitcherView。
/// 毛玻璃材质由窗口服务器合成、离线渲染不出来，这里用半透明深色底近似
private final class Stage {
    let root: NSView
    let content = SwitcherView()
    private let window: NSWindow
    private let panel = NSView()

    /// 场景的图层时间（秒）。根图层的 speed 为 0，整棵树的时间就停在 timeOffset 上；
    /// 新加的动画也从这个时刻开始，所以切换那一帧正好是滑动的起点
    var time: CFTimeInterval = 0 {
        didSet {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            root.layer?.timeOffset = time
            CATransaction.commit()
        }
    }

    init(canvas: CGSize) {
        root = NSView(frame: CGRect(origin: .zero, size: canvas))
        root.wantsLayer = true
        // 要在主题装上之前停住时钟，循环动画才从时间 0 开始，首尾帧对得上
        root.layer?.speed = 0
        root.layer?.timeOffset = 0
        let backdrop = CAGradientLayer()
        backdrop.frame = root.bounds
        backdrop.zPosition = -1
        backdrop.colors = [NSColor(hex: 0x3A5BA0).cgColor, NSColor(hex: 0x8A5BB0).cgColor]
        backdrop.startPoint = CGPoint(x: 0, y: 1)
        backdrop.endPoint = CGPoint(x: 1, y: 0)
        root.layer?.addSublayer(backdrop)

        panel.wantsLayer = true
        panel.layer?.backgroundColor = NSColor(white: 0.12, alpha: 0.75).cgColor
        root.addSubview(panel)
        panel.addSubview(content)

        // 窗口不显示，只为让 AppKit 按深色外观和屏幕缩放比例画标签、取图标
        window = NSWindow(contentRect: root.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentView = root
    }

    func show(_ id: ThemeID) {
        let layout = content.show(icons: ThemePreviewView.icons(), names: ThemePreviewView.apps.map(\.0), selected: 1,
                                  theme: id.make(), availableWidth: ThemePreviewView.layoutWidth)
        panel.frame = CGRect(x: (root.bounds.width - layout.size.width) / 2, y: (root.bounds.height - layout.size.height) / 2,
                             width: layout.size.width, height: layout.size.height).integral
        panel.layer?.cornerRadius = layout.cornerRadius
        content.setFrameOrigin(.zero)
    }
}

/// 用 CARenderer 把图层树画进 Metal 纹理再读回像素；画哪一时刻由 Stage.time 决定，和渲染时的真实时间无关
private final class FrameRenderer {
    private let queue: MTLCommandQueue
    private let texture: MTLTexture
    private let renderer: CARenderer
    private let scale: CGFloat
    private let width: Int
    private let height: Int

    init(size: CGSize, scale: CGFloat) throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        queue = try XCTUnwrap(device.makeCommandQueue())
        self.scale = scale
        width = Int(size.width * scale)
        height = Int(size.height * scale)
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .managed
        texture = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
        renderer = CARenderer(mtlTexture: texture, options: [
            kCARendererMetalCommandQueue: queue,
            kCARendererColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
        ])
        renderer.bounds = CGRect(x: 0, y: 0, width: width, height: height)
    }

    func render(_ view: NSView) throws -> CGImage {
        let root = try XCTUnwrap(view.layer)
        if renderer.layer !== root {
            renderer.layer = root
            // 放大到像素尺寸，并上下翻转：Metal 纹理原点在左上，图层坐标原点在左下
            root.sublayerTransform = CATransform3DConcat(CATransform3DMakeScale(scale, -scale, 1),
                                                         CATransform3DMakeTranslation(0, CGFloat(height), 0))
        }
        view.window?.displayIfNeeded() // 选中项变了，名称标签要重画
        // CARenderer 只画已提交的图层树：换图层、改选中项都要先提交
        CATransaction.flush()
        renderer.beginFrame(atTime: CACurrentMediaTime(), timeStamp: nil)
        renderer.addUpdate(renderer.bounds)
        renderer.render()
        renderer.endFrame()

        // CARenderer 在同一队列上提交绘制；排在它后面的同步拷贝完成后，像素才能读回
        let buffer = try XCTUnwrap(queue.makeCommandBuffer())
        let blit = try XCTUnwrap(buffer.makeBlitCommandEncoder())
        blit.synchronize(resource: texture)
        blit.endEncoding()
        buffer.commit()
        buffer.waitUntilCompleted()

        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        texture.getBytes(&bytes, bytesPerRow: width * 4, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
        let provider = try XCTUnwrap(CGDataProvider(data: Data(bytes) as CFData))
        return try XCTUnwrap(CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                                     space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                     bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue
                                         | CGBitmapInfo.byteOrder32Little.rawValue),
                                     provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
    }
}
