import CoreGraphics
import ImageIO
import Foundation
import UniformTypeIdentifiers

// imgenc <输入png> <输出> <webp|avif>
let a = CommandLine.arguments
guard a.count >= 4 else { exit(2) }
let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: a[1]) as CFURL, nil)!
let img = CGImageSourceCreateImageAtIndex(src, 0, nil)!
let out = URL(fileURLWithPath: a[2])
let t = UTType(a[3])!
let dest = CGImageDestinationCreateWithURL(out as CFURL, t.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, img, nil)
let ok = CGImageDestinationFinalize(dest)
if !ok { FileHandle.standardError.write(Data("encode failed for \(a[3])\n".utf8)); exit(1) }
print("encoded \(a[3])")
