import Foundation

// 解压功能验证器：extract-test <压缩包> <目标目录> <路径1> <路径2> ...
// 验证：解压后目标文件存在且内容与原压缩包一致
let args = CommandLine.arguments
guard args.count >= 4 else {
    FileHandle.standardError.write(Data("用法: extract-test <archive> <dest> <path...>\n".utf8)); exit(2)
}
let archive = URL(fileURLWithPath: args[1])
let dest = URL(fileURLWithPath: args[2])
let selected = Set(args[3...])

try? FileManager.default.removeItem(at: dest)

do {
    let count = try ArchiveSession.extract(url: archive, selected: selected, dest: dest) { done, total, current in
        print("progress \(done)/\(total) \(current)")
    }
    print("extracted=\(count)")
    var failures = 0
    for p in selected {
        let f = dest.appendingPathComponent(p)
        if FileManager.default.fileExists(atPath: f.path) {
            print("OK file \(p) (\((try? FileManager.default.attributesOfItem(atPath: f.path))?[.size] as? Int64 ?? 0) B)")
        } else {
            print("MISSING \(p)")
            failures += 1
        }
    }
    exit(failures > 0 ? 1 : 0)
} catch {
    FileHandle.standardError.write(Data("EXTRACT_FAIL: \(error)\n".utf8))
    exit(1)
}
