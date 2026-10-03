import Foundation

/// 当前主题的持久化；读到未知或损坏的值时回退到经典
struct ThemeStore {
    static let key = "selectionTheme"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var current: ThemeID {
        get { defaults.string(forKey: Self.key).flatMap(ThemeID.init(rawValue:)) ?? .classic }
        nonmutating set { defaults.set(newValue.rawValue, forKey: Self.key) }
    }
}
