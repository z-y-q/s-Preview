import Foundation
import WebKit

// 自定义协议：同源提供页面资源、预览目标文件字节与自检报告回收
final class ResourceSchemeHandler: NSObject, WKURLSchemeHandler {
    let fileURL: URL
    weak var archiveSession: ArchiveSession?
    static let scheme = "spreview-resource"

    init(fileURL: URL, archiveSession: ArchiveSession? = nil) {
        self.fileURL = fileURL
        self.archiveSession = archiveSession
        super.init()
    }

    static var selftestLogURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/s-Preview/selftest.log")
    }

    static var pageBaseURL: URL {
        URL(string: "\(scheme)://page/Viewer/spreview.html")!
    }

    // 页面资源根目录：扩展进程取自身资源包；离屏验证器回退到已安装的扩展包
    static var resourceBase: URL {
        if let u = Bundle.main.resourceURL,
           FileManager.default.fileExists(atPath: u.appendingPathComponent("Viewer/spreview.html").path) {
            return u
        }
        return URL(fileURLWithPath: "/Applications/s-Preview.app/Contents/PlugIns/s-Preview.QuickLook.appex/Contents/Resources")
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url,
              url.scheme == Self.scheme else { return }
        let host = url.host ?? ""

        switch host {
        case "report":
            let query = url.query.map { $0.removingPercentEncoding ?? $0 } ?? ""
            Self.selftestLogURL.appendText("REPORT " + query + "\n")
            respond(task: urlSchemeTask, url: url, data: Data("ok".utf8), mime: "text/plain")
        case "file":
            do {
                let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
                respond(task: urlSchemeTask, url: url, data: data, mime: Self.mimeFor(fileURL.pathExtension))
            } catch {
                urlSchemeTask.didFailWithError(error)
            }
        case "page":
            // /file 提供预览目标文件字节（与页面同源，避免跨源拦截）
            if url.path == "/file" {
                do {
                    let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
                    respond(task: urlSchemeTask, url: url, data: data, mime: Self.mimeFor(fileURL.pathExtension))
                } catch {
                    urlSchemeTask.didFailWithError(error)
                }
                return
            }
            // 压缩包树形清单（TSV）
            if url.path == "/archive.tsv" {
                guard let session = archiveSession else {
                    urlSchemeTask.didFailWithError(NSError(domain: Self.scheme, code: 404))
                    return
                }
                let tsv = session.currentTSV()
                respond(task: urlSchemeTask, url: url, data: Data(tsv.utf8), mime: "text/plain")
                return
            }
            if url.path == "/report" {
                let query = url.query.map { $0.removingPercentEncoding ?? $0 } ?? ""
                Self.selftestLogURL.appendText("REPORT " + query + "\n")
                respond(task: urlSchemeTask, url: url, data: Data("ok".utf8), mime: "text/plain")
                return
            }
            serveResource(urlSchemeTask: urlSchemeTask, url: url)
        default:
            urlSchemeTask.didFailWithError(NSError(domain: Self.scheme, code: 404))
        }
    }

    // 页面资源：仅允许 Viewer 目录内的相对路径
    private func serveResource(urlSchemeTask: WKURLSchemeTask, url: URL) {
        var comps = url.pathComponents.filter { $0 != "/" }
        // pathComponents 形如 ["/", "Viewer", "app.js"]
        guard comps.first == "Viewer", comps.count >= 2 else {
            urlSchemeTask.didFailWithError(NSError(domain: Self.scheme, code: 403))
            return
        }
        for c in comps where c == ".." {
            urlSchemeTask.didFailWithError(NSError(domain: Self.scheme, code: 403))
            return
        }
        let resourceURL = Self.resourceBase
        let fileURL = resourceURL.appendingPathComponent(comps.joined(separator: "/"))
        guard FileManager.default.fileExists(atPath: fileURL.path),
              fileURL.standardizedFileURL.path.hasPrefix(resourceURL.standardizedFileURL.path) else {
            urlSchemeTask.didFailWithError(NSError(domain: Self.scheme, code: 404))
            return
        }
        do {
            let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
            respond(task: urlSchemeTask, url: url, data: data,
                    mime: Self.mimeFor(fileURL.pathExtension))
        } catch {
            urlSchemeTask.didFailWithError(error)
        }
    }

    static func mimeFor(_ extRaw: String) -> String {
        let ext = extRaw.lowercased()
        switch ext {
        case "html": return "text/html"
        case "css": return "text/css"
        case "js", "mjs": return "text/javascript"
        case "json": return "application/json"
        case "woff2": return "font/woff2"
        case "woff": return "font/woff"
        case "wasm": return "application/wasm"
        case "png": return "image/png"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        case "avif": return "image/avif"
        case "jpeg", "jpg": return "image/jpeg"
        case "glb": return "model/gltf-binary"
        case "gltf": return "model/gltf+json"
        case "obj": return "text/plain"
        case "stl", "ply", "fbx": return "application/octet-stream"
        case "dae": return "model/vnd.collada+xml"
        case "usdz": return "model/vnd.usdz+zip"
        default: return "application/octet-stream"
        }
    }

    private func respond(task: WKURLSchemeTask, url: URL, data: Data, mime: String) {
        let resp = URLResponse(url: url, mimeType: mime, expectedContentLength: data.count, textEncodingName: mime.hasPrefix("text") || mime.hasPrefix("model/gltf+json") ? "utf-8" : nil)
        task.didReceive(resp)
        task.didReceive(data)
        task.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}
}

extension URL {
    func appendText(_ text: String) {
        let dir = deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let handle = try? FileHandle(forWritingTo: self) {
            _ = try? handle.seekToEnd()
            _ = try? handle.write(contentsOf: Data(text.utf8))
            try? handle.close()
        } else {
            try? Data(text.utf8).write(to: self)
        }
    }
}
