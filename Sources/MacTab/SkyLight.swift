import CoreGraphics

// 私有 SkyLight/CGS API。CoreGraphics 会重新导出这些符号。yabai、AltTab、Hammerspoon 都用了多年。

typealias CGSConnectionID = UInt32

@_silgen_name("CGSMainConnectionID")
func CGSMainConnectionID() -> CGSConnectionID

/// 返回窗口所属的 Space ID 列表；mask 0x7 表示当前、其他和用户 Space 全部包含
@_silgen_name("CGSCopySpacesForWindows")
func CGSCopySpacesForWindows(_ cid: CGSConnectionID, _ mask: Int32, _ windowIDs: CFArray) -> Unmanaged<CFArray>?
