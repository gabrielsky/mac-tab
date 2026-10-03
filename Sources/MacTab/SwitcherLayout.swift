import CoreGraphics

/// 面板内容的几何：图标格子、名称标签和整体尺寸。纯计算，面板和设置预览共用。
/// 比例以图标边长为 1，量自 macOS 26 原生切换器（图标含系统图标自带的约 10% 透明外圈）
struct SwitcherLayout: Equatable {
    static let maxIcon: CGFloat = 128
    /// 格子比图标四周各大这么多；相邻格子紧挨，所以图标间空隙是它的 2 倍
    static let insetRatio: CGFloat = 0.045
    /// 面板边缘到图标
    static let marginRatio: CGFloat = 0.35
    static let cornerRatio: CGFloat = 0.38
    /// 名称字号固定，不随图标缩小：应用多时图标很小，按比例缩的字看不清
    static let fontSize: CGFloat = 16
    /// 名称标签底边离面板底边
    static let labelRatio: CGFloat = 0.1
    /// 名称和格子之间的空隙：边框类主题画满格子，名称不能被压住
    static let labelGap: CGFloat = 4

    let icon: CGFloat
    let cellInset: CGFloat
    let size: CGSize
    let cellFrames: [CGRect]
    /// 名称区顶边：名称从这里往下排，中文回退字体行高更高也只会往下长，不会顶到格子
    private let labelTop: CGFloat

    var cornerRadius: CGFloat { icon * Self.cornerRatio }

    /// 应用少时图标用最大尺寸，多时缩小，保证总宽不超过 availableWidth 的 90%。
    /// extraTop / extraBottom 是主题要求在图标行上方、下方额外留出的高度
    init(count: Int, availableWidth: CGFloat, extraTop: CGFloat, extraBottom: CGFloat) {
        let n = CGFloat(max(count, 1))
        // 总宽 = 图标 × (n 个格子 - 首尾格子多出的内缩 + 两侧边距)
        let widthInIcons = n * (1 + 2 * Self.insetRatio) - 2 * Self.insetRatio + 2 * Self.marginRatio
        icon = min(Self.maxIcon, floor(availableWidth * 0.9 / widthInIcons))
        let inset = icon * Self.insetRatio
        cellInset = inset
        let margin = icon * Self.marginRatio
        let cell = icon + 2 * inset
        // 名称区在最下面，角色的额外空间在名称区和格子之间；行高按字号 × 1.25 预留
        labelTop = icon * Self.labelRatio + Self.fontSize * 1.25
        let rowY = labelTop + Self.labelGap + extraBottom
        cellFrames = (0..<count).map {
            CGRect(x: margin - inset + CGFloat($0) * cell, y: rowY, width: cell, height: cell)
        }
        size = CGSize(width: icon * widthInIcons, height: rowY + cell + extraTop + margin - inset)
    }

    /// 名称标签：在选中图标正下方居中，不超出面板（两侧至少留半个边距）
    func labelFrame(under index: Int, textSize: CGSize) -> CGRect {
        let inset = icon * Self.marginRatio / 2
        let width = min(textSize.width, size.width - 2 * inset)
        let midX = cellFrames.indices.contains(index) ? cellFrames[index].midX : size.width / 2
        let x = min(max(midX - width / 2, inset), size.width - inset - width)
        return CGRect(x: x, y: labelTop - textSize.height, width: width, height: textSize.height)
    }
}
