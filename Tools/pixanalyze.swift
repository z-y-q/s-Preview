import CoreGraphics
import ImageIO
import Foundation

let url = URL(fileURLWithPath: CommandLine.arguments[1])
let src = CGImageSourceCreateWithURL(url as CFURL, nil)!
let img = CGImageSourceCreateImageAtIndex(src, 0, nil)!
let w = img.width, h = img.height
var buf = [UInt8](repeating: 0, count: w * h * 4)
let ctx = CGContext(data: &buf, width: w, height: h, bitsPerComponent: 8,
                    bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
var white = 0, red = 0, green = 0, blue = 0, other = 0
var sumR = 0, sumG = 0, sumB = 0
var i = 0
while i < buf.count {
    let r = buf[i], g = buf[i + 1], b = buf[i + 2]
    sumR += Int(r); sumG += Int(g); sumB += Int(b)
    if r > 230 && g > 230 && b > 230 { white += 1 }
    else if r > 180 && g < 80 && b < 80 { red += 1 }
    else if g > 150 && r < 100 && b < 100 { green += 1 }
    else if b > 180 && r < 100 && g < 130 { blue += 1 }
    else { other += 1 }
    i += 4
}
let total = white + red + green + blue + other
let n = total
func pct(_ v: Int) -> String { String(format: "%.4f", Double(v) / Double(total)) }
print("WHITE=\(pct(white)) RED=\(pct(red)) GREEN=\(pct(green)) BLUE=\(pct(blue)) OTHER=\(pct(other)) size=\(w)x\(h) mean=(\(sumR/n),\(sumG/n),\(sumB/n))")
func sample(_ x: Int, _ y: Int) -> String {
    let idx = (y * w + x) * 4
    return "(\(buf[idx]),\(buf[idx+1]),\(buf[idx+2]))"
}
print("center=\(sample(w/2, h/2)) topleft=\(sample(20, 20)) topright=\(sample(w-20, 20)) botleft=\(sample(20, h-20)) botright=\(sample(w-20, h-20))")
