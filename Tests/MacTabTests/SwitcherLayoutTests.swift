import XCTest
@testable import MacTab

final class SwitcherLayoutTests: XCTestCase {
    func testFewAppsUseFullSizeIconsWithNativeProportions() {
        let layout = SwitcherLayout(count: 3, availableWidth: 1440, extraTop: 0, extraBottom: 0)
        XCTAssertEqual(layout.icon, 128)
        // 格子 = 图标四周各放大 4.5%，相邻格子紧挨，所以图标间空隙 = 图标的 9%
        XCTAssertEqual(layout.cellInset, 5.76, accuracy: 0.001)
        XCTAssertEqual(layout.cellFrames.count, 3)
        XCTAssertEqual(layout.cellFrames[0].width, 139.52, accuracy: 0.001)
        XCTAssertEqual(layout.cellFrames[1].minX, layout.cellFrames[0].maxX, accuracy: 0.001)
        // 面板边缘到图标 = 图标的 35%
        XCTAssertEqual(layout.cellFrames[0].minX, 39.04, accuracy: 0.001) // 44.8 - 5.76
        XCTAssertEqual(layout.size.width, 496.64, accuracy: 0.001) // 44.8 + 3 × 128 + 2 × 11.52 + 44.8
        // 高 = 名称区（底边距 12.8 + 字高 16 × 1.25 + 空隙 4）+ 格子 + 顶边距（44.8 - 5.76）
        XCTAssertEqual(layout.cellFrames[0].minY, 36.8, accuracy: 0.001)
        XCTAssertEqual(layout.size.height, 215.36, accuracy: 0.001) // 36.8 + 139.52 + 39.04
        XCTAssertEqual(layout.cornerRadius, 48.64, accuracy: 0.001) // 128 × 0.38
    }

    func testExtraRoomRaisesRowAndGrowsPanel() {
        let plain = SwitcherLayout(count: 3, availableWidth: 1440, extraTop: 0, extraBottom: 0)
        let layout = SwitcherLayout(count: 3, availableWidth: 1440, extraTop: 24, extraBottom: 28)
        XCTAssertEqual(layout.size.height, plain.size.height + 52, accuracy: 0.001)
        XCTAssertEqual(layout.cellFrames[0].minY, plain.cellFrames[0].minY + 28, accuracy: 0.001)
        // 名称标签的高度位置不变：角色在图标和名称之间
        let text = CGSize(width: 50, height: 20)
        XCTAssertEqual(layout.labelFrame(under: 0, textSize: text).minY, plain.labelFrame(under: 0, textSize: text).minY)
    }

    func testManyAppsShrinkToFit90PercentOfWidth() {
        let layout = SwitcherLayout(count: 30, availableWidth: 1684, extraTop: 0, extraBottom: 0)
        XCTAssertLessThan(layout.icon, 128)
        // 空隙跟着图标一起缩：30 个应用时图标仍有 45pt（固定 16pt 空隙时只有 34pt）
        XCTAssertGreaterThanOrEqual(layout.icon, 45)
        XCTAssertLessThanOrEqual(layout.size.width, 1684 * 0.9)
        XCTAssertEqual(layout.cellFrames[29].maxX, layout.size.width - layout.icon * 0.35 + layout.cellInset, accuracy: 0.001)
    }

    func testLabelSitsCenteredUnderSelectedIcon() {
        let layout = SwitcherLayout(count: 5, availableWidth: 1440, extraTop: 0, extraBottom: 0)
        let frame = layout.labelFrame(under: 2, textSize: CGSize(width: 60, height: 20))
        XCTAssertEqual(frame.midX, layout.cellFrames[2].midX, accuracy: 0.001)
        XCTAssertEqual(frame.size, CGSize(width: 60, height: 20))
    }

    func testLabelClearsCellsSoThemesDoNotCoverIt() {
        // 边框类主题画满整个格子，角色站在格子下方的额外空间里：名称必须在它们下面
        for extraBottom: CGFloat in [0, 28] {
            let layout = SwitcherLayout(count: 5, availableWidth: 1440, extraTop: 0, extraBottom: extraBottom)
            let text = CGSize(width: 60, height: ceil(SwitcherLayout.fontSize * 1.4))
            XCTAssertLessThanOrEqual(layout.labelFrame(under: 0, textSize: text).maxY,
                                     layout.cellFrames[0].minY - extraBottom)
        }
    }

    func testLabelStaysInsidePanel() {
        let layout = SwitcherLayout(count: 3, availableWidth: 1440, extraTop: 0, extraBottom: 0)
        let inset = layout.icon * 0.35 / 2
        let nearEdge = layout.labelFrame(under: 0, textSize: CGSize(width: 300, height: 20))
        XCTAssertEqual(nearEdge.minX, inset, accuracy: 0.001)
        let tooWide = layout.labelFrame(under: 1, textSize: CGSize(width: 5000, height: 20))
        XCTAssertEqual(tooWide.minX, inset, accuracy: 0.001)
        XCTAssertEqual(tooWide.maxX, layout.size.width - inset, accuracy: 0.001)
    }
}
