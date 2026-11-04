#!/bin/bash
# s-Preview 产品构建：编译、组装、嵌入动态库、签名、安装注册
set -euo pipefail
cd "$(dirname "$0")"
ROOT="$PWD"
BUILD="$ROOT/build/s-Preview"
APP="$BUILD/s-Preview.app"
LIBARC=/opt/homebrew/opt/libarchive
KIT="$ROOT/Sources/SPreviewKit"
EXT="$ROOT/Sources/QuickLookExtension"
MODMAP="$ROOT/Sources/Clibarchive/include/module.modulemap"
CLIBINC="$ROOT/Sources/Clibarchive/include"

rm -rf "$BUILD"
mkdir -p "$APP/Contents/MacOS" \
         "$APP/Contents/Resources/Viewer" \
         "$APP/Contents/PlugIns/s-Preview.QuickLook.appex/Contents/MacOS" \
         "$APP/Contents/PlugIns/s-Preview.QuickLook.appex/Contents/Resources/Viewer" \
         "$APP/Contents/PlugIns/s-Preview.QuickLook.appex/Contents/Frameworks"

XCC=(-Xcc "-I$CLIBINC" -Xcc "-I$LIBARC/include" -Xcc "-fmodule-map-file=$MODMAP")

echo "-- 编译预览扩展二进制"
swiftc -O -module-name SPreviewQuickLook \
    "${XCC[@]}" \
    -framework Cocoa -framework WebKit -framework QuickLookUI -framework UniformTypeIdentifiers -framework ImageIO \
    -L"$LIBARC/lib" -larchive \
    -Xlinker -rpath -Xlinker "@executable_path/../Frameworks" \
    -Xlinker -e -Xlinker _NSExtensionMain \
    "$KIT/SettingsStore.swift" "$KIT/UTIRouter.swift" "$KIT/Payload.swift" "$KIT/ContentReader.swift" "$KIT/NotebookParser.swift" "$KIT/ArchiveLister.swift" \
    "$EXT/PreviewController.swift" "$EXT/HLJSAliases.swift" "$EXT/ResourceSchemeHandler.swift" \
    -o "$APP/Contents/PlugIns/s-Preview.QuickLook.appex/Contents/MacOS/s-Preview.QuickLook"

echo "-- 嵌入 libarchive 及依赖动态库"
FRAMEWORKS="$APP/Contents/PlugIns/s-Preview.QuickLook.appex/Contents/Frameworks"
cp "$LIBARC/lib/libarchive.13.dylib" "$FRAMEWORKS/"
cp /opt/homebrew/opt/xz/lib/liblzma.5.dylib "$FRAMEWORKS/"
cp /opt/homebrew/opt/zstd/lib/libzstd.1.dylib "$FRAMEWORKS/"
cp /opt/homebrew/opt/lz4/lib/liblz4.1.dylib "$FRAMEWORKS/"
cp /opt/homebrew/opt/libb2/lib/libb2.1.dylib "$FRAMEWORKS/"
for d in liblzma.5.dylib libzstd.1.dylib liblz4.1.dylib libb2.1.dylib; do
    install_name_tool -change "/opt/homebrew/opt/libarchive/lib/$d" "@rpath/$d" "$FRAMEWORKS/libarchive.13.dylib" 2>/dev/null || true
done
install_name_tool -change "/opt/homebrew/opt/libarchive/lib/liblzma.5.dylib" "@rpath/liblzma.5.dylib" "$FRAMEWORKS/libarchive.13.dylib"
install_name_tool -change "/opt/homebrew/opt/libarchive/lib/libzstd.1.dylib" "@rpath/libzstd.1.dylib" "$FRAMEWORKS/libarchive.13.dylib"
install_name_tool -change "/opt/homebrew/opt/libarchive/lib/liblz4.1.dylib" "@rpath/liblz4.1.dylib" "$FRAMEWORKS/libarchive.13.dylib"
install_name_tool -change "/opt/homebrew/opt/libarchive/lib/libb2.1.dylib" "@rpath/libb2.1.dylib" "$FRAMEWORKS/libarchive.13.dylib"
# 修正扩展二进制对 libarchive 的引用
install_name_tool -change "$LIBARC/lib/libarchive.13.dylib" "@rpath/libarchive.13.dylib" \
    "$APP/Contents/PlugIns/s-Preview.QuickLook.appex/Contents/MacOS/s-Preview.QuickLook"

echo "-- 组装扩展包"
cp Resources/appex-Info.plist "$APP/Contents/PlugIns/s-Preview.QuickLook.appex/Contents/Info.plist"
cp Resources/appex-entitlements.plist "$BUILD/appex-entitlements.plist"
echo "-- 复制预览页面资源与图标"
cp -R "$ROOT/Resources/Viewer/"* "$APP/Contents/PlugIns/s-Preview.QuickLook.appex/Contents/Resources/Viewer/"
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/PlugIns/s-Preview.QuickLook.appex/Contents/Resources/AppIcon.icns"
if [ -f "$ROOT/README.md" ]; then
    cp "$ROOT/README.md" "$APP/Contents/Resources/README.md"
fi
if [ -d "$ROOT/docs/screenshots" ]; then
    mkdir -p "$APP/Contents/PlugIns/s-Preview.QuickLook.appex/Contents/Resources/Viewer/docs/screenshots"
    cp "$ROOT/docs/screenshots/"*.png "$APP/Contents/PlugIns/s-Preview.QuickLook.appex/Contents/Resources/Viewer/docs/screenshots/" 2>/dev/null || true
fi

echo "-- 编译设置应用"
swiftc -O -parse-as-library -module-name SPreviewApp \
    -framework SwiftUI -framework AppKit -framework ImageIO \
    Sources/SPreviewApp/SettingsApp.swift \
    "$KIT/SettingsStore.swift" "$KIT/UTIRouter.swift" "$KIT/Payload.swift" "$KIT/ContentReader.swift" "$KIT/NotebookParser.swift" \
    -o "$APP/Contents/MacOS/s-Preview"
cp Resources/app-Info.plist "$APP/Contents/Info.plist"
plutil -lint "$APP/Contents/Info.plist" "$APP/Contents/PlugIns/s-Preview.QuickLook.appex/Contents/Info.plist"

echo "-- 签名"
for d in liblzma.5.dylib libzstd.1.dylib liblz4.1.dylib libb2.1.dylib libarchive.13.dylib; do
    codesign --force --sign - "$FRAMEWORKS/$d"
done
codesign --force --sign - --entitlements Resources/appex-entitlements.plist \
    "$APP/Contents/PlugIns/s-Preview.QuickLook.appex"
codesign --force --sign - "$APP"
codesign --verify --verbose=1 "$APP"
echo "-- 验证动态库加载"
otool -L "$APP/Contents/PlugIns/s-Preview.QuickLook.appex/Contents/MacOS/s-Preview.QuickLook" | grep -E "archive|rpath" | head -3

echo "-- 构建完成: $APP"
