import Foundation
import XCTest
@testable import MacTab

/// 中文翻译在 Resources/zh-Hans.lproj，由 assemble-app.sh 拷进 app。
/// 测试进程的 Bundle.main 不是 app，取到的文案就是英文原文，也就是翻译表的键
final class LocalizationTests: XCTestCase {
    private static let chinese: [String: String]? = {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return NSDictionary(contentsOf: root.appendingPathComponent("Resources/zh-Hans.lproj/Localizable.strings")) as? [String: String]
    }()

    /// 语法错（比如漏了分号）时整个文件解析失败，界面会全部退回英文
    func testChineseStringsFileParses() {
        XCTAssertNotNil(Self.chinese)
    }

    func testEveryThemeHasChineseTitleAndSubtitle() throws {
        let chinese = try XCTUnwrap(Self.chinese)
        for id in ThemeID.allCases {
            XCTAssertNotNil(chinese[id.title], "缺少翻译：\(id.title)")
            XCTAssertNotNil(chinese[id.subtitle], "缺少翻译：\(id.subtitle)")
        }
    }
}
