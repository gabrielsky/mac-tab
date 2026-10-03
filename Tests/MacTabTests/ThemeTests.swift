import QuartzCore
import XCTest
@testable import MacTab

/// 所有主题都必须满足的约定：装上有东西，卸载干净，减弱动态效果时不动
final class ThemeContractTests: XCTestCase {
    private struct Fixture {
        let host: ThemeHost
        let icons: [CALayer]
    }

    private func makeFixture(reduceMotion: Bool) -> Fixture {
        // 搭建夹具本身不能产生隐式动画，否则「减弱动态效果时没有动画」的断言会被夹具污染
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        let root = CALayer()
        root.frame = CGRect(x: 0, y: 0, width: 400, height: 200)
        let under = CALayer(), over = CALayer()
        root.addSublayer(under)
        root.addSublayer(over)
        let frames = (0..<4).map { CGRect(x: 16 + CGFloat($0) * 72, y: 60, width: 72, height: 72) }
        let icons = frames.map { frame -> CALayer in
            let icon = CALayer()
            icon.frame = frame.insetBy(dx: 8, dy: 8)
            root.addSublayer(icon)
            return icon
        }
        let host = ThemeHost(under: under, over: over, cellFrames: frames, iconLayers: icons, reduceMotion: reduceMotion)
        return Fixture(host: host, icons: icons)
    }

    private func allLayers(_ layer: CALayer) -> [CALayer] {
        [layer] + (layer.sublayers ?? []).flatMap(allLayers)
    }

    func testEveryThemeCleansUpAfterItself() {
        for id in ThemeID.allCases {
            for reduceMotion in [false, true] {
                let f = makeFixture(reduceMotion: reduceMotion)
                let theme = id.make()
                theme.install(on: f.host)
                let added = (f.host.under.sublayers?.count ?? 0) + (f.host.over.sublayers?.count ?? 0)
                XCTAssertGreaterThan(added, 0, "\(id) 安装后没有加任何图层")
                for index in 0..<4 { theme.select(index, animated: true) }
                theme.select(2, animated: false)
                // 卸载后图层已脱离宿主，只能在卸载前记下主题装上的全部图层
                let installed = allLayers(f.host.under) + allLayers(f.host.over)
                theme.uninstall()
                XCTAssertEqual(f.host.under.sublayers ?? [], [], "\(id) 卸载后 under 仍有图层")
                XCTAssertEqual(f.host.over.sublayers ?? [], [], "\(id) 卸载后 over 仍有图层")
                for icon in f.icons {
                    XCTAssertTrue(CATransform3DIsIdentity(icon.transform), "\(id) 卸载后图标 transform 没有复原")
                }
                for layer in installed + f.icons {
                    XCTAssertEqual(layer.animationKeys() ?? [], [], "\(id) 卸载后仍有动画")
                }
            }
        }
    }

    func testReduceMotionMeansNoAnimations() {
        for id in ThemeID.allCases {
            let f = makeFixture(reduceMotion: true)
            let theme = id.make()
            theme.install(on: f.host)
            theme.select(1, animated: true)
            theme.select(3, animated: true)
            for layer in allLayers(f.host.under) + allLayers(f.host.over) + f.icons {
                XCTAssertEqual(layer.animationKeys() ?? [], [], "\(id) 在减弱动态效果时仍有动画")
            }
            theme.uninstall()
        }
    }

    func testFrameThemesCenterFrameOnSelectedCell() {
        for id in ThemeID.allCases {
            let theme = id.make()
            guard theme is FrameTheme else { continue }
            let f = makeFixture(reduceMotion: false)
            theme.install(on: f.host)
            theme.select(2, animated: false)
            let cell = f.host.cellFrames[2]
            XCTAssertEqual(f.host.under.sublayers?.first?.position, CGPoint(x: cell.midX, y: cell.midY), "\(id)")
            theme.uninstall()
        }
    }

