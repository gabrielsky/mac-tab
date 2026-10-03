import CoreGraphics
import XCTest
@testable import MacTab

/// 夹具来自 2026-09-29 在本机（macOS 26.6.2）的探测数据，见 spec 第 3 节
final class WindowRuleTests: XCTestCase {
    private static let finder: pid_t = 906, chatGPT: pid_t = 847, sequelAce: pid_t = 91317, acrobat: pid_t = 15901
    private static let overlayOnly: pid_t = 4242 // 构造的场景：只有非 layer 0 的窗口

    /// 真实数据经 CFDictionary 桥接后是 NSNumber，夹具保持一致
    private static func window(_ pid: pid_t, id: Int, layer: Int) -> [String: Any] {
        [kCGWindowOwnerPID as String: NSNumber(value: pid),
         kCGWindowNumber as String: NSNumber(value: id),
         kCGWindowLayer as String: NSNumber(value: layer)]
    }

    private static let infos: [[String: Any]] = [
        window(finder, id: 12818, layer: 0),           // 2560x30 菜单栏条
        window(finder, id: 2941, layer: 0),            // 64x64 @(0,940) 杂窗
        window(finder, id: 37, layer: -2147483603),    // 桌面图标层
        window(chatGPT, id: 8941, layer: 0),           // 500x500 @(0,940) 杂窗
        window(chatGPT, id: 220, layer: 0),            // 最小化的主窗口
        window(sequelAce, id: 4767, layer: 0),         // 应用被 Cmd+H 隐藏
        window(acrobat, id: 7672, layer: 0),           // 已 order out 的窗口
        window(acrobat, id: 7666, layer: 0),           // 在其他桌面（Space 502）
        window(overlayOnly, id: 12009, layer: 1000),   // 非 layer 0，即使属于某个 Space
    ]
    private static let spaces: [Int: [UInt64]] = [37: [1], 220: [1], 4767: [1], 7666: [502], 12009: [1]]

    private var result: Set<pid_t> {
        WindowRule.pidsWithWindows(Self.infos) { $0.flatMap { Self.spaces[$0] ?? [] } }
    }

    func testWindowlessFinderIsExcluded() { XCTAssertFalse(result.contains(Self.finder)) }
    func testMinimizedWindowCounts() { XCTAssertTrue(result.contains(Self.chatGPT)) }
    func testHiddenAppWindowCounts() { XCTAssertTrue(result.contains(Self.sequelAce)) }
    func testWindowOnOtherSpaceCounts() { XCTAssertTrue(result.contains(Self.acrobat)) }
    func testNonZeroLayerIgnoredEvenWithSpace() { XCTAssertFalse(result.contains(Self.overlayOnly)) }

    /// 每次 spacesOf 都是一次 IPC：每个应用最多查一次，非 layer 0 的窗口不查
    func testSpacesQueriedAtMostOncePerAppAndOnlyForLayer0() {
        var calls: [[Int]] = []
        _ = WindowRule.pidsWithWindows(Self.infos) { ids in
            calls.append(ids)
            return ids.flatMap { Self.spaces[$0] ?? [] }
        }
        let pidOf = Dictionary(uniqueKeysWithValues: Self.infos.map {
            ($0[kCGWindowNumber as String] as! Int, $0[kCGWindowOwnerPID as String] as! pid_t)
        })
        let pidsPerCall = calls.flatMap { Set($0.compactMap { pidOf[$0] }) }
        XCTAssertEqual(pidsPerCall.count, Set(pidsPerCall).count)
        XCTAssertTrue(Set(calls.joined()).isDisjoint(with: [37, 12009]))
    }
}

/// 夹具来自 2026-10-02 在本机的探测：Steam 登录窗口属于子进程 Steam Helper（accessory），主进程 steam_osx（regular）没有窗口
final class AppOwnerTests: XCTestCase {
    private static let steam: pid_t = 90533, steamHelper: pid_t = 90552, tunnelblick: pid_t = 75963
    private static let parents: [pid_t: pid_t] = [steamHelper: steam, steam: 1, tunnelblick: 1]
    private static let regular: Set<pid_t> = [steam]

    private func owner(_ pid: pid_t) -> pid_t {
        AppOwner.resolve(pid, isApp: Self.regular.contains) { Self.parents[$0] ?? 0 }
    }

    func testHelperResolvesToRegularParent() { XCTAssertEqual(owner(Self.steamHelper), Self.steam) }
    func testRegularAppResolvesToItself() { XCTAssertEqual(owner(Self.steam), Self.steam) }
    func testNoRegularAncestorResolvesToItself() { XCTAssertEqual(owner(Self.tunnelblick), Self.tunnelblick) }
}

final class MRUTests: XCTestCase {
    func testInitDeduplicatesKeepingFirstOccurrence() {
        // seededFromSystem 拼接「前台 + 屏幕层级 + 启动时间」时依赖这条去重规则
        XCTAssertEqual(MRU(order: [3, 1, 3, 2, 1]).order, [3, 1, 2])
    }

    func testActivatedMovesToFront() {
        var mru = MRU(order: [1, 2, 3])
        mru.activated(3)
        XCTAssertEqual(mru.order, [3, 1, 2])
        mru.activated(9) // 新启动的应用
        XCTAssertEqual(mru.order, [9, 3, 1, 2])
    }

    func testTerminatedIsRemoved() {
        var mru = MRU(order: [1, 2, 3])
        mru.terminated(2)
        XCTAssertEqual(mru.order, [1, 3])
    }

    func testSortedPutsKnownFirstThenUnknownInGivenOrder() {
        XCTAssertEqual(MRU(order: [3, 1, 2]).sorted([1, 7, 2, 5]), [1, 2, 7, 5])
    }
}
