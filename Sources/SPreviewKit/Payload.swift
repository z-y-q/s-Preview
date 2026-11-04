import Foundation

// 预览数据载荷：Swift 侧组装，注入页面 SPreview.render(...)
public struct PreviewPayload: Codable {
    public var module: String          // code | markdown | notebook | archive | image | model
    public var fileName: String
    public var fileSize: Int64
    public var kind: String
    public var dark: Bool
    public var settings: SPreviewSettings
    public var test: Bool

    // code / markdown / notebook
    public var text: String?
    public var truncated: Bool?
    public var language: String?       // highlight.js 语言别名

    // notebook
    public var cells: [NotebookCell]?

    // archive
    public var archive: ArchiveInfoLite?

    // image
    public var imageWidth: Int?
    public var imageHeight: Int?
    public var imageFormat: String?
    public var imageDepth: Int?
    public var imageDPI: Double?
    public var imageAnimated: Bool?

    // model
    public var modelFormat: String?
}

public struct NotebookCell: Codable {
    public var type: String            // markdown | code | raw
    public var source: String
    public var language: String?
    public var outputs: [NotebookOutput]?
    public var executionCount: Int?
}

public struct NotebookOutput: Codable {
    public var kind: String            // text | html | image | error | stream
    public var content: String         // 文本 / html / base64 png / 错误信息
    public var mimeType: String?
}

// 压缩包清单数据
public struct ArchiveEntryLite: Codable {
    public var path: String
    public var size: Int64
    public var compressedSize: Int64
    public var isDirectory: Bool
    public var mtime: Double
    public var isEncrypted: Bool
}

public struct ArchiveInfoLite: Codable {
    public var format: String
    public var entryCount: Int
    public var totalSize: Int64
    public var totalCompressed: Int64
    public var fileCount: Int
    public var dirCount: Int
    public var entries: [ArchiveEntryLite]
    public var truncated: Bool
}
