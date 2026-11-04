import CoreGraphics
import ImageIO
import Foundation

// 图标像素自检：不透明覆盖率、白色占比、蓝色占比（程序化验证，不做人工看图）
let url = URL(fileURLWithPath: CommandLine.arguments[1])
let src = CGImageSourceCreateWithURL(url as CFURL, nil)!
let img = CGImageSourceCreateImageAtIndex(src, 0, nil)!
let w = img.width, h = img.height
var buf = [UInt8](repeating: 0, count: w * h * 4)
let ctx = CGContext(data: &buf, width: w, height: h, bitsPerComponent: 8,
                    bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
var opaque = 0, white = 0, blueish = 0
var i = 0
while i < buf.count {
    let a = buf[i + 3], r = buf[i], g = buf[i + 1], b = buf[i + 2]
    if a > 200 {
        opaque += 1
        if r > 220 && g > 220 && b > 220 { white += 1 }
        else if b > 140 && b > r + 30 { blueish += 1 }
    }
    i += 4
}
let total = w * h
let opq = max(opaque, 1)
func pct(_ v: Int, _ base: Int) -> String { String(format: "%.4f", Double(v) / Double(base)) }
print("OPAQUE=\(pct(opaque, total)) WHITE=\(pct(white, opq)) BLUE=\(pct(blueish, opq)) size=\(w)x\(h)")
