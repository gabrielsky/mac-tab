import Foundation

/// 状态机处理一个输入之后，调用方要执行的动作
enum SwitcherEffect: Equatable {
    case stay            // 选中项或列表变了，会话继续
    case activate(pid_t) // 结束会话并激活
    case cancel          // 结束会话，不激活
    case hide(pid_t)     // 隐藏，会话继续
    case quit(pid_t)     // 已从列表移除；调用方负责 terminate，列表空了就结束会话
}

/// 切换会话的纯状态：MRU 排好序的 pid 列表 + 选中下标
struct Switcher {
    private(set) var apps: [pid_t]
    private(set) var selected: Int

    init?(apps: [pid_t], frontmost: pid_t?, reverse: Bool) {
        guard !apps.isEmpty else { return nil }
        self.apps = apps
        if reverse {
            selected = apps.count - 1
        } else if apps[0] == frontmost && apps.count > 1 {
            selected = 1
        } else {
            selected = 0
        }
    }

    var isEmpty: Bool { apps.isEmpty }

    mutating func handle(_ input: SwitcherInput) -> SwitcherEffect {
        guard !apps.isEmpty else { return .cancel }
        switch input {
        case .next:
            selected = (selected + 1) % apps.count
            return .stay
        case .previous:
            selected = (selected - 1 + apps.count) % apps.count
            return .stay
        case .confirm:
            return .activate(apps[selected])
        case .cancel:
            return .cancel
        case .hide:
            return .hide(apps[selected])
        case .quit:
            let pid = apps[selected]
            remove(pid)
            return .quit(pid)
        case .begin:
            return .stay
        }
    }

    mutating func select(_ index: Int) {
        if apps.indices.contains(index) { selected = index }
    }

    /// 移除应用，并尽量保持原来选中的那个应用不变
    @discardableResult
    mutating func remove(_ pid: pid_t) -> Bool {
        guard let index = apps.firstIndex(of: pid) else { return false }
        apps.remove(at: index)
        if index < selected { selected -= 1 }
        selected = min(selected, max(apps.count - 1, 0))
        return true
    }
}
