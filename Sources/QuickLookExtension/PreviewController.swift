import Cocoa
import WebKit
import QuickLookUI
import UniformTypeIdentifiers

// 预览主控制器：路由文件类型 → 组装载荷 → WKWebView 渲染
final class PreviewController: NSViewController, QLPreviewingController {
    private var webView: WKWebView?
    private var payload: PreviewPayload?
    private var fileURL: URL?
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
            let payload = try buildPayload(url: url, kind: kind)
            self.payload = payload
            guard let resourceURL = Bundle.main.resourceURL else {
                throw NSError(domain: "s-preview", code: 10, userInfo: [NSLocalizedDescriptionKey: "缺少资源目录"])
            }
            let cfg = WKWebViewConfiguration()
            cfg.setURLSchemeHandler(ResourceSchemeHandler(fileURL: url), forURLScheme: ResourceSchemeHandler.scheme)
            cfg.preferences.javaScriptEnabled = true
            let web = WKWebView(frame: view.bounds, configuration: cfg)
            web.autoresizingMask = [.width, .height]
            web.navigationDelegate = self
            self.webView = web
            view.addSubview(web)
            if let pageURL = URL(string: ResourceSchemeHandler.pageBaseURL.absoluteString) {
                web.load(URLRequest(url: pageURL))
            }
            handler(nil)
        } catch {
            Self.debugLog("PAYLOAD_FAIL \(error.localizedDescription)")
            handler(error)
        }
    }

    static func debugLog(_ line: String) {
        ResourceSchemeHandler.selftestLogURL.appendText("DEBUG " + line + "\n")
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
            payload.archive = try ArchiveLister.list(url: url)
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
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Self.debugLog("PAGE_FAIL \(error.localizedDescription)")
    }
}
