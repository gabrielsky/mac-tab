import AppKit
import CoreGraphics

/// spec 第 3 节：应用有窗口 ⟺ 存在一个 layer == 0 且属于至少一个 Space 的窗口。
/// 最小化、隐藏、在其他桌面的窗口都属于某个 Space；菜单栏条和屏幕外杂窗不属于任何 Space。
/// ponytail: Chrome、千牛等应用有少量属于 Space 的弹出杂窗，关闭全部窗口后仍可能显示；
/// 需要时再对当前 Space 的窗口加一层 AX AXStandardWindow 过滤（注意 macOS 26 上最小化窗口的 subrole 报成 AXDialog，过滤时要放行最小化窗口）。
enum WindowRule {
    /// spacesOf：返回传入这批窗口所属 Space 的并集。每个应用只调用一次（一次 IPC）。
    /// ponytail: CGSCopySpacesForWindows 返回并集是在 macOS 26.6 上实测的；
    /// 将来系统改了这个语义，就退回每个窗口单独查一次。
    static func pidsWithWindows(_ windowInfos: [[String: Any]], spacesOf: ([Int]) -> [UInt64]) -> Set<pid_t> {
        var layer0 = [pid_t: [Int]]()
        for info in windowInfos {
            guard let pid = info[kCGWindowOwnerPID as String] as? pid_t,
                  info[kCGWindowLayer as String] as? Int == 0,
                  let id = info[kCGWindowNumber as String] as? Int else { continue }
            layer0[pid, default: []].append(id)
        }
        return Set(layer0.filter { !spacesOf($0.value).isEmpty }.keys)
    }

    static func currentPidsWithWindows() -> Set<pid_t> {
        let infos = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
        let cid = CGSMainConnectionID()
        return pidsWithWindows(infos) { ids in
            (CGSCopySpacesForWindows(cid, 0x7, ids as CFArray)?.takeRetainedValue() as? [UInt64]) ?? []
        }
    }
}

/// 有些应用的窗口由子进程持有：Steam 的登录窗口属于 Steam Helper（accessory），主进程 steam_osx（regular）自己没有窗口；
/// 激活 steam_osx 时它会把前台交给 Helper。所以窗口和激活都要归到最近的 regular 祖先进程，跟原生切换器显示「Steam」一致。
/// ponytail: 只沿父进程链找；由 launchd 拉起的 XPC 助手进程（父进程是 1）归不回去，遇到这类应用再按 bundle 路径归属。
enum AppOwner {
    /// 沿父进程链向上，返回第一个满足 isApp 的进程；都不满足就返回 pid 本身
    static func resolve(_ pid: pid_t, isApp: (pid_t) -> Bool, parent: (pid_t) -> pid_t = parentPID) -> pid_t {
        var p = pid
        while p > 1 {
            if isApp(p) { return p }
            p = parent(p)
        }
        return pid
    }

    /// 前台应用变了时用：通知里只有一个进程，没有现成的 regular 列表
    static func resolve(_ pid: pid_t) -> pid_t {
        resolve(pid) { NSRunningApplication(processIdentifier: $0)?.activationPolicy == .regular }
    }

    /// 查不到（进程已退出）时返回 0，resolve 的循环随之结束
    static func parentPID(_ pid: pid_t) -> pid_t {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        return proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size ? pid_t(info.pbi_ppid) : 0
    }
}

/// 最近使用顺序，最前面的是最近激活的
struct MRU {
    private(set) var order: [pid_t]

    init(order: [pid_t]) {
        self.order = order.reduce(into: []) { if !$0.contains($1) { $0.append($1) } }
    }

    mutating func activated(_ pid: pid_t) {
        order.removeAll { $0 == pid }
        order.insert(pid, at: 0)
    }

    mutating func terminated(_ pid: pid_t) {
        order.removeAll { $0 == pid }
    }

    /// 按 MRU 排序：已知的按 MRU 顺序在前，未知的保持传入顺序排在后面
    func sorted(_ pids: [pid_t]) -> [pid_t] {
        order.filter(pids.contains) + pids.filter { !order.contains($0) }
    }

    /// 启动时的初始顺序：前台应用 → 屏幕上窗口的前后层级 → 其余按启动时间从新到旧
    static func seededFromSystem() -> MRU {
        let onscreen = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        let zOrder = onscreen
            .filter { $0[kCGWindowLayer as String] as? Int == 0 }
            .compactMap { $0[kCGWindowOwnerPID as String] as? pid_t }
        let running = NSWorkspace.shared.runningApplications
        let byLaunch = running
            .sorted { ($0.launchDate ?? .distantPast) > ($1.launchDate ?? .distantPast) }
            .map(\.processIdentifier)
        let front = NSWorkspace.shared.frontmostApplication.map { [$0.processIdentifier] } ?? []
        let regular = Set(running.filter { $0.activationPolicy == .regular }.map(\.processIdentifier))
        return MRU(order: (front + zOrder).map { AppOwner.resolve($0, isApp: regular.contains) } + byLaunch)
    }
}
