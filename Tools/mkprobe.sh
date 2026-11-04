#!/bin/bash
# 参数化探针克隆构建器：mkprobe.sh <序号> <claims文件>
# claims 文件每行一个 UTI；构建 com.spreview.probe<N> 系列扩展并注册
set -euo pipefail
cd "$(dirname "$0")/.."
N="$1"
CLAIMS_FILE="$2"
ID="com.spreview.probe${N}"
B="build/probe${N}"
rm -rf "$B"
mkdir -p "$B/Probe${N}.app/Contents/MacOS" "$B/Probe${N}.app/Contents/PlugIns/Probe${N}.appex/Contents/MacOS" "$B/Probe${N}.app/Contents/PlugIns/Probe${N}.appex/Contents/Resources"

cp Probe/appex-Info.plist "$B/Probe${N}.app/Contents/PlugIns/Probe${N}.appex/Contents/Info.plist"
plutil -replace CFBundleIdentifier -string "${ID}.QuickLook" "$B/Probe${N}.app/Contents/PlugIns/Probe${N}.appex/Contents/Info.plist"
plutil -replace CFBundleExecutable -string "Probe${N}QuickLook" "$B/Probe${N}.app/Contents/PlugIns/Probe${N}.appex/Contents/Info.plist"
plutil -replace CFBundleName -string "Probe${N}QuickLook" "$B/Probe${N}.app/Contents/PlugIns/Probe${N}.appex/Contents/Info.plist"
plutil -replace CFBundleDisplayName -string "Probe${N} QuickLook" "$B/Probe${N}.app/Contents/PlugIns/Probe${N}.appex/Contents/Info.plist"
plutil -replace NSExtensionPrincipalClass -string "SPreviewProbe${N}.ProbeViewController" "$B/Probe${N}.app/Contents/PlugIns/Probe${N}.appex/Contents/Info.plist"
python3 - "$CLAIMS_FILE" "$B/Probe${N}.app/Contents/PlugIns/Probe${N}.appex/Contents/Info.plist" <<'PYEOF'
import plistlib, sys
claims_file, plist_path = sys.argv[1], sys.argv[2]
claims = [l.strip() for l in open(claims_file) if l.strip()]
with open(plist_path, 'rb') as f:
    d = plistlib.load(f)
d['NSExtension']['NSExtensionAttributes']['QLSupportedContentTypes'] = claims
with open(plist_path, 'wb') as f:
    plistlib.dump(d, f)
print('claims:', claims)
PYEOF
cp Probe/probe.html "$B/Probe${N}.app/Contents/PlugIns/Probe${N}.appex/Contents/Resources/probe.html"
swiftc -O -module-name "SPreviewProbe${N}" -Xlinker -e -Xlinker _NSExtensionMain \
    -framework Cocoa -framework WebKit -framework QuickLookUI -framework UniformTypeIdentifiers \
    Probe/ProbeViewController.swift \
    -o "$B/Probe${N}.app/Contents/PlugIns/Probe${N}.appex/Contents/MacOS/Probe${N}QuickLook" 2>/dev/null
cp Probe/app-Info.plist "$B/Probe${N}.app/Contents/Info.plist"
plutil -replace CFBundleIdentifier -string "${ID}" "$B/Probe${N}.app/Contents/Info.plist"
plutil -replace CFBundleExecutable -string "Probe${N}" "$B/Probe${N}.app/Contents/Info.plist"
plutil -replace CFBundleName -string "Probe${N}" "$B/Probe${N}.app/Contents/Info.plist"
plutil -replace CFBundleDisplayName -string "Probe${N}" "$B/Probe${N}.app/Contents/Info.plist"
# 声明自定义 UTI probe<N>
python3 - "$N" "$B/Probe${N}.app/Contents/Info.plist" <<'PYEOF'
import plistlib, sys
n, plist_path = sys.argv[1], sys.argv[2]
with open(plist_path, 'rb') as f:
    d = plistlib.load(f)
decls = [x for x in d.get('UTImportedTypeDeclarations', []) if x.get('UTTypeIdentifier') == f'com.spreview.probe{n}']
if not decls:
    decls = [{
        'UTTypeIdentifier': f'com.spreview.probe{n}',
        'UTTypeDescription': f'Probe{n} File',
        'UTTypeConformsTo': ['public.data'],
        'UTTypeTagSpecification': {'public.filename-extension': [f'sprobe{n}']},
    }]
    d['UTImportedTypeDeclarations'] = decls
with open(plist_path, 'wb') as f:
    plistlib.dump(d, f)
PYEOF
swiftc -O -module-name "Probe${N}App" -target arm64-apple-macos12.0 -framework AppKit Probe/host-main.swift \
    -o "$B/Probe${N}.app/Contents/MacOS/Probe${N}"
codesign --force --sign - "$B/Probe${N}.app/Contents/PlugIns/Probe${N}.appex"
codesign --force --sign - "$B/Probe${N}.app"
LS=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
"$LS" -f "$B/Probe${N}.app"
pluginkit -r "$B/Probe${N}.app/Contents/PlugIns/Probe${N}.appex" 2>/dev/null || true
sleep 1
pluginkit -a "$B/Probe${N}.app/Contents/PlugIns/Probe${N}.appex"
sleep 2
echo "BUILD_OK $B"
