import CoreGraphics
import XCTest
@testable import MacTab

final class PixelSpriteTests: XCTestCase {
    private let palette: [Character: UInt32] = ["k": 0x2C2C2A, "s": 0xF5C4B3]

    func testParsesRowsTopToBottomWithDotAsTransparent() {
        let sprite = PixelSprite(rows: ["k.", ".s"], palette: palette)
        XCTAssertEqual(sprite.width, 2)
        XCTAssertEqual(sprite.height, 2)
        XCTAssertEqual(sprite.pixels, [0x2C2C2A, nil, nil, 0xF5C4B3])
    }

    func testImageKeepsSizeAndColors() {
        let image = PixelSprite(rows: ["k.", ".s"], palette: palette).image
        XCTAssertEqual(image.width, 2)
        XCTAssertEqual(image.height, 2)

        // 画进 RGBA 位图再读回；位图内存第一行就是图片最上面一行。
        // 缓冲区指针只在 withUnsafeMutableBytes 闭包内有效，所以绘制必须在闭包里完成
        var bytes = [UInt8](repeating: 0, count: 2 * 2 * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: 2, height: 2, bitsPerComponent: 8, bytesPerRow: 8,
                                          space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: 2, height: 2))
            return true
        }
        XCTAssertTrue(drawn)
        XCTAssertEqual(Array(bytes[0..<4]), [0x2C, 0x2C, 0x2A, 0xFF]) // 左上：k
        XCTAssertEqual(bytes[7], 0)                                    // 右上：透明
        XCTAssertEqual(Array(bytes[12..<16]), [0xF5, 0xC4, 0xB3, 0xFF]) // 右下：s
    }

    func testAllBundledFramesAre16x16AndUseThePalette() {
        XCTAssertFalse(Sprites.allFrames.isEmpty)
        for (name, rows) in Sprites.allFrames {
            XCTAssertEqual(rows.count, 16, "\(name) 行数")
            for row in rows {
                XCTAssertEqual(row.count, 16, "\(name) 有一行不是 16 个字符：\(row)")
                for char in row where char != "." {
                    XCTAssertNotNil(Sprites.palette[char], "\(name) 用了调色板外的字符 \(char)")
                }
            }
        }
    }

    func testBundledImagesHaveExpectedFrameCounts() {
        XCTAssertEqual(Sprites.idleImages.count, 2)
        XCTAssertEqual(Sprites.walkImages.count, 4)
        XCTAssertEqual(Sprites.catImages.count, 2)
        XCTAssertEqual(Sprites.liftImage.width, 16)
    }
}
