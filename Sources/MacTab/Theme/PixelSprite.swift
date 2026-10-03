import CoreGraphics
import Foundation

/// 像素精灵：一帧是等长字符串数组，一个字符一个像素，'.' 表示透明；颜色是 0xRRGGBB
struct PixelSprite: Equatable {
    let width: Int
    let height: Int
    /// 行优先，从上到下；nil 为透明
    let pixels: [UInt32?]

    init(rows: [String], palette: [Character: UInt32]) {
        // 用局部常量校验：闭包里不能在 self 全部初始化前读 self.width
        let rowWidth = rows.first?.count ?? 0
        precondition(rows.allSatisfy { $0.count == rowWidth }, "像素帧每行长度必须一致")
        width = rowWidth
        height = rows.count
        pixels = rows.flatMap { row in
            row.map { char -> UInt32? in
                if char == "." { return nil }
                guard let color = palette[char] else { preconditionFailure("调色板里没有字符 \(char)") }
                return color
            }
        }
    }

    /// 生成 sRGB 的 CGImage；透明像素 alpha 为 0。显示时由图层做最近邻放大
    var image: CGImage {
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        for (index, pixel) in pixels.enumerated() {
            guard let pixel else { continue }
            bytes[index * 4] = UInt8((pixel >> 16) & 0xFF)
            bytes[index * 4 + 1] = UInt8((pixel >> 8) & 0xFF)
            bytes[index * 4 + 2] = UInt8(pixel & 0xFF)
            bytes[index * 4 + 3] = 0xFF
        }
        let provider = CGDataProvider(data: Data(bytes) as CFData)!
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                       space: CGColorSpace(name: CGColorSpace.sRGB)!,
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
    }
}
