import AppKit
import XCTest
@testable import MacTab

final class SwitcherBackgroundTests: XCTestCase {
    /// 窗口后方的材质由窗口服务器按视图的长方形渲染，layer 圆角裁不到；必须靠 maskImage 把四角遮掉
    func testMaskImageCutsCornersOfTheMaterial() throws {
        let view = SwitcherBackground(frame: NSRect(x: 0, y: 0, width: 200, height: 100))
        view.cornerRadius = 40
        let mask = try XCTUnwrap(view.maskImage)

        // 按面板尺寸拉伸画出遮罩：四角透明，中间不透明
        let rep = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 200, pixelsHigh: 100,
                                                 bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                                 colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        mask.draw(in: NSRect(x: 0, y: 0, width: 200, height: 100))
        NSGraphicsContext.restoreGraphicsState()

        for (x, y) in [(2, 2), (197, 2), (2, 97), (197, 97)] {
            XCTAssertEqual(rep.colorAt(x: x, y: y)?.alphaComponent ?? -1, 0, accuracy: 0.01, "corner (\(x), \(y))")
        }
        XCTAssertEqual(rep.colorAt(x: 100, y: 50)?.alphaComponent ?? -1, 1, accuracy: 0.01)
        XCTAssertEqual(rep.colorAt(x: 100, y: 2)?.alphaComponent ?? -1, 1, accuracy: 0.01)
    }
}
