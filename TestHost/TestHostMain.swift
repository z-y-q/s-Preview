import AppKit
import QuickLookUI

// 测试宿主 v3：批量预览多个文件，单窗口切换，页面通过本机端口自报告渲染结果
// 用法: TestHost <file1> <file2> ... --per <秒>
let args = CommandLine.arguments
var inputs = Array(args.dropFirst())
var perFile = 6.0
if let idx = inputs.firstIndex(of: "--per"), idx + 1 < inputs.count {
    perFile = Double(inputs[idx + 1]) ?? 6.0
    inputs.removeSubrange(idx...idx + 1)
}
guard !inputs.isEmpty else {
    FileHandle.standardError.write(Data("用法: TestHost <file...> --per <秒>\n".utf8))
    exit(2)
}
let files = inputs.map { URL(fileURLWithPath: $0) }

final class BatchBox: NSView, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    let files: [URL]
    var index = 0
    init(files: [URL]) {
        self.files = files
        super.init(frame: .zero)
    }
    required init?(coder: NSCoder) { fatalError("unsupported") }
    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool { true }
    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.dataSource = self
        panel.delegate = self
    }
    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {}
    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int { files.count }
    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        self.index = min(max(index, 0), files.count - 1)
        return files[self.index] as NSURL
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)

let winFrame = NSRect(x: 24, y: 40, width: 520, height: 420)
let win = NSWindow(contentRect: winFrame,
                   styleMask: [.titled, .resizable], backing: .buffered, defer: false)
win.title = "s-Preview 批量测试"
win.level = .floating
win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
let box = BatchBox(files: files)
win.contentView = box
win.makeKeyAndOrderFront(nil)
app.activate(ignoringOtherApps: true)

var panel: QLPreviewPanel?
DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
    let p = QLPreviewPanel.shared()!
    p.dataSource = box
    p.delegate = box
    p.parent = win
    p.makeKeyAndOrderFront(nil)
    panel = p
    print("PANEL_OPEN")
    // 逐个切换文件
    var i = 0
    func advance() {
        if i >= box.files.count {
            print("BATCH_DONE")
            exit(0)
        }
        box.index = i
        if let p = panel {
            p.reloadData()
        }
        print("PREVIEW \(box.files[i].lastPathComponent)")
        i += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + perFile, execute: advance)
    }
    advance()
}

_ = app.run()
