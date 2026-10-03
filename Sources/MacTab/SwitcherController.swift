import AppKit

/// 常驻整个进程的控制器：把 KeyTap、AppList、Switcher、SwitcherPanel、Activator 串起来
final class SwitcherController {
    private var mru = MRU.seededFromSystem()
    private var switcher: Switcher?
    private var apps: [pid_t: NSRunningApplication] = [:]
    private let panel = SwitcherPanel()
    private lazy var keyTap = KeyTap { [weak self] input in self?.handle(input) }
    private var showWork: DispatchWorkItem?
    private var commandPoll: Timer?
    private var panelShown = false
    private let themeStore = ThemeStore()

    init() {
        panel.onHover = { [weak self] index in
            self?.switcher?.select(index)
            self?.panel.select(index)
        }
        panel.onClick = { [weak self] index in
            self?.switcher?.select(index)
            self?.handle(.confirm)
        }
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.mru.activated(AppOwner.resolve(app.processIdentifier))
        }
        center.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.appTerminated(app.processIdentifier)
        }
    }

    var isRunning: Bool { keyTap.isRunning }

    /// 创建事件拦截；返回 false 通常表示没有辅助功能权限。可重复调用
    func start() -> Bool { keyTap.start() }

    /// 先结束进行中的会话，再拆掉事件拦截。可重复调用
    func stop() {
        end()
        keyTap.stop()
    }

    private func handle(_ input: SwitcherInput) {
        if case .begin(let reverse) = input {
            begin(reverse: reverse)
            return
        }
        guard let effect = switcher?.handle(input) else { return }
        switch effect {
        case .stay:
            if panelShown, let s = switcher { panel.select(s.selected) }
        case .activate(let pid):
            let app = apps[pid]
            end()
            // 立即记入 MRU：didActivateApplication 通知是异步的，快速连按时下一次 begin 可能跑在它前面
            mru.activated(pid)
            // 放到下一轮 runloop 只是让这次 tap 回调先返回；Activator 仍在主线程（也就是 tap 所在线程）上执行
            DispatchQueue.main.async { if let app { Activator.activate(app) } }
        case .cancel:
            end()
        case .hide(let pid):
            apps[pid]?.hide()
        case .quit(let pid):
            apps[pid]?.terminate()
            // 重新排版（读主题、装主题、重建图标）放到下一轮 runloop：不在 tap 回调里做重活，让回调先返回
            DispatchQueue.main.async { [weak self] in self?.listChanged() }
        }
    }

    private func begin(reverse: Bool) {
        let regular = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
        let regularPIDs = Set(regular.map(\.processIdentifier))
        let withWindows = Set(WindowRule.currentPidsWithWindows().map { AppOwner.resolve($0, isApp: regularPIDs.contains) })
        let candidates = regular.filter { withWindows.contains($0.processIdentifier) }
        apps = Dictionary(candidates.map { ($0.processIdentifier, $0) }, uniquingKeysWith: { first, _ in first })
        // 用 MRU 而不是 frontmostApplication：后者同样要等异步通知才更新，快速连按时会过时
        let frontmost = mru.order.first
        // 列表为空时不开会话；按键已经被 KeyTap 吞掉，所以不会弹出原生切换器
        guard let s = Switcher(apps: mru.sorted(candidates.map(\.processIdentifier)), frontmost: frontmost, reverse: reverse) else { return }
        switcher = s
        keyTap.sessionActive = true

        // 延迟 150ms 再显示面板：快速轻按时直接切换，面板不会闪一下
        let work = DispatchWorkItem { [weak self] in self?.showPanel() }
        showWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)

        // flagsChanged 丢失时兜底；加到 common mode，菜单栏菜单打开（eventTracking mode）时也照常运行
        let poll = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            if !CGEventSource.flagsState(.combinedSessionState).contains(.maskCommand) { self?.handle(.confirm) }
        }
        RunLoop.main.add(poll, forMode: .common)
        commandPoll = poll
    }

    private func showPanel() {
        guard let s = switcher else { return }
        // 每次弹出都新建主题实例：设置里刚换的主题下次弹出就生效
        panel.show(apps: s.apps.compactMap { apps[$0] }, selected: s.selected, theme: themeStore.current.make())
        panelShown = true
    }

    private func listChanged() {
        guard let s = switcher else { return }
        if s.isEmpty { end() } else if panelShown { showPanel() }
    }

    private func appTerminated(_ pid: pid_t) {
        mru.terminated(pid)
        if switcher?.remove(pid) == true { listChanged() }
    }

    private func end() {
        showWork?.cancel()
        showWork = nil
        commandPoll?.invalidate()
        commandPoll = nil
        switcher = nil
        keyTap.sessionActive = false
        panelShown = false
        panel.dismiss()
    }
}
