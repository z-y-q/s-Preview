import Foundation
@testable import SPreviewKit

// 压缩包清单命令行测试器：archlist <archive路径>
guard CommandLine.arguments.count >= 2 else {
    FileHandle.standardError.write(Data("用法: archlist <archive>\n".utf8)); exit(2)
}
let url = URL(fileURLWithPath: CommandLine.arguments[1])
do {
    let info = try ArchiveLister.list(url: url)
    let enc = JSONEncoder()
    enc.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try enc.encode(info)
    print(String(data: data, encoding: .utf8)!.prefix(1500))
    print("... total entries=\(info.entryCount) files=\(info.fileCount) dirs=\(info.dirCount) format=\(info.format) truncated=\(info.truncated)")
} catch {
    FileHandle.standardError.write(Data("FAIL: \(error)\n".utf8))
    exit(1)
}
