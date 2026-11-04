import AppKit
import QuickLookUI

// QLPreviewView 单文件测试
let args = CommandLine.arguments
guard args.count >= 2 else { exit(2) }
let file = URL(fileURLWithPath: args[1])
let seconds = Double(args.count > 2 ? args[2] : "10") ?? 10

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let win = NSWindow(contentRect: NSRect(x: 24, y: 40, width: 520, height: 400),
                   styleMask: [.titled, .resizable], backing: .buffered, defer: false)
win.title = "QLViewTest"
win.level = .floating
let ql = QLPreviewView(frame: NSRect(x: 0, y: 0, width: 520, height: 400))!
ql.previewItem = file as NSURL
ql.refreshPreviewItem()
win.contentView = ql
win.makeKeyAndOrderFront(nil)
app.activate(ignoringOtherApps: true)
DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { exit(0) }
app.run()
