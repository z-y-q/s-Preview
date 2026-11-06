import Cocoa
import WebKit
import Foundation
import UniformTypeIdentifiers

// 离屏预览验证器：直接驱动真实扩展页面与同一套载荷构建代码，无窗口无弹窗
// 用法: previewharness <文件> <超时秒> [截图输出.png]
// 输出: JSON 报告到 stdout；可选将渲染结果保存为 PNG
let args = CommandLine.arguments
guard args.count >= 2 else {
    FileHandle.standardError.write(Data("用法: previewharness <文件> <超时秒> [截图输出.png]\n".utf8)); exit(2)
}
let file = URL(fileURLWithPath: args[1])
let timeout = Double(args.count > 2 ? args[2] : "15") ?? 15
let snapshotPath: String? = args.count > 3 ? args[3] : nil

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)

let settings = SPreviewSettings.load()
var harnessSettings = settings
harnessSettings.testMode = true

let payload: PreviewPayload
do {
    // 与 PreviewController.buildPayload 相同的组装逻辑
    var fileSize: Int64 = 0
    if let attrs = try? FileManager.default.attributesOfItem(atPath: file.path),
       let s = attrs[.size] as? Int64 { fileSize = s }
    let kind = PreviewKind.detect(url: file)
    var p = PreviewPayload(
        module: "code", fileName: file.lastPathComponent, fileSize: fileSize,
        kind: (UTType(filenameExtension: file.pathExtension)?.identifier) ?? "public.data",
        dark: ProcessInfo.processInfo.environment["SP_LIGHT"] != "1", settings: harnessSettings, test: true,
        text: nil, truncated: nil, language: nil, cells: nil, archive: nil,
        imageWidth: nil, imageHeight: nil, imageFormat: nil, imageDepth: nil,
        imageDPI: nil, imageAnimated: nil, modelFormat: nil)
    switch kind {
    case .markdown:
        p.module = "markdown"
        let (text, tr) = try ContentReader.readText(url: file, limit: harnessSettings.textSizeLimit)
        p.text = text; p.truncated = tr; p.language = "markdown"
    case .notebook:
        p.module = "notebook"
        p.cells = try NotebookParser.parse(url: file, textLimit: harnessSettings.textSizeLimit)
    case .archive:
        p.module = "archive"
        p.archive = try ArchiveLister.list(url: file)
    case .image:
        p.module = "image"
        if let info = ContentReader.imageInfo(url: file) {
            p.imageWidth = info.width; p.imageHeight = info.height
            p.imageFormat = info.format; p.imageDepth = info.depth
            p.imageDPI = info.dpi; p.imageAnimated = info.animated
        }
    case .model3D:
        p.module = "model"
        p.modelFormat = file.pathExtension.lowercased()
    case .info:
        p.module = "info"
        let (dump, tr) = try ContentReader.hexdump(url: file, bytes: 4096)
        p.text = dump
        p.truncated = tr
        p.language = "hexdump"
    case .code, .fallbackCode:
        p.module = "code"
        let (text, tr) = try ContentReader.readText(url: file, limit: harnessSettings.textSizeLimit)
        p.text = text; p.truncated = tr
        p.language = HLJSAliases.alias(ext: file.pathExtension.lowercased(), name: file.lastPathComponent.lowercased())
    }
    payload = p
} catch {
    let enc = JSONEncoder()
    let data = try! enc.encode(["FAIL": "payload: \(error.localizedDescription)"])
    print(String(data: data, encoding: .utf8)!)
    exit(1)
}

let appexResources = URL(fileURLWithPath: "/Applications/s-Preview.app/Contents/PlugIns/s-Preview.QuickLook.appex/Contents/Resources")
let htmlURL = appexResources.appendingPathComponent("Viewer/spreview.html")
guard FileManager.default.fileExists(atPath: htmlURL.path) else {
    print("{\"FAIL\": \"appex resources missing\"}")
    exit(1)
}

var archiveSession: ArchiveSession? = nil
if payload.module == "archive" {
    let s = ArchiveSession(url: file)
    s.loadTree()
    archiveSession = s
}
let cfg = WKWebViewConfiguration()
cfg.setURLSchemeHandler(ResourceSchemeHandler(fileURL: file, archiveSession: archiveSession), forURLScheme: ResourceSchemeHandler.scheme)
let web = WKWebView(frame: NSRect(x: 0, y: 0, width: 1200, height: 800), configuration: cfg)

let payloadJSON = String(data: try! JSONEncoder().encode(payload), encoding: .utf8)!

func dumpAndExit(_ code: Int32) {
    web.evaluateJavaScript("JSON.stringify({reports: window.__SP_REPORTS__ || {}, sprev: typeof SPreview, bodyLen: document.body ? document.body.innerHTML.length : -1, loaded: !!window.__SP_PAGE_READY__, err: window.__SP_ERR__ || null})") { result, error in
        if let s = result as? String {
            print(s)
        } else {
            print("{\"FAIL\": \"dump: \(error?.localizedDescription ?? "none")\"}")
        }
        exit(code)
    }
}

// 用闭包代理
final class NavDummy: NSObject, WKNavigationDelegate {
    var onDone: (() -> Void)?
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        onDone?()
    }
}
let nav = NavDummy()
web.navigationDelegate = nav
nav.onDone = {
    web.evaluateJavaScript("JSON.stringify([typeof SPreview, typeof hljs, typeof marked, typeof katex, typeof SPreview3D, window.__SP_ERR__, document.scripts.length, Array.from(document.scripts).map(function(s){return s.src.split('/').pop() + ':' + (s.src === '' ? 'inline-ok' : 'loaded')})])") { result, err in
        FileHandle.standardError.write(Data("page_state=\(result ?? "\"eval-fail\"")\n".utf8))
    }
    let wrapped = "(function(){ try { SPreview.render(\(payloadJSON)); return 'ok'; } catch (e) { window.__SP_ERR__ = ((e && e.message) || String(e)) + ' | ' + ((e && e.stack) || ''); return 'throw'; } })()"
    web.evaluateJavaScript(wrapped) { result, err in
        let r = (result as? String) ?? (err != nil ? "eval-fail: \(err!.localizedDescription)" : "nil")
        FileHandle.standardError.write(Data("render_result=\(r.prefix(200))\n".utf8))
        if payload.module == "archive" && r == "ok" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                web.evaluateJavaScript("SPreview.archiveInit();") { _, _ in }
            }
        }
    }
}

if let pageURL = URL(string: ResourceSchemeHandler.pageBaseURL.absoluteString) {
    web.load(URLRequest(url: pageURL))
}

DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
    if let out = snapshotPath {
        let cfg = WKSnapshotConfiguration()
        cfg.rect = CGRect(x: 0, y: 0, width: 1200, height: 800)
        web.takeSnapshot(with: cfg) { image, error in
            if let img = image, let tiff = img.tiffRepresentation,
               let rep = NSBitmapImageRep(data: tiff),
               let png = rep.representation(using: .png, properties: [:]) {
                try? png.write(to: URL(fileURLWithPath: out))
                dumpAndExit(0)
            } else {
                print("{\"FAIL\": \"snapshot: \(error?.localizedDescription ?? "none")\"}")
                exit(1)
            }
        }
    } else {
        dumpAndExit(0)
    }
}
app.run()
