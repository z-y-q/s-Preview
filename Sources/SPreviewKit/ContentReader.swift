import Foundation
import ImageIO
import UniformTypeIdentifiers

// 内容读取：编码猜测、大小上限、图片元数据
public enum ContentReader {
    public static func readText(url: URL, limit: Int) throws -> (text: String, truncated: Bool) {
        let data = try Data(contentsOf: url)
        if data.isEmpty { return ("", false) }
        if data.count <= limit {
            return (decode(data), false)
        }
        return (decode(data.prefix(limit)), true)
    }

    static func decode(_ data: Data) -> String {
        if data.starts(with: [0xEF, 0xBB, 0xBF]) {
            let s = String(data: data.dropFirst(3), encoding: .utf8)
            if let s = s { return s }
        }
        if data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF]) {
            let s = String(data: data, encoding: .utf16)
            if let s = s { return s }
        }
        if let s = String(data: data, encoding: .utf8), !s.contains("\u{FFFD}") {
            return s
        }
        if let s = String(data: data, encoding: .isoLatin1) {
            return s
        }
        return String(data: data, encoding: .nonLossyASCII) ?? ""
    }

    public static func imageInfo(url: URL) -> (width: Int, height: Int, format: String, depth: Int, dpi: Double, animated: Bool)? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        guard let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any] else { return nil }
        let width = props[kCGImagePropertyPixelWidth] as? Int ?? 0
        let height = props[kCGImagePropertyPixelHeight] as? Int ?? 0
        if width == 0 || height == 0 { return nil }
        var depth = props[kCGImagePropertyDepth] as? Int ?? 0
        if depth == 0 {
            if let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) { depth = cg.bitsPerPixel }
        }
        let dpiX = props[kCGImagePropertyDPIWidth] as? Double ?? 0
        let dpiY = props[kCGImagePropertyDPIHeight] as? Double ?? 0
        let dpi = dpiX > 0 ? dpiX : dpiY
        let count = CGImageSourceGetCount(src)
        let uti = CGImageSourceGetType(src) as String?
        var animated = false
        if count > 1, let uti = uti, UTType(uti)?.conforms(to: .gif) == true { animated = true }
        let formatName: String
        if let uti = uti, let t = UTType(uti) {
            formatName = t.preferredFilenameExtension ?? uti
        } else {
            formatName = url.pathExtension.lowercased()
        }
        return (width, height, formatName, depth, dpi, animated)
    }

    // 经典十六进制排版：偏移 + 十六进制字节 + ASCII 列
    public static func hexdump(url: URL, bytes: Int = 2048) throws -> (dump: String, truncated: Bool) {
        let data = try Data(contentsOf: url)
        let slice = data.prefix(bytes)
        var lines: [String] = []
        var offset = 0
        while offset < slice.count {
            let chunk = slice.subdata(in: offset..<(offset + min(16, slice.count - offset)))
            var hex: [String] = []
            var ascii = ""
            for byte in chunk {
                hex.append(String(format: "%02X", byte))
                ascii += (32...126).contains(byte) ? String(UnicodeScalar(byte)) : "·"
            }
            while hex.count < 16 {
                hex.append("  ")
            }
            lines.append(String(format: "%08X  ", offset) + hex.joined(separator: " ") + "  |" + ascii + "|")
            offset += 16
        }
        return (lines.joined(separator: "\n"), data.count > bytes)
    }
}
