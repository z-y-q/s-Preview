import Foundation

// highlight.js 语言别名映射（按扩展名）
public enum HLJSAliases {
    static let map: [String: String] = [
        "py": "python", "pyw": "python", "pyi": "python",
        "go": "go",
        "js": "javascript", "mjs": "javascript", "cjs": "javascript", "jsx": "javascript",
        "ts": "typescript", "tsx": "typescript", "mts": "typescript", "cts": "typescript",
        "vue": "xml", "kt": "kotlin", "kts": "kotlin",
        "dart": "dart", "rs": "rust", "swift": "swift",
        "c": "c", "h": "c", "cpp": "cpp", "hpp": "cpp", "cc": "cpp", "hh": "cpp", "cxx": "cpp",
        "m": "objectivec", "mm": "objectivec",
        "java": "java", "rb": "ruby", "php": "php",
        "sh": "bash", "bash": "bash", "zsh": "bash", "fish": "bash", "command": "bash",
        "yaml": "yaml", "yml": "yaml", "toml": "ini", "ini": "ini", "cfg": "ini", "conf": "ini", "properties": "ini",
        "lua": "lua", "sql": "sql", "r": "r", "pl": "perl", "pm": "perl", "ps1": "powershell", "psm1": "powershell",
        "scss": "scss", "sass": "scss", "less": "less", "css": "css",
        "html": "xml", "htm": "xml", "xml": "xml", "plist": "xml", "svg": "xml",
        "json": "json", "jsonc": "json", "gradle": "gradle", "cmake": "cmake", "mk": "makefile",
        "proto": "protobuf", "graphql": "graphql", "gql": "graphql", "tf": "hcl", "hcl": "hcl",
        "vim": "vim", "ex": "elixir", "exs": "elixir", "erl": "erlang", "hs": "haskell",
        "ml": "ocaml", "fs": "fsharp", "fsi": "fsharp", "fsx": "fsharp", "cs": "csharp",
        "vb": "vbnet", "asm": "x86asm", "s": "x86asm", "nasm": "nasm", "bat": "dos", "cmd": "dos",
        "awk": "awk", "sed": "sed", "tcl": "tcl", "zig": "zig", "nim": "nim", "cr": "crystal",
        "jl": "julia", "scala": "scala", "sbt": "scala", "groovy": "groovy", "erb": "erb",
        "hbs": "handlebars", "ejs": "ejs", "pug": "pug", "jade": "pug", "styl": "stylus",
        "txt": "plaintext", "text": "plaintext", "log": "accesslog", "csv": "csv", "tsv": "csv",
        "diff": "diff", "patch": "diff", "lock": "plaintext", "env": "ini",
        "markdown": "markdown", "md": "markdown", "ipynb": "json",
        "dockerfile": "dockerfile", "makefile": "makefile", "gitignore": "plaintext",
        "gitattributes": "plaintext", "editorconfig": "ini", "npmrc": "ini",
        "babelrc": "json", "eslintrc": "json", "prettierrc": "json",
        "xcconfig": "ini", "strings": "ini", "entitlements": "xml", "pbxproj": "plaintext",
        "resx": "xml", "idl": "cpp", "thrift": "cpp", "liquid": "liquid", "twig": "twig",
        "rmd": "markdown", "coffee": "coffeescript", "bat2": "dos"
    ]

    public static func alias(ext: String, name: String) -> String {
        let n = name.lowercased()
        if n == "podfile" || n == "gemfile" || n == "rakefile" || n == "brewfile" { return "ruby" }
        if n == "makefile" || n.hasPrefix("makefile") { return "makefile" }
        if n == "dockerfile" || n.hasPrefix("dockerfile") { return "dockerfile" }
        if n == "cmakelists.txt" { return "cmake" }
        if n == "license" || n == "readme" || n == "authors" || n == "notice" || n == "contributing" { return "plaintext" }
        if n.hasPrefix(".") { return "plaintext" }
        if let a = map[ext] { return a }
        return "plaintext"
    }
}
