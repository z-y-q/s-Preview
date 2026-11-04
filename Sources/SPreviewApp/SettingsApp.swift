import SwiftUI
import AppKit

// s-Preview 设置应用：个性化预览外观与各模块行为
@main
struct SPreviewSettingsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("s-Preview 设置") {
            ContentView()
                .frame(width: 640, height: 620)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("关于 s-Preview") {
                    NSApp.orderFrontStandardAboutPanel(options: [
                        .applicationName: "s-Preview",
                        .applicationIcon: NSApp.applicationIconImage,
                        .credits: NSAttributedString(string: "让 Quick Look 支持并增强更多文件格式的预览插件"),
                    ])
                }
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDockMenu(_ sender: Notification) -> NSMenu? {
        let menu = NSMenu()

        let themeItem = NSMenuItem(title: "预览主题", action: nil, keyEquivalent: "")
        let themeMenu = NSMenu()
        let current = SPreviewSettings.load().theme
        for (title, value) in [("跟随系统", "auto"), ("浅色", "light"), ("深色", "dark")] {
            let item = NSMenuItem(title: title, action: #selector(setTheme(_:)), keyEquivalent: "")
            item.representedObject = value
            item.state = current == value ? .on : .off
            item.target = self
            themeMenu.addItem(item)
        }
        themeItem.submenu = themeMenu
        menu.addItem(themeItem)

        let reset = NSMenuItem(title: "恢复默认设置", action: #selector(resetSettings), keyEquivalent: "")
        reset.target = self
        menu.addItem(reset)

        let guide = NSMenuItem(title: "打开说明文档", action: #selector(openGuide), keyEquivalent: "")
        guide.target = self
        menu.addItem(guide)
        return menu
    }

    @objc func setTheme(_ sender: NSMenuItem) {
        var s = SPreviewSettings.load()
        s.theme = sender.representedObject as? String ?? "auto"
        try? SPreviewSettings.save(s)
    }

    @objc func resetSettings() {
        try? SPreviewSettings.save(.standard)
    }

    @objc func openGuide() {
        if let url = Bundle.main.url(forResource: "README", withExtension: "md") {
            NSWorkspace.shared.open(url)
        }
    }
}

struct CodeThemeOption: Identifiable, Hashable {
    let id: String
    let name: String
}

let codeThemes: [CodeThemeOption] = [
    CodeThemeOption(id: "github", name: "GitHub"),
    CodeThemeOption(id: "atom-one-light", name: "Atom One"),
    CodeThemeOption(id: "xcode", name: "Xcode"),
    CodeThemeOption(id: "vs", name: "Visual Studio"),
    CodeThemeOption(id: "nnfx-light", name: "nnfx"),
    CodeThemeOption(id: "tokyo-night-light", name: "Tokyo Night"),
    CodeThemeOption(id: "dracula", name: "Dracula"),
    CodeThemeOption(id: "monokai", name: "Monokai"),
    CodeThemeOption(id: "nord", name: "Nord")
]

struct ContentView: View {
    @State private var s: SPreviewSettings = SPreviewSettings.load()
    @State private var savedNote = ""
    @State private var version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    @State private var appIcon: NSImage? = Bundle.main.image(forResource: "AppIcon")

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    if let icon = appIcon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("s-Preview").font(.title2).fontWeight(.semibold)
                        Text("版本 \(version) · 让 Quick Look 支持更多格式")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }
            Section("预览类别") {
                Text("关闭某个类别后，这类文件会交还 macOS 原生预览；macOS 没有原生预览的格式则显示「无预览」。")
                    .font(.footnote).foregroundStyle(.secondary)
                Toggle("代码与文本（源代码高亮）", isOn: $s.catCode)
                Toggle("Markdown 与 Jupyter（公式排版）", isOn: $s.catDocs)
                Toggle("压缩包清单", isOn: $s.catArchive)
                Toggle("图片信息条（webp / avif）", isOn: $s.catImage)
                Toggle("三维模型交互渲染", isOn: $s.catModel)
                Toggle("兜底预览（未识别文件信息 + 十六进制）", isOn: $s.catData)
                Text("jpg、png、pdf、影片、音乐等格式 macOS 原生预览本来就很完善，s-Preview 从不介入。")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Section("外观") {
                Picker("界面主题", selection: $s.theme) {
                    Text("跟随系统").tag("auto")
                    Text("浅色").tag("light")
                    Text("深色").tag("dark")
                }
                Picker("代码高亮主题", selection: $s.codeTheme) {
                    ForEach(codeThemes) { t in
                        Text(t.name).tag(t.id)
                    }
                }
                Stepper("代码字号 \(s.fontSize)pt", value: $s.fontSize, in: 9...24)
                Stepper("制表符宽度 \(s.tabWidth)", value: $s.tabWidth, in: 2...8)
                Toggle("自动换行", isOn: $s.wordWrap)
                Toggle("显示行号", isOn: $s.lineNumbers)
            }
            Section("文档") {
                Toggle("数学公式排版（Markdown 与 Jupyter）", isOn: $s.markdownMath)
            }
            Section("图片") {
                Toggle("显示尺寸与格式信息条", isOn: $s.imageInfoOverlay)
            }
            Section("压缩包") {
                Toggle("显示压缩后大小", isOn: $s.archiveShowCompressed)
                Toggle("显示修改时间", isOn: $s.archiveShowDate)
                Toggle("显示权限列（部分格式可用）", isOn: $s.archiveShowPermissions)
            }
            Section("三维模型") {
                Toggle("地面网格", isOn: $s.modelGrid)
                Toggle("坐标轴", isOn: $s.modelAxes)
                Toggle("默认线框模式", isOn: $s.modelWireframe)
                Toggle("默认显示包围盒", isOn: $s.modelBBox)
                Toggle("默认显示骨架", isOn: $s.modelSkeleton)
                Toggle("自动旋转", isOn: $s.modelAutoRotate)
                Picker("背景", selection: $s.modelBackground) {
                    Text("跟随主题").tag("auto")
                    Text("浅色").tag("light")
                    Text("深色").tag("dark")
                }
            }
            Section("测试") {
                Toggle("自检模式（向扩展容器记录渲染结果）", isOn: $s.testMode)
            }
            Section {
                Button("保存设置") {
                    do {
                        try SPreviewSettings.save(s)
                        savedNote = "已保存，新预览立即生效"
                    } catch {
                        savedNote = "保存失败：\(error.localizedDescription)"
                    }
                }
                .buttonStyle(.borderedProminent)
                if !savedNote.isEmpty {
                    Text(savedNote).font(.footnote).foregroundStyle(.secondary)
                }
                Text("设置写入：\(SPreviewSettings.primarySettingsURL.path)")
                    .font(.caption2).foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
