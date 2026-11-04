import Foundation

// 设置项：设置应用写入 JSON 文件，扩展每次预览读取
// 路径说明：扩展是沙箱进程，读写 `~/Library/Application Support/s-Preview/` 会被
// 系统透明映射进自身容器；未沙箱的设置应用写同一路径的字面位置。为保证两边共享
// 同一份数据，保存时同时写入字面路径与沙箱映射落点。
public struct SPreviewSettings: Codable {
    public var theme: String          // auto | light | dark
    public var codeTheme: String      // highlight.js 主题名
    public var fontSize: Int
    public var tabWidth: Int
    public var wordWrap: Bool
    public var lineNumbers: Bool
    public var markdownMath: Bool
    public var imageInfoOverlay: Bool
    public var archiveShowCompressed: Bool
    public var archiveShowDate: Bool
    public var archiveShowPermissions: Bool
    public var modelGrid: Bool
    public var modelAxes: Bool
    public var modelWireframe: Bool
    public var modelBBox: Bool
    public var modelSkeleton: Bool
    public var modelAutoRotate: Bool
    public var modelBackground: String  // auto | light | dark
    public var testMode: Bool
    public var textSizeLimit: Int       // 代码文本读取上限（字节）
    // 预览类别开关：关闭后扩展拒绝该类别，系统回退到原生预览
    public var catCode: Bool
    public var catDocs: Bool
    public var catArchive: Bool
    public var catImage: Bool
    public var catModel: Bool
    public var catData: Bool

    public static let standard = SPreviewSettings(
        theme: "auto", codeTheme: "github", fontSize: 13, tabWidth: 4,
        wordWrap: false, lineNumbers: true, markdownMath: true,
        imageInfoOverlay: true,
        archiveShowCompressed: true, archiveShowDate: true, archiveShowPermissions: false,
        modelGrid: true, modelAxes: true, modelWireframe: false, modelBBox: false,
        modelSkeleton: false, modelAutoRotate: false, modelBackground: "auto",
        testMode: false, textSizeLimit: 5_000_000,
        catCode: true, catDocs: true, catArchive: true, catImage: true,
        catModel: true, catData: true
    )

    // 逻辑路径（未沙箱进程的字面位置；沙箱进程读写时被映射进容器）
    public static var primarySettingsURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/s-Preview/settings.json")
    }

    // 沙箱映射落点（扩展进程读逻辑路径时实际命中的位置）
    public static var sandboxSettingsURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers/com.spreview.s-preview.QuickLook/Data/Library/Application Support/s-Preview/settings.json")
    }

    // 旧版容器路径（1.0 写入位置，保留兼容读取）
    public static var legacySettingsURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers/com.spreview.s-preview.QuickLook/Data/Library/Application Support/settings.json")
    }

    public static func load() -> SPreviewSettings {
        for path in [primarySettingsURL, sandboxSettingsURL, legacySettingsURL] {
            if let data = try? Data(contentsOf: path),
               let s = try? JSONDecoder().decode(SPreviewSettings.self, from: data) {
                return s
            }
        }
        return .standard
    }

    public static func save(_ s: SPreviewSettings) throws {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try enc.encode(s)
        for path in [primarySettingsURL, sandboxSettingsURL] {
            try FileManager.default.createDirectory(at: path.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try data.write(to: path, options: .atomic)
        }
    }

    // 预览类别 → 设置键名（供扩展路由与设置界面共用）
    public func categoryEnabled(_ kind: String) -> Bool {
        switch kind {
        case "code", "fallbackCode": return catCode
        case "markdown", "notebook": return catDocs
        case "archive": return catArchive
        case "image": return catImage
        case "model": return catModel
        case "info": return catData
        default: return true
        }
    }
}
