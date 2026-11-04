#!/bin/bash
# 真实 Quick Look 管线批测：安装应用 → 批量预览（单一窗口） → 从容器自检日志断言
# 注意：本脚本依赖 QLPreviewPanel 测试宿主，该入口对第三方扩展的选择不稳定；
# 日常回归验证请用 run-harness-tests.sh（无窗口、28 样本全量断言）。
# 真实环境验证以 Finder 空格键为准（已实测正常）。
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"

echo "== 安装应用到 /Applications"
rm -rf /Applications/s-Preview.app
cp -R "$ROOT/build/s-Preview/s-Preview.app" /Applications/s-Preview.app
LS=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
"$LS" -f /Applications/s-Preview.app
# 关键：先移除再注册，否则 QLSupportedContentTypes 声明不会刷新
pluginkit -r /Applications/s-Preview.app/Contents/PlugIns/s-Preview.QuickLook.appex 2>/dev/null || true
sleep 1
pluginkit -a /Applications/s-Preview.app/Contents/PlugIns/s-Preview.QuickLook.appex
sleep 2
pluginkit -m -p com.apple.quicklook.preview 'QLSupportedContentTypes=public.plain-text' 2>/dev/null | grep -q "com.spreview.s-preview.QuickLook" && echo CLAIMS_OK || { echo "claims missing"; exit 1; }
sleep 1

echo "== 开启自检模式并清空自检日志"
mkdir -p TestResults
SELFTEST_LOG="$HOME/Library/Application Support/s-Preview/selftest.log"
rm -f "$SELFTEST_LOG"
rm -f "$HOME/Library/Containers/com.spreview.s-preview.QuickLook/Data/Library/Application Support/s-Preview/selftest.log"
python3 - <<'PYEOF'
import json, os
home = os.path.expanduser("~")
paths = [
    home + "/Library/Application Support/s-Preview/settings.json",
    home + "/Library/Containers/com.spreview.s-preview.QuickLook/Data/Library/Application Support/s-Preview/settings.json",
]
base = {
    "theme": "auto", "codeTheme": "github", "fontSize": 13, "tabWidth": 4,
    "wordWrap": False, "lineNumbers": True, "markdownMath": True,
    "imageInfoOverlay": True,
    "archiveShowCompressed": True, "archiveShowDate": True, "archiveShowPermissions": False,
    "modelGrid": True, "modelAxes": True, "modelWireframe": False, "modelBBox": False,
    "modelSkeleton": False, "modelAutoRotate": False, "modelBackground": "auto",
    "testMode": True, "textSizeLimit": 5000000,
    "catCode": True, "catDocs": True, "catArchive": True,
    "catImage": True, "catModel": True, "catData": True
}
for p in paths:
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, "w") as f:
        json.dump(base, f)
print("settings written")
PYEOF

pkill -f QuickLookUIService 2>/dev/null || true
sleep 2

echo "== 预热并确认扩展可被拉起"
WARM_OK=0
for attempt in 1 2 3 4 5; do
    pluginkit -a /Applications/s-Preview.app/Contents/PlugIns/s-Preview.QuickLook.appex 2>/dev/null || true
    sleep 2
    "$ROOT/build/TestHost/TestHost.app/Contents/MacOS/TestHost" \
        TestSamples/code/demo.py --per 8 >/dev/null 2>&1 || true
    sleep 1
    CAND="$HOME/Library/Containers/com.spreview.s-preview.QuickLook/Data/Library/Application Support/s-Preview/selftest.log"
    if grep -q "CALLED" "$SELFTEST_LOG" 2>/dev/null || grep -q "CALLED" "$CAND" 2>/dev/null; then
        echo "  attempt ${attempt}: extension responded"
        WARM_OK=1
        break
    fi
    echo "  attempt ${attempt}: no response, retry"
done
if [ "$WARM_OK" -ne 1 ]; then
    echo "extension never responded, abort"
    exit 1
fi
rm -f "$SELFTEST_LOG"

