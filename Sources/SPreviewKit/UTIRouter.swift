import Foundation
import UniformTypeIdentifiers

// 文件类型判定：UTI 为主，扩展名兜底
public enum PreviewKind {
    case code          // 源代码与纯文本
    case markdown      // Markdown
    case notebook      // Jupyter .ipynb
    case archive       // 压缩包
    case image         // 图片（webp/avif 等）
    case model3D       // 三维模型
    case fallbackCode  // 未识别但可能是文本
    case info          // 无法识别的二进制：文件信息 + 十六进制预览

    public static func detect(url: URL) -> PreviewKind {
        let ext = url.pathExtension.lowercased()
        let specialNames = ["readme", "podfile", "gemfile", "license", "makefile", "rakefile",
                            "brewfile", "dockerfile", "procfile", "vagrantfile", "jenkinsfile",
                            "cargo", "go", "justfile", "cmakelists"]
        let name = url.lastPathComponent.lowercased()

        if ext == "ipynb" { return .notebook }
        if ext == "md" || ext == "markdown" || ext == "mdown" || ext == "mkd" { return .markdown }
        if name == "readme" || specialNames.contains(name.replacingOccurrences(of: ".", with: "").lowercased()) {
            return .code
        }

        let codeExts: Set<String> = [
            "py", "go", "js", "jsx", "ts", "tsx", "mjs", "cjs", "vue", "kt", "kts", "dart",
            "rs", "swift", "c", "h", "cpp", "hpp", "cc", "hh", "cxx", "m", "mm", "java",
            "rb", "php", "sh", "bash", "zsh", "fish", "yaml", "yml", "toml", "ini", "cfg",
            "conf", "lua", "sql", "r", "pl", "pm", "ps1", "psm1", "scss", "sass", "less",
            "css", "html", "htm", "xml", "json", "jsonc", "gradle", "cmake", "mk", "dockerfile",
            "proto", "graphql", "gql", "tf", "tfvars", "hcl", "vim", "el", "lisp", "clj",
            "ex", "exs", "erl", "hs", "ml", "fs", "fsi", "vb", "cs", "fsx", "asm", "s",
            "nasm", "bat", "cmd", "awk", "sed", "tcl", "zig", "nim", "cr", "v", "odin",
            "julia", "jl", "rmd", "sbt", "scala", "groovy", "liquid", "erb", "hbs", "ejs",
            "pug", "jade", "styl", "txt", "text", "log", "csv", "tsv", "properties", "gitignore",
            "gitattributes", "editorconfig", "npmrc", "babelrc", "eslintrc", "prettierrc",
            "env", "cnf", "list", "diff", "patch", "lock", "resx", "plist", "entitlements",
            "pbxproj", "xcconfig", "strings", "idl", "thrift", "proto3", "vue2"
        ]
        if codeExts.contains(ext) { return .code }

        let archiveExts: Set<String> = ["zip", "tar", "gz", "tgz", "bz2", "tbz", "xz", "txz",
                                        "7z", "rar", "zst", "tzst", "lz4", "cpio", "ar"]
        if archiveExts.contains(ext) { return .archive }

        let modelExts: Set<String> = ["glb", "gltf", "obj", "stl", "ply", "fbx", "dae", "usdz", "off"]
        if modelExts.contains(ext) { return .model3D }

        let imageExts: Set<String> = ["webp", "avif", "heic", "heif", "tiff", "tif", "bmp", "ico", "gif"]
        if imageExts.contains(ext) { return .image }

        // 按 UTI 判定
        if let t = UTType(filenameExtension: ext) {
            if t.conforms(to: .image) { return .image }
            if t.conforms(to: UTType("org.khronos.glb") ?? .data) || t.identifier.contains("3d") { return .model3D }
            if let arch = UTType("public.archive"), t.conforms(to: arch) { return .archive }
            if let src = UTType("public.source-code"), t.conforms(to: src) { return .code }
        }

        // 内容嗅探：可打印文本比例高则按代码处理，否则按信息 + 十六进制处理
        if let data = try? Data(contentsOf: url) {
            if data.isEmpty { return .code }
            let sample = data.prefix(4096)
            var printable = 0
            for byte in sample {
                if byte == 9 || byte == 10 || byte == 13 || (32...126).contains(byte) || byte >= 128 {
                    printable += 1
                }
            }
            if Double(printable) / Double(sample.count) > 0.9 { return .code }
            return .info
        }
        return .info
    }
}
