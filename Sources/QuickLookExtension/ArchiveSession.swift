import Foundation
import Clibarchive

// 压缩包会话：树形清单缓存 + 选择性解压（含 Zip-Slip 防护与进度回调）
final class ArchiveSession {
    let url: URL
    private let lock = NSLock()
    private var tsv: String = ""
    private var loaded = false
    private(set) var errorMessage: String?

    init(url: URL) {
        self.url = url
    }

    /// 后台线程调用：解析清单并缓存 TSV
    func loadTree() {
        lock.lock()
        if loaded {
            lock.unlock()
            return
        }
        loaded = true
        lock.unlock()

        do {
            let r = try ArchiveLister.listTree(url: url)
            lock.lock()
            tsv = r.tsv
            lock.unlock()
        } catch {
            lock.lock()
            errorMessage = error.localizedDescription
            lock.unlock()
        }
    }

    func currentTSV() -> String {
        lock.lock()
        defer { lock.unlock() }
        return tsv
    }

    func treeError() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return errorMessage
    }

    /// 条目路径规范化：拒绝绝对路径与 .. 上跳（Zip-Slip 防护）
    static func sanitizeEntryPath(_ name: String) -> String? {
        var cleaned = name
        while cleaned.hasPrefix("/") {
            cleaned = String(cleaned.dropFirst())
        }
        if cleaned.count >= 2, cleaned[cleaned.index(after: cleaned.startIndex)] == ":" {
            cleaned = String(cleaned.dropFirst(2))
            while cleaned.hasPrefix("/") || cleaned.hasPrefix("\\") {
                cleaned = String(cleaned.dropFirst())
            }
        }
        cleaned = cleaned.replacingOccurrences(of: "\\", with: "")
        let comps = cleaned.split(separator: "/").map(String.init)
        if comps.isEmpty || comps.contains("..") {
            return nil
        }
        return comps.joined(separator: "/")
    }

    /// 选择性解压：selected 含文件路径与文件夹路径（文件夹按前缀展开整个子树）
    /// 返回成功写盘的条目数
    static func extract(url: URL, selected: Set<String>, dest: URL,
                        progress: @escaping (Int, Int, String) -> Void) throws -> Int {
        try FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)

        let a = archive_read_new()
        defer { archive_read_free(a) }
        archive_read_support_format_all(a)
        archive_read_support_filter_all(a)
        let fd = open(url.path, O_RDONLY)
        guard fd >= 0 else {
            throw NSError(domain: "ArchiveExtract", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "无法打开压缩包"])
        }
        defer { close(fd) }
        guard archive_read_open_fd(a, fd, 64 * 1024) == ARCHIVE_OK else {
            throw NSError(domain: "ArchiveExtract", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: String(cString: archive_error_string(a))])
        }

        var extracted = 0
        var reported = 0
        let total = max(selected.count, 1)
        let fm = FileManager.default

        while true {
            var entry: OpaquePointer?
            let r = archive_read_next_header(a, &entry)
            if r == ARCHIVE_EOF { break }
            if r < ARCHIVE_WARN {
                let msg = archive_error_string(a).map { String(cString: $0) } ?? "读取失败"
                throw NSError(domain: "ArchiveExtract", code: 3,
                              userInfo: [NSLocalizedDescriptionKey: msg])
            }
            guard let e = entry else { break }
            let rawName = archive_entry_pathname(e).map { String(cString: $0) } ?? ""
            guard let name = sanitizeEntryPath(rawName) else {
                // Zip-Slip 条目：跳过不处理
                _ = archive_read_data_skip(a)
                continue
            }
            let isDir = archive_entry_filetype(e) == 0o40000

            // 命中规则：精确命中，或位于某个已选文件夹内
            var hit = selected.contains(name)
            if !hit {
                for s in selected {
                    if name.hasPrefix(s + "/") {
                        hit = true
                        break
                    }
                }
            }

            if hit {
                let destFile = dest.appendingPathComponent(name)
                let parent = destFile.deletingLastPathComponent()
                try fm.createDirectory(at: parent, withIntermediateDirectories: true)
                if isDir {
                    try fm.createDirectory(at: destFile, withIntermediateDirectories: true)
                } else {
                    fm.createFile(atPath: destFile.path, contents: Data())
                    guard let out = FileHandle(forWritingAtPath: destFile.path) else {
                        throw NSError(domain: "ArchiveExtract", code: 5,
                                      userInfo: [NSLocalizedDescriptionKey: "无法写入 \(destFile.lastPathComponent)"])
                    }
                    defer { try? out.close() }
                    var buffer = [UInt8](repeating: 0, count: 64 * 1024)
                    while true {
                        let n = archive_read_data(a, &buffer, buffer.count)
                        if n <= 0 { break }
                        _ = try out.write(contentsOf: Data(buffer[0..<n]))
                    }
                    let mtime = archive_entry_mtime(e)
                    if mtime > 0 {
                        let date = Date(timeIntervalSince1970: Double(mtime))
                        try? fm.setAttributes([.modificationDate: date], ofItemAtPath: destFile.path)
                    }
                    extracted += 1
                    if extracted - reported >= 20 || extracted == total {
                        reported = extracted
                        progress(extracted, total, name)
                    }
                }
            } else {
                _ = archive_read_data_skip(a)
            }
        }
        return extracted
    }
}
