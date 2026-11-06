import Cocoa
import WebKit
import QuickLookUI
import UniformTypeIdentifiers

// 预览主控制器：路由文件类型 → 组装载荷 → WKWebView 渲染；压缩包支持树形浏览与选择性解压
final class PreviewController: NSViewController, QLPreviewingController {
    private var webView: WKWebView?
    private var payload: PreviewPayload?
    private var fileURL: URL?
    private var archiveSession: ArchiveSession?
    private var pendingArchiveInit = false
    private let settings = SPreviewSettings.load()

    override func loadView() {
        let v = NSView(frame: NSRect(x: 0, y: 0, width: 1000, height: 700))
        v.wantsLayer = true
        v.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        self.view = v
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        Self.debugLog("CALLED \(url.lastPathComponent)")
        self.fileURL = url
        do {
            let kind = PreviewKind.detect(url: url)
            // 用户关闭的类别：拒绝预览，系统自动回退到原生预览
            let moduleGuess = kindModule(kind)
            if !settings.categoryEnabled(moduleGuess) {
                Self.debugLog("DECLINED category=\(moduleGuess)")
                handler(NSError(domain: "com.spreview.s-preview", code: 1001,
                                userInfo: [NSLocalizedDescriptionKey: "该类别已在 s-Preview 中关闭，已交还系统预览"]))
                return
            }

            if kind == .archive {
                // 压缩包：后台解析清单（大压缩包可达数秒），完成后加载页面
                let session = ArchiveSession(url: url)
                self.archiveSession = session
                handler(nil)
                DispatchQueue.global(qos: .userInitiated).async {
                    session.loadTree()
                    DispatchQueue.main.async {
                        self.pendingArchiveInit = true
                        self.installWebView(session: session)
                    }
                }
                return
            }

            let payload = try buildPayload(url: url, kind: kind)
            self.payload = payload
            installWebView(session: nil)
            handler(nil)
        } catch {
            Self.debugLog("PAYLOAD_FAIL \(error.localizedDescription)")
            handler(error)
        }
    }

    private func installWebView(session: ArchiveSession?) {
        guard let resourceURL = Bundle.main.resourceURL else {
            Self.debugLog("RESOURCE_DIR_MISSING")
            return
        }
        let cfg = WKWebViewConfiguration()
        cfg.setURLSchemeHandler(ResourceSchemeHandler(fileURL: fileURL ?? URL(fileURLWithPath: "/"),
                                                      archiveSession: session),
                                forURLScheme: ResourceSchemeHandler.scheme)
        cfg.preferences.javaScriptEnabled = true
        cfg.userContentController.add(self, name: "spreview")
        let web = WKWebView(frame: view.bounds, configuration: cfg)
        web.autoresizingMask = [.width, .height]
        web.navigationDelegate = self
        self.webView = web
        view.addSubview(web)
        if let pageURL = URL(string: ResourceSchemeHandler.pageBaseURL.absoluteString) {
            web.load(URLRequest(url: pageURL))
        }
    }

    static func debugLog(_ line: String) {
        ResourceSchemeHandler.selftestLogURL.appendText("DEBUG " + line + "\n")
    }

    static func jsString(_ s: String) -> String {
        guard let data = try? JSONEncoder().encode([s]),
              let arr = String(data: data, encoding: .utf8) else { return "\"\"" }
        // ["..."] 去掉首尾括号即得到转义后的字符串字面量
        return String(arr.dropFirst().dropLast())
    }

    // MARK: - 载荷组装
    func buildPayload(url: URL, kind: PreviewKind) throws -> PreviewPayload {
        var fileSize: Int64 = 0
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let s = attrs[.size] as? Int64 {
            fileSize = s
        }
        let dark = effectiveDark()
        var payload = PreviewPayload(
            module: "code", fileName: url.lastPathComponent, fileSize: fileSize,
            kind: utiDescription(url: url), dark: dark, settings: settings,
            test: settings.testMode, text: nil, truncated: nil, language: nil,
            cells: nil, archive: nil,
            imageWidth: nil, imageHeight: nil, imageFormat: nil, imageDepth: nil,
            imageDPI: nil, imageAnimated: nil, modelFormat: nil
        )

        switch kind {
        case .markdown:
            payload.module = "markdown"
            let (text, truncated) = try ContentReader.readText(url: url, limit: settings.textSizeLimit)
            payload.text = text
            payload.truncated = truncated
            payload.language = "markdown"
        case .notebook:
            payload.module = "notebook"
            payload.cells = try NotebookParser.parse(url: url, textLimit: settings.textSizeLimit)
        case .archive:
            payload.module = "archive"
        case .image:
            payload.module = "image"
            if let info = ContentReader.imageInfo(url: url) {
                payload.imageWidth = info.width
                payload.imageHeight = info.height
                payload.imageFormat = info.format
                payload.imageDepth = info.depth
                payload.imageDPI = info.dpi
                payload.imageAnimated = info.animated
            }
        case .model3D:
            payload.module = "model"
            payload.modelFormat = url.pathExtension.lowercased()
        case .fallbackCode:
            payload.module = "code"
            let (text, truncated) = try ContentReader.readText(url: url, limit: settings.textSizeLimit)
            payload.text = text
            payload.truncated = truncated
            payload.language = languageFor(url: url)
        case .info:
            payload.module = "info"
            let (dump, truncated) = try ContentReader.hexdump(url: url, bytes: 4096)
            payload.text = dump
            payload.truncated = truncated
            payload.language = "hexdump"
        case .code:
            payload.module = "code"
            let (text, truncated) = try ContentReader.readText(url: url, limit: settings.textSizeLimit)
            payload.text = text
            payload.truncated = truncated
            payload.language = languageFor(url: url)
        }
        return payload
    }

