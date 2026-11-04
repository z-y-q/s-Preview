import AppKit
import CoreText
import Foundation

// s-Preview 应用图标生成器：按 Apple Big Sur 图标网格绘制「预览之眼」母题
// 用法: make-icon <输出iconset目录>
let outDir = URL(fileURLWithPath: CommandLine.arguments[1])

let canvas: CGFloat = 1024
// 大苏尔网格：画布 1024，内容 824 居中（四周留 100），圆角约 22.5%
let inset: CGFloat = 100
let iconSize: CGFloat = canvas - inset * 2
let cornerRadius: CGFloat = 185

func makeContext(_ size: CGFloat) -> CGContext {
    let ctx = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8,
                        bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.scaleBy(x: size / canvas, y: size / canvas)
    return ctx
}

func drawIcon(in ctx: CGContext) {
    // 背景圆角矩形 + 对角渐变
    let rect = CGRect(x: inset, y: inset, width: iconSize, height: iconSize)
    let squircle = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    ctx.addPath(squircle)
    ctx.clip()

    let colors = [CGColor(red: 0.36, green: 0.33, blue: 0.96, alpha: 1),
                  CGColor(red: 0.05, green: 0.42, blue: 1.0, alpha: 1)] as CFArray
    let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
    ctx.drawLinearGradient(grad, start: CGPoint(x: inset, y: canvas - inset),
                           end: CGPoint(x: canvas - inset, y: inset), options: [])

    // 顶部高光
    ctx.saveGState()
    ctx.addPath(squircle)
    ctx.clip()
    let glass = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                           colors: [CGColor(red: 1, green: 1, blue: 1, alpha: 0.22),
                                    CGColor(red: 1, green: 1, blue: 1, alpha: 0.0)] as CFArray,
                           locations: [0, 1])!
    ctx.drawLinearGradient(glass, start: CGPoint(x: 0, y: canvas), end: CGPoint(x: 0, y: canvas * 0.45), options: [])
    ctx.restoreGState()

    // ---------- 眼睛主体 ----------
    let cx: CGFloat = canvas / 2
    let cy: CGFloat = canvas / 2 + 10
    let eyeW: CGFloat = 330      // 眼角到中心水平距离
    let eyeH: CGFloat = 208      // 上下弧高
    let stroke: CGFloat = 46

    let left = CGPoint(x: cx - eyeW, y: cy)
    let right = CGPoint(x: cx + eyeW, y: cy)
    let eye = CGMutablePath()
    eye.move(to: left)
    eye.addQuadCurve(to: right, control: CGPoint(x: cx, y: cy - eyeH))
    eye.addQuadCurve(to: left, control: CGPoint(x: cx, y: cy + eyeH))
    eye.closeSubpath()

    // 外描边（白色，带轻微投影）
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 40,
                  color: CGColor(red: 0, green: 0.1, blue: 0.35, alpha: 0.35))
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    ctx.setLineWidth(stroke)
    ctx.setLineCap(.round)
    ctx.addPath(eye)
    ctx.strokePath()
    ctx.restoreGState()

    // 眼内暗色填充（比背景更深，突出瞳孔）
    ctx.saveGState()
    ctx.addPath(eye)
    ctx.clip()
    let inner = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                           colors: [CGColor(red: 0.07, green: 0.13, blue: 0.42, alpha: 1),
                                    CGColor(red: 0.03, green: 0.06, blue: 0.24, alpha: 1)] as CFArray,
                           locations: [0, 1])!
    ctx.drawLinearGradient(inner, start: CGPoint(x: 0, y: canvas), end: CGPoint(x: 0, y: 0), options: [])
    ctx.restoreGState()

    // 瞳孔：白色圆 + 渐变内圆
    let pupilR: CGFloat = 128
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    ctx.fillEllipse(in: CGRect(x: cx - pupilR, y: cy - pupilR, width: pupilR * 2, height: pupilR * 2))
    let pupilGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                               colors: [CGColor(red: 0.10, green: 0.30, blue: 0.95, alpha: 1),
                                        CGColor(red: 0.30, green: 0.26, blue: 0.90, alpha: 1)] as CFArray,
                               locations: [0, 1])!
    let innerR: CGFloat = 100
    ctx.saveGState()
    ctx.addEllipse(in: CGRect(x: cx - innerR, y: cy - innerR, width: innerR * 2, height: innerR * 2))
    ctx.clip()
    ctx.drawLinearGradient(pupilGrad, start: CGPoint(x: 0, y: cy + innerR), end: CGPoint(x: 0, y: cy - innerR), options: [])
    ctx.restoreGState()

    // 瞳孔内 </> 符号
    let attr = NSAttributedString(string: "</>", attributes: [
        .font: CTFontCreateWithName("Menlo-Bold" as CFString, 118, nil),
        .foregroundColor: CGColor(red: 1, green: 1, blue: 1, alpha: 1),
    ])
    let line = CTLineCreateWithAttributedString(attr)
    let width = CTLineGetTypographicBounds(line, nil, nil, nil)
    let font = attr.attribute(.font, at: 0, effectiveRange: nil) as! CTFont
    let ascent = CTFontGetAscent(font)
    let descent = CTFontGetDescent(font)
    ctx.textPosition = CGPoint(x: cx - width / 2, y: cy - (ascent - descent) / 2)
    CTLineDraw(line, ctx)

    // 高光弧：左上角小弧线点缀
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.9))
    ctx.setLineWidth(30)
    ctx.setLineCap(.round)
    ctx.addArc(center: CGPoint(x: cx - 150, y: cy - 150), radius: 120,
               startAngle: .pi * 1.05, endAngle: .pi * 1.45, clockwise: false)
    ctx.strokePath()
}

// 圆角裁剪到 squircle（大尺寸图标含透明边距）
func render(size: CGFloat, cornerCrop: Bool) -> Data {
    let ctx = makeContext(size)
    if cornerCrop {
        // 16pt 级小图标：铺满画布（系统自动加圆角遮罩时更清晰），此处仍保留轻微透明边
        drawIcon(in: ctx)
    } else {
        drawIcon(in: ctx)
    }
    let img = ctx.makeImage()!
    let rep = NSBitmapImageRep(cgImage: img)
    return rep.representation(using: .png, properties: [:])!
}

try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
let specs: [(String, CGFloat)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]
for (name, px) in specs {
    try render(size: px, cornerCrop: px <= 64).write(to: outDir.appendingPathComponent(name))
    print("rendered \(name)")
}
print("iconset done")
