#!/bin/bash
# 构建 TestHost.app 与像素分析工具
set -euo pipefail
cd "$(dirname "$0")"
ROOT="$PWD"
BUILD="$ROOT/build/TestHost"
rm -rf "$BUILD"
mkdir -p "$BUILD/TestHost.app/Contents/MacOS"

swiftc -O -module-name TestHost -target arm64-apple-macos12.0 \
    -framework AppKit -framework Quartz \
    TestHost/TestHostMain.swift \
    -o "$BUILD/TestHost.app/Contents/MacOS/TestHost"

cat > "$BUILD/TestHost.app/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.spreview.testhost</string>
    <key>CFBundleName</key>
    <string>TestHost</string>
    <key>CFBundleExecutable</key>
    <string>TestHost</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF
codesign --force --sign - "$BUILD/TestHost.app"

swiftc -O -o "$ROOT/build/pixanalyze" Tools/pixanalyze.swift
echo "-- TestHost 构建完成: $BUILD/TestHost.app"