    func testFrameThemesSlideWhenMotionAllowed() {
        for id in ThemeID.allCases {
            let theme = id.make()
            guard theme is FrameTheme else { continue }
            let f = makeFixture(reduceMotion: false)
            theme.install(on: f.host)
            theme.select(0, animated: false)
            theme.select(2, animated: true)
            let cell = f.host.cellFrames[2]
            let move = f.host.under.sublayers?.first?.animation(forKey: "move") as? CABasicAnimation
            XCTAssertNotNil(move, "\(id) 允许动态效果时选中框没有滑动")
            XCTAssertEqual(move?.duration, ThemeMotion.slide, "\(id)")
            XCTAssertEqual((move?.toValue as? NSValue)?.pointValue, CGPoint(x: cell.midX, y: cell.midY), "\(id)")
            theme.uninstall()
        }
    }

    func testCharacterThemesReserveRoomForTheCharacter() {
        XCTAssertGreaterThan(ThemeID.porter.make().extraBottom, 0)
        XCTAssertGreaterThan(ThemeID.lifter.make().extraBottom, 0)
        XCTAssertGreaterThan(ThemeID.cat.make().extraTop, 0)
    }

    func testLifterRaisesOnlyTheSelectedIcon() {
        let f = makeFixture(reduceMotion: false)
        let theme = ThemeID.lifter.make()
        theme.install(on: f.host)
        theme.select(1, animated: false)
        theme.select(3, animated: false)
        XCTAssertTrue(CATransform3DEqualToTransform(f.icons[3].transform, LifterTheme.liftTransform))
        for index in [0, 1, 2] {
            XCTAssertTrue(CATransform3DIsIdentity(f.icons[index].transform), "图标 \(index) 应该落回原位")
        }
        theme.uninstall()
    }

    func testLifterIgnoresStaleWalkAfterInstantSelect() {
        let f = makeFixture(reduceMotion: false)
        let theme = ThemeID.lifter.make()
        theme.install(on: f.host)
        theme.select(0, animated: false)
        theme.select(1, animated: true)
        theme.select(3, animated: false)
        // 等走向图标 1 的回调到点：它已被更新的选中作废，不能再把图标 1 举起来
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        XCTAssertTrue(CATransform3DEqualToTransform(f.icons[3].transform, LifterTheme.liftTransform))
        for index in [0, 1, 2] {
            XCTAssertTrue(CATransform3DIsIdentity(f.icons[index].transform), "图标 \(index) 应该落回原位")
        }
        theme.uninstall()
    }

    func testPorterIdlesAfterInstantSelectMidWalk() {
        let f = makeFixture(reduceMotion: false)
        let theme = ThemeID.porter.make()
        theme.install(on: f.host)
        theme.select(0, animated: false)
        theme.select(1, animated: true)
        theme.select(3, animated: false)
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        // 走路回调已作废，瞬移后必须直接回到待机帧，不能停在走路帧上。
        // 转过 run loop 后脱离渲染的图层动画会被 CA 丢掉，所以看模型层的 contents：逐帧循环总会先把它设成第一帧
        let person = f.host.over.sublayers?.first
        XCTAssertTrue(person?.contents as AnyObject? === Sprites.idleImages[0], "瞬移后小人没有回到待机")
        theme.uninstall()
    }
}

final class ThemeIDTests: XCTestCase {
    func testThemeIDsArePinned() {
        // rawValue 会存进 UserDefaults，改名会让用户的选择失效
        XCTAssertEqual(ThemeID.allCases.map(\.rawValue),
                       ["classic", "accent", "ornate", "neon", "rainbow", "marchingAnts", "porter", "lifter", "cat"])
        XCTAssertTrue(ThemeID.allCases.allSatisfy { !$0.title.isEmpty && !$0.subtitle.isEmpty })
    }
}

final class ThemeStoreTests: XCTestCase {
    private let suite = "MacTabThemeStoreTests"
    private var defaults: UserDefaults!

    override func setUp() {
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
    }

    func testDefaultsToClassic() {
        XCTAssertEqual(ThemeStore(defaults: defaults).current, .classic)
    }

    func testRoundTrip() {
        ThemeStore(defaults: defaults).current = .cat
        XCTAssertEqual(ThemeStore(defaults: defaults).current, .cat)
    }

    func testUnknownValueFallsBackToClassic() {
        defaults.set("sparkles", forKey: ThemeStore.key)
        XCTAssertEqual(ThemeStore(defaults: defaults).current, .classic)
    }
}
