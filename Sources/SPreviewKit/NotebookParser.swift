import Foundation

// Jupyter Notebook 解析：.ipynb JSON → 结构化单元
public enum NotebookParser {
    public static func parse(url: URL, textLimit: Int) throws -> [NotebookCell] {
        let data = try Data(contentsOf: url)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "NotebookParser", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "notebook 根节点不是对象"])
        }
        guard let cells = root["cells"] as? [[String: Any]] else {
            throw NSError(domain: "NotebookParser", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "缺少 cells 字段（可能不是有效的 .ipynb）"])
        }
        var result: [NotebookCell] = []
        result.reserveCapacity(cells.count)
        for cell in cells {
            let type = cell["cell_type"] as? String ?? "raw"
            let source = joinSource(cell["source"])
            var lang: String? = nil
            var exec: Int? = nil
            var outputs: [NotebookOutput]? = nil
            if type == "code" {
                if let meta = cell["metadata"] as? [String: Any] { _ = meta }
                if let ec = cell["execution_count"] as? Int { exec = ec }
                else if let ec = cell["execution_count"] as? String { exec = Int(ec) }
                if let outs = cell["outputs"] as? [[String: Any]] {
                    outputs = outs.map { parseOutput($0) }
                }
            }
            if type == "code", let m = cell["metadata"] as? [String: Any] {
                _ = m
            }
            if let l = languageHint(source, cell: cell) { lang = l }
            result.append(NotebookCell(type: type, source: source, language: lang,
                                       outputs: outputs, executionCount: exec))
        }
        return result
    }

    // source 既可能是字符串数组，也可能是单个字符串
    static func joinSource(_ value: Any?) -> String {
        if let arr = value as? [String] { return arr.joined() }
        if let s = value as? String { return s }
        return ""
    }

    static func parseOutput(_ o: [String: Any]) -> NotebookOutput {
        let outputType = o["output_type"] as? String ?? ""
        if outputType == "stream" {
            return NotebookOutput(kind: "stream", content: joinSource(o["text"]), mimeType: "text/plain")
        }
        if outputType == "error" {
            let name = o["ename"] as? String ?? "Error"
            let value = o["evalue"] as? String ?? ""
            let trace = joinSource(o["traceback"])
            return NotebookOutput(kind: "error", content: "\(name): \(value)\n\(trace)", mimeType: nil)
        }
        if let dataMap = o["data"] as? [String: Any] {
            if let html = dataMap["text/html"] as? [String] {
                return NotebookOutput(kind: "html", content: html.joined(), mimeType: "text/html")
            }
            if let html = dataMap["text/html"] as? String {
                return NotebookOutput(kind: "html", content: html, mimeType: "text/html")
            }
            if let png = dataMap["image/png"] as? [String] {
                return NotebookOutput(kind: "image", content: png.joined(), mimeType: "image/png")
            }
            if let png = dataMap["image/png"] as? String {
                return NotebookOutput(kind: "image", content: png, mimeType: "image/png")
            }
            if let svg = dataMap["image/svg+xml"] as? [String] {
                return NotebookOutput(kind: "html", content: svg.joined(), mimeType: "image/svg+xml")
            }
            if let svg = dataMap["image/svg+xml"] as? String {
                return NotebookOutput(kind: "html", content: svg, mimeType: "image/svg+xml")
            }
            if let latex = dataMap["text/latex"] as? [String] {
                return NotebookOutput(kind: "text", content: latex.joined(), mimeType: "text/latex")
            }
            if let plain = dataMap["text/plain"] as? [String] {
                return NotebookOutput(kind: "text", content: plain.joined(), mimeType: "text/plain")
            }
            if let plain = dataMap["text/plain"] as? String {
                return NotebookOutput(kind: "text", content: plain, mimeType: "text/plain")
            }
            for (mime, value) in dataMap {
                if mime.hasPrefix("image/") {
                    if let b64 = value as? String { return NotebookOutput(kind: "image", content: b64, mimeType: mime) }
                    if let arr = value as? [String] { return NotebookOutput(kind: "image", content: arr.joined(), mimeType: mime) }
                }
            }
        }
        if let banner = o["enamel"] as? String { return NotebookOutput(kind: "text", content: banner, mimeType: nil) }
        return NotebookOutput(kind: "text", content: "", mimeType: nil)
    }

    static func languageHint(_ source: String, cell: [String: Any]) -> String? {
        if let meta = cell["metadata"] as? [String: Any],
           let langMeta = meta["language_info"] as? [String: Any],
           let name = langMeta["name"] as? String {
            return alias(name)
        }
        return "python"
    }

    static func alias(_ name: String) -> String {
        switch name.lowercased() {
        case "python", "python3", "ipython": return "python"
        case "r": return "r"
        case "julia": return "julia"
        case "javascript", "js", "node": return "javascript"
        case "bash", "shell": return "bash"
        default: return name.lowercased()
        }
    }
}
