#!/bin/bash
# s-Preview 安装脚本：构建、安装、注册（含声明刷新）
set -euo pipefail
cd "$(dirname "$0")"

echo "-- 构建"
./build.sh

echo "-- 结束正在运行的旧设置应用"
pkill -f "s-Preview.app/Contents/MacOS/s-Preview" 2>/dev/null || true
sleep 1

echo "-- 安装到 /Applications"
rm -rf /Applications/s-Preview.app
cp -R build/s-Preview/s-Preview.app /Applications/s-Preview.app

LS=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
"$LS" -f /Applications/s-Preview.app

echo "-- 注册预览扩展"
pluginkit -r /Applications/s-Preview.app/Contents/PlugIns/s-Preview.QuickLook.appex 2>/dev/null || true
sleep 1
pluginkit -a /Applications/s-Preview.app/Contents/PlugIns/s-Preview.QuickLook.appex
sleep 2

if pluginkit -m -p com.apple.quicklook.preview 2>/dev/null | grep -q "com.spreview.s-preview.QuickLook"; then
    echo "-- 注册成功"
else
    echo "-- 警告：扩展尚未出现在注册表，注销重登或重启后会自动生效" >&2
fi

echo "-- 完成。打开「s-Preview」可调整主题与选项；按空格即可预览支持的文件。"
