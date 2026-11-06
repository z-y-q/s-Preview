import Foundation
import Clibarchive

// 压缩包清单：基于 libarchive 的统一读取（zip/tar/gz/7z/rar/bz2/xz）
public enum ArchiveLister {
    static let maxEntries = 5000
    public static let maxTreeEntries = 200_000
    // archive_entry.h 中的文件类型宏（Swift 不导入 C 宏，这里按八进制值定义）
    static let AE_IFDIR: UInt32 = 0o40000

    public static func list(url: URL) throws -> ArchiveInfoLite {
        try list(url: url, maxEntries: Self.maxEntries)
    }

    // 树形浏览用：更大的条目上限 + 紧凑 TSV（路径、大小、压缩后、修改时间、标志）
    public static func listTree(url: URL) throws -> (info: ArchiveInfoLite, tsv: String) {
        var full = try list(url: url, maxEntries: Self.maxTreeEntries)
        if full.entries.count >= Self.maxTreeEntries {
            full.truncated = true
        }
        var lines: [String] = []
        lines.reserveCapacity(full.entries.count)
        for e in full.entries {
            let flag = e.isDirectory ? "d" : (e.isEncrypted ? "de" : "-")
            lines.append("\(e.path)\t\(e.size)\t\(e.compressedSize)\t\(Int(e.mtime))\t\(flag)")
        }
        return (full, lines.joined(separator: "\n"))
    }

    public static func list(url: URL, maxEntries: Int) throws -> ArchiveInfoLite {
        let a = archive_read_new()
        defer { archive_read_free(a) }
        archive_read_support_format_all(a)
        archive_read_support_format_raw(a)
        archive_read_support_filter_all(a)

        let fd = open(url.path, O_RDONLY)
        guard fd >= 0 else {
            throw NSError(domain: "ArchiveLister", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "无法打开 \(url.lastPathComponent)"])
        }
        defer { close(fd) }
        let status = archive_read_open_fd(a, fd, 64 * 1024)
        guard status == ARCHIVE_OK else {
            throw NSError(domain: "ArchiveLister", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: String(cString: archive_error_string(a))])
        }

        var entries: [ArchiveEntryLite] = []
        var format = ""
        var totalSize: Int64 = 0
        var totalCompressed: Int64 = 0
        var fileCount = 0
        var dirCount = 0
        var truncated = false

        while true {
            var entry: OpaquePointer?
            let posBefore = archive_position_compressed(a)
            let r = archive_read_next_header(a, &entry)
            if r == ARCHIVE_EOF { break }
            if r < ARCHIVE_WARN {
                let msg = archive_error_string(a).map { String(cString: $0) } ?? "未知错误"
                if entries.isEmpty {
                    throw NSError(domain: "ArchiveLister", code: 3,
                                  userInfo: [NSLocalizedDescriptionKey: msg])
                }
                // 单个条目致命错误但已有部分数据时停止继续解析
                truncated = true
                break
            }
            if r == ARCHIVE_WARN {
                // 警告级错误（如条目级校验问题）继续，但记录
                _ = archive_error_string(a)
            }
            guard let e = entry else { break }
            if format.isEmpty {
                format = archive_format_name(a).map { String(cString: $0) } ?? "unknown"
            }
            let path = archive_entry_pathname(e).map { String(cString: $0) } ?? "?"
            let isDir = archive_entry_filetype(e) == AE_IFDIR
            var size = isDir ? Int64(0) : archive_entry_size(e)
            if size < 0 { size = 0 }
            if !isDir {
                let skip = archive_read_data_skip(a)
                if skip < ARCHIVE_WARN { truncated = true; break }
            }
            let compressed = archive_position_compressed(a) - posBefore
            let mtime = archive_entry_mtime(e)
            let enc = archive_entry_is_encrypted(e) != 0
            if isDir { dirCount += 1 } else { fileCount += 1 }
            totalSize += size
            totalCompressed += compressed
            if entries.count < maxEntries {
                entries.append(ArchiveEntryLite(path: path, size: size, compressedSize: compressed,
                                                isDirectory: isDir, mtime: Double(mtime), isEncrypted: enc))
            } else {
                truncated = true
            }
        }
        // raw 流（如单独的 .gz 文件）：用累计位置得到真实解压大小
        if format.contains("raw"), let first = entries.first {
            entries[0].size = archive_position_uncompressed(a)
            totalSize = archive_position_uncompressed(a)
            _ = first
        }
        return ArchiveInfoLite(format: format, entryCount: fileCount + dirCount,
                              totalSize: totalSize, totalCompressed: totalCompressed,
                              fileCount: fileCount, dirCount: dirCount,
                              entries: entries, truncated: truncated)
    }
}
