import AppKit
import XCTest
@testable import MacTab

final class IconCellTests: XCTestCase {
    private let finder = NSWorkspace.shared.icon(forFile: "/System/Library/CoreServices/Finder.app")

    /// 应用图标的名义尺寸只有 32pt；位图必须覆盖图层的实际像素（96pt × 2），否则会被拉伸发糊
    func testBitmapCoversLayerPixels() throws {
        let image = try XCTUnwrap(IconCell.bitmap(of: finder, pointSize: 96, scale: 2))
        XCTAssertGreaterThanOrEqual(image.width, 192)
        XCTAssertGreaterThanOrEqual(image.height, 192)
    }

    /// 图标缩小时取小图，不会拿最大的 2048px 那张
    func testSmallIconStaysSmall() throws {
        let image = try XCTUnwrap(IconCell.bitmap(of: finder, pointSize: 16, scale: 1))
        XCTAssertGreaterThanOrEqual(image.width, 16)
        XCTAssertLessThanOrEqual(image.width, 64)
    }
}
