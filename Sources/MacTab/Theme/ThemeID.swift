import Foundation

/// 内置主题注册表；rawValue 会存进 UserDefaults，定下后不能改名
enum ThemeID: String, CaseIterable {
    case classic, accent, ornate, neon, rainbow, marchingAnts, porter, lifter, cat

    /// 名称和说明都是英文原文，中文见 Resources/zh-Hans.lproj
    var title: String {
        switch self {
        case .classic: String(localized: "Classic")
        case .accent: String(localized: "Accent")
        case .ornate: String(localized: "Ornate")
        case .neon: String(localized: "Neon")
        case .rainbow: String(localized: "Rainbow")
        case .marchingAnts: String(localized: "Marching Ants")
        case .porter: String(localized: "Porter")
        case .lifter: String(localized: "Lifter")
        case .cat: String(localized: "Hopping Cat")
        }
    }

    var subtitle: String {
        switch self {
        case .classic: String(localized: "Outline hugging the icon, like the system switcher")
        case .accent: String(localized: "Solid system accent color")
        case .ornate: String(localized: "Gold double border with a dotted outline")
        case .neon: String(localized: "Pink neon outline that glows and flickers")
        case .rainbow: String(localized: "Rainbow gradient flowing around the border")
        case .marchingAnts: String(localized: "Dashes marching around the border")
        case .porter: String(localized: "A pixel person drags the frame over")
        case .lifter: String(localized: "A pixel person lifts the selected icon")
        case .cat: String(localized: "A pixel cat hops from icon to icon")
        }
    }

    func make() -> SelectionTheme {
        switch self {
        case .classic: FrameTheme.classic()
        case .accent: FrameTheme.accent()
        case .ornate: FrameTheme.ornate()
        case .neon: FrameTheme.neon()
        case .rainbow: FrameTheme.rainbow()
        case .marchingAnts: FrameTheme.marchingAnts()
        case .porter: PorterTheme()
        case .lifter: LifterTheme()
        case .cat: CatTheme()
        }
    }
}
