#!/bin/bash
# 被动观察器：记录自检日志变化与扩展进程出现（不弹任何窗口）
LOG="$HOME/Library/Containers/com.spreview.s-preview.QuickLook/Data/Library/Application Support/selftest.log"
OUT="$PWD/TestResults/watcher.log"
echo "watcher start $(date '+%H:%M:%S')" >> "$OUT"
END=$((SECONDS + 600))
while [ $SECONDS -lt $END ]; do
    P=$(ps aux | grep -i 's-Preview.QuickLook' | grep -v grep | wc -l | tr -d ' ')
    if [ "$P" != "0" ] && [ ! -f "$OUT.done" ]; then
        echo "EXT_PROC_ALIVE $(date '+%H:%M:%S')" >> "$OUT"
    fi
    if [ -f "$LOG" ] && ! diff -q "$LOG" "$OUT.logsnap" >/dev/null 2>&1; then
        cp "$LOG" "$OUT.logsnap" 2>/dev/null
        echo "LOG_CHANGED $(date '+%H:%M:%S')" >> "$OUT"
        tail -5 "$LOG" >> "$OUT"
    fi
    sleep 2
done
echo "watcher end $(date '+%H:%M:%S')" >> "$OUT"