echo "== 批量预览（单一窗口会话）"
"$ROOT/build/TestHost/TestHost.app/Contents/MacOS/TestHost" \
    TestSamples/code/demo.py \
    TestSamples/code/main.go \
    TestSamples/code/App.vue \
    TestSamples/code/Button.jsx \
    TestSamples/code/User.kt \
    TestSamples/code/Point.dart \
    TestSamples/code/lib.rs \
    TestSamples/code/README \
    TestSamples/code/Podfile \
    TestSamples/code/LICENSE \
    TestSamples/code/Gemfile \
    TestSamples/docs/formula.md \
    TestSamples/docs/demo.ipynb \
    TestSamples/arch/demo.zip \
    TestSamples/arch/demo.tar \
    TestSamples/arch/demo.tgz \
    TestSamples/arch/demo.7z \
    TestSamples/arch/single.gz \
    TestSamples/docs/gradient.webp \
    TestSamples/docs/gradient.avif \
    TestSamples/models/cube.glb \
    TestSamples/models/cube.gltf \
    TestSamples/models/cube.obj \
    TestSamples/models/cube.stl \
    TestSamples/models/cube.ply \
    TestSamples/models/cube.dae \
    TestSamples/models/cube.fbx \
    TestSamples/models/cube.usdz \
    --per 7 2>&1 | grep -E "PREVIEW|BATCH_DONE|PANEL_OPEN"

sleep 1

echo "== 断言报告"
SELFTEST_LOG="$SELFTEST_LOG" python3 - <<'PYEOF'
import json, os, sys
home = os.path.expanduser("~")
candidates = [
    home + "/Library/Application Support/s-Preview/selftest.log",
    home + "/Library/Containers/com.spreview.s-preview.QuickLook/Data/Library/Application Support/s-Preview/selftest.log",
    home + "/Library/Containers/com.spreview.s-preview.QuickLook/Data/Library/Application Support/selftest.log",
]
lines = []
for path in candidates:
    if os.path.exists(path):
        lines += open(path).read().splitlines()
reports = {}
for line in lines:
        if not line.startswith("REPORT "):
            continue
        q = line[len("REPORT "):].strip()
        parts = {}
        for kv in q.split("&"):
            if "=" in kv:
                k, v = kv.split("=", 1)
                parts[k] = v
        c = parts.get("c")
        try:
            d = json.loads(parts.get("d", "{}"))
        except Exception:
            d = {}
        reports.setdefault(c, []).append(d)

fails = []
def expect(cond, msg):
    if not cond:
        fails.append(msg)

codes = reports.get("code", [])
expect(len(codes) >= 11, f"code 报告数量不足: {len(codes)}")
expect(any(r.get("tokens", 0) >= 3 for r in codes), "code 未见高亮 token")
expect(any(r.get("language") == "python" for r in codes), "code 缺 python 语言")
expect(any(r.get("language") in ("vue", "xml") for r in codes), "code 缺 vue")

md = reports.get("markdown", [])
expect(len(md) >= 1 and md[0].get("katex", 0) >= 3, "markdown KaTeX 公式数量不足")
expect(len(md) >= 1 and md[0].get("tables", 0) >= 1, "markdown 表格缺失")

nb = reports.get("notebook", [])
expect(len(nb) >= 1 and nb[0].get("cells", 0) == 5, "notebook 单元数量错误")
expect(len(nb) >= 1 and nb[0].get("images", 0) == 1, "notebook 图片输出缺失")
expect(len(nb) >= 1 and nb[0].get("katex", 0) >= 1, "notebook 公式缺失")

arcs = reports.get("archive", [])
expect(len(arcs) >= 5, f"archive 报告数量不足: {len(arcs)}")
expect(any(r.get("format", "").lower().startswith("zip") for r in arcs), "archive 缺 zip")
expect(any("7-zip" in r.get("format", "").lower() for r in arcs), "archive 缺 7z")
expect(any(r.get("rows", 0) == 1 for r in arcs), "archive 缺 gz 单文件")

imgs = reports.get("image", [])
expect(len(imgs) >= 2, "image 报告数量不足")
expect(all(r.get("loaded") for r in imgs), "image 有解码失败")
expect(any(r.get("naturalWidth") == 120 for r in imgs), "image 尺寸报告缺失")

models = reports.get("model", [])
expect(len(models) >= 8, f"model 报告数量不足: {len(models)}")
expect(all(r.get("rendered") for r in models), f"model 有渲染失败: {models}")
expect(any(r.get("triangles") == 12 for r in models), "model 三角面数不对")
expect(any(r.get("renderer") for r in models), "model 渲染器信息缺失")

print("REPORTS:", {k: len(v) for k, v in reports.items()})
if fails:
    print("FAILS:")
    for f in fails:
        print("  -", f)
    sys.exit(1)
print("ALL PASS")
PYEOF
