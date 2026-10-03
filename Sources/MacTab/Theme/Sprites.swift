import CoreGraphics

/// 内置像素角色帧。人物由上半身（0–10 行）和腿（11–15 行）拼成，避免整帧重复
enum Sprites {
    static let palette: [Character: UInt32] = [
        "k": 0x2C2C2A, // 鞋、眼睛
        "s": 0xF5C4B3, // 皮肤
        "h": 0x633806, // 头发
        "b": 0x378ADD, // 上衣
        "p": 0x0C447C, // 裤子
        "o": 0xEF9F27, // 猫
        "d": 0xBA7517, // 猫的条纹
        "n": 0xED93B1, // 猫鼻子
    ]

    private static let upper = [
        "................",
        "......hhhh......",
        ".....hhhhhh.....",
        ".....hssssh.....",
        ".....skssks.....",
        ".....ssssss.....",
        "......ssss......",
        ".....bbbbbb.....",
        "....bbbbbbbb....",
        "....sbbbbbbs....",
        ".....bbbbbb.....",
    ]

    /// 眨眼：只有眼睛那一行不同
    private static var upperBlink: [String] {
        var rows = upper
        rows[4] = ".....ssssss....."
        return rows
    }

    /// 举起双手：手在头两侧向上
    private static let upperLift = [
        "....s......s....",
        "....s.hhhh.s....",
        "....bhhhhhhb....",
        "....bhsssshb....",
        "....bskssksb....",
        "....bssssssb....",
        ".....bssssb.....",
        ".....bbbbbb.....",
        ".....bbbbbb.....",
        ".....bbbbbb.....",
        ".....bbbbbb.....",
    ]

    private static let legsStand = [
        ".....pppppp.....",
        ".....pp..pp.....",
        ".....pp..pp.....",
        ".....pp..pp.....",
        "....kkk..kkk....",
    ]

    private static let legsWide = [
        ".....pppppp.....",
        "....pp....pp....",
        "...pp......pp...",
        "...pp......pp...",
        "..kkk......kkk..",
    ]

    private static let legsNarrow = [
        ".....pppppp.....",
        ".....pp..pp.....",
        "....pp....pp....",
        "....pp....pp....",
        "...kkk....kkk...",
    ]

    private static let catBody = [
        "................",
        "................",
        "................",
        "................",
        "....o.....o.....",
        "....oo...oo.....",
        "....ooooooo.....",
        "....okoooko.....",
        "....ooonooo.....",
        ".....ooooo......",
        "....ooooooo.....",
        "...oodooodoo....",
    ]

    private static let catTailDown = [
        "...ooooooooo....",
        "...ooooooooo..o.",
        "...ooooooooo.o..",
        "....oo...oo.o...",
    ]

    private static let catTailUp = [
        "...ooooooooo..o.",
        "...ooooooooo..o.",
        "...ooooooooo.o..",
        "....oo...oooo...",
    ]

    static let personIdle = upper + legsStand
    static let personBlink = upperBlink + legsStand
    static let personWalk = [upper + legsWide, upper + legsStand, upper + legsNarrow, upper + legsStand]
    static let personLift = upperLift + legsNarrow
    static let catSit = [catBody + catTailDown, catBody + catTailUp]

    /// 全部帧，供测试逐帧校验
    static var allFrames: [(name: String, rows: [String])] {
        [("personIdle", personIdle), ("personBlink", personBlink), ("personLift", personLift)]
            + personWalk.enumerated().map { ("personWalk\($0.offset)", $0.element) }
            + catSit.enumerated().map { ("catSit\($0.offset)", $0.element) }
    }

    // 生成好的图片：static let 首次访问时生成一次，之后复用
    static let idleImages = [personIdle, personBlink].map(image)
    static let walkImages = personWalk.map(image)
    static let liftImage = image(personLift)
    static let catImages = catSit.map(image)

    private static func image(_ rows: [String]) -> CGImage {
        PixelSprite(rows: rows, palette: palette).image
    }
}
