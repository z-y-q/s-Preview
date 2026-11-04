#!/bin/bash
# 无界面端到端测试：离屏渲染全部样本并断言（不依赖 Quick Look 系统路由）
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"

H="$ROOT/build/tools/previewharness"
if [ ! -x "$H" ]; then
    echo "缺少 previewharness，请先运行 build.sh 并重编译验证器" >&2
    exit 2
fi

FILES=(
    code/demo.py code/main.go code/App.vue code/Button.jsx code/User.kt
    code/Point.dart code/lib.rs code/README code/Podfile code/LICENSE code/Gemfile
    docs/formula.md docs/demo.ipynb
    arch/demo.zip arch/demo.tar arch/demo.tgz arch/demo.7z arch/single.gz
    docs/gradient.webp docs/gradient.avif
    models/cube.glb models/cube.gltf models/cube.obj models/cube.stl
    models/cube.ply models/cube.dae models/cube.fbx models/cube.usdz
)

PASS=0
FAIL=0
declare -a FAILED
for f in "${FILES[@]}"; do
    R=$("$H" "$ROOT/TestSamples/$f" 20 2>/dev/null)
    VERDICT=$(echo "$R" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    r = d.get('reports', {})
    if r.get('model', {}).get('rendered') is True and r['model'].get('meshes', 0) >= 1:
        print('PASS')
    elif r.get('code', {}).get('rendered'):
        print('PASS')
    elif r.get('markdown', {}).get('rendered') and r['markdown'].get('katex', 0) >= 3:
        print('PASS')
    elif r.get('notebook', {}).get('rendered') and r['notebook'].get('images', 0) >= 1:
        print('PASS')
    elif r.get('archive', {}).get('rendered') and r['archive'].get('rows', 0) >= 1:
        print('PASS')
    elif r.get('image', {}).get('loaded'):
        print('PASS')
    else:
        print('FAIL ' + json.dumps(d)[:160])
except Exception as e:
    print('FAIL parse ' + str(e))
")
    if [ "$VERDICT" = "PASS" ]; then
        PASS=$((PASS + 1))
        echo "PASS  $f"
    else
        FAIL=$((FAIL + 1))
        FAILED+=("$f :: $VERDICT")
        echo "FAIL  $f"
    fi
done

echo
echo "通过 $PASS / $((PASS + FAIL))"
if [ "$FAIL" -gt 0 ]; then
    for l in "${FAILED[@]}"; do echo "  $l"; done
    exit 1
fi
echo "ALL PASS"