    func languageFor(url: URL) -> String? {
        HLJSAliases.alias(ext: url.pathExtension.lowercased(), name: url.lastPathComponent.lowercased())
    }

    func kindModule(_ kind: PreviewKind) -> String {
        switch kind {
        case .code: return "code"
        case .markdown: return "markdown"
        case .notebook: return "notebook"
        case .archive: return "archive"
        case .image: return "image"
        case .model3D: return "model"
        case .fallbackCode: return "code"
        case .info: return "info"
        }
    }

    func effectiveDark() -> Bool {
        switch settings.theme {
        case "light": return false
        case "dark": return true
        default:
            let name = NSApp?.effectiveAppearance.name.rawValue ?? "NSAppearanceNameAqua"
            return name.contains("Dark")
        }
    }

    func utiDescription(url: URL) -> String {
        if let t = UTType(filenameExtension: url.pathExtension) { return t.identifier }
        return "public.data"
    }
}

// MARK: - 页面导航与注入
extension PreviewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Self.debugLog("PAGE_LOADED module=\(payload?.module ?? "?")")
        guard let payload = payload,
              let data = try? JSONEncoder().encode(payload),
              let json = String(data: data, encoding: .utf8) else {
            Self.debugLog("ENCODE_FAIL")
            return
        }
        webView.evaluateJavaScript("SPreview.render(\(json));") { _, err in
            if let err = err {
                Self.debugLog("INJECT_FAIL \(err.localizedDescription)")
            } else {
                Self.debugLog("INJECT_OK")
            }
        }
        if self.pendingArchiveInit {
            self.pendingArchiveInit = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                webView.evaluateJavaScript("SPreview.archiveInit();") { _, err in
                    if let err = err {
                        Self.debugLog("ARCHIVE_INIT_FAIL \(err.localizedDescription)")
                    } else {
                        Self.debugLog("ARCHIVE_INIT_OK")
                    }
                }
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Self.debugLog("PAGE_FAIL \(error.localizedDescription)")
    }
}

// MARK: - 页面 → 原生：选择性解压
extension PreviewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard message.name == "spreview",
              let body = message.body as? [String: Any],
              body["action"] as? String == "extract",
              let paths = body["paths"] as? [String], !paths.isEmpty else { return }
        let auto = body["auto"] as? Bool ?? false
        startExtraction(paths: Set(paths), auto: auto)
    }

    private func startExtraction(paths: Set<String>, auto: Bool) {
        guard let url = fileURL else { return }
        let web = webView

        func run(dest: URL) {
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    var extracted = 0
                    let count = try ArchiveSession.extract(url: url, selected: paths, dest: dest) { done, total, current in
                        extracted = done
                        DispatchQueue.main.async {
                            web?.evaluateJavaScript("SPreview.archiveProgress(\(done),\(total),\(Self.jsString(current)));", completionHandler: nil)
                        }
                    }
                    DispatchQueue.main.async {
                        Self.debugLog("EXTRACT_DONE \(extracted) -> \(dest.path)")
                        web?.evaluateJavaScript("SPreview.archiveDone(true,\(extracted),\(Self.jsString(dest.path)));", completionHandler: nil)
                    }
                    _ = count
                } catch {
                    DispatchQueue.main.async {
                        Self.debugLog("EXTRACT_FAIL \(error.localizedDescription)")
                        web?.evaluateJavaScript("SPreview.archiveDone(false,0,\(Self.jsString(error.localizedDescription)));", completionHandler: nil)
                    }
                }
            }
        }

        if auto {
            // 自检模式：免面板，解压到扩展容器临时目录
            let dir = FileManager.default.temporaryDirectory
                .appendingPathComponent("spreview-extract-\(Int(Date().timeIntervalSince1970))")
            run(dest: dir)
            return
        }

        DispatchQueue.main.async {
            let panel = NSOpenPanel()
            panel.canChooseDirectories = true
            panel.canChooseFiles = false
            panel.canCreateDirectories = true
            panel.prompt = "解压到此处"
            panel.nameFieldStringValue = url.deletingPathExtension().lastPathComponent
            panel.message = "选择解压目标文件夹，已选 \(paths.count) 个条目"
            if panel.runModal() == .OK, let dest = panel.url {
                run(dest: dest)
            } else {
                web?.evaluateJavaScript("SPreview.archiveDone(false,0,'cancelled');", completionHandler: nil)
            }
        }
    }
}
