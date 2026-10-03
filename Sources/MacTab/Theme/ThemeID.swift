/// 内置主题注册表；rawValue 会存进 UserDefaults，定下后不能改名
enum ThemeID: String, CaseIterable {
    case classic, accent, ornate, neon, rainbow, marchingAnts, porter, lifter, cat

    var title: String {
        switch self {
        case .classic: "经典"
        case .accent: "强调色"
        case .ornate: "花框"
        case .neon: "霓虹"
        case .rainbow: "彩虹流光"
        case .marchingAnts: "跑马灯"
        case .porter: "搬运小人"
        case .lifter: "举重小人"
        case .cat: "跳跳猫"
        }
    }

    var subtitle: String {
        switch self {
        case .classic: "白色半透明底"
        case .accent: "系统强调色实色底"
        case .ornate: "金色双线加点线外框"
        case .neon: "粉色霓虹描边，呼吸闪烁"
        case .rainbow: "彩虹渐变边框持续流动"
        case .marchingAnts: "虚线沿边框行进"
        case .porter: "像素小人拖着选中框跑过去"
        case .lifter: "小人把选中图标举高放大"
        case .cat: "像素猫蹲在图标上，切换时跳过去"
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
