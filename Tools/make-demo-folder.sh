#!/bin/bash
# 生成「预览演示」文件夹：每个可预览类别一份样本，供人工空格键检查
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"
DEMO="$ROOT/预览演示"

# 先确保样本齐全
./Tools/make-samples.sh >/dev/null 2>&1

rm -rf "$DEMO"
mkdir -p "$DEMO/代码" "$DEMO/文档" "$DEMO/压缩包" "$DEMO/图片" "$DEMO/三维模型"

cp TestSamples/code/demo.py TestSamples/code/main.go TestSamples/code/App.vue \
   TestSamples/code/Button.jsx TestSamples/code/User.kt TestSamples/code/Point.dart \
   TestSamples/code/lib.rs TestSamples/code/README TestSamples/code/Podfile \
   TestSamples/code/LICENSE TestSamples/code/Gemfile "$DEMO/代码/"
cp TestSamples/docs/formula.md TestSamples/docs/demo.ipynb "$DEMO/文档/"
cp TestSamples/arch/demo.zip TestSamples/arch/demo.tar TestSamples/arch/demo.tgz \
   TestSamples/arch/demo.7z TestSamples/arch/single.gz "$DEMO/压缩包/"
cp TestSamples/docs/gradient.webp TestSamples/docs/gradient.avif "$DEMO/图片/"
cp TestSamples/models/cube.glb TestSamples/models/cube.gltf TestSamples/models/cube.obj \
   TestSamples/models/cube.stl TestSamples/models/cube.ply TestSamples/models/cube.dae \
   TestSamples/models/cube.fbx TestSamples/models/cube.usdz "$DEMO/三维模型/"

cat > "$DEMO/说明.md" <<'EOF'
# 预览演示

对下面每个文件按**空格键**，查看 s-Preview 的实际效果。再按一次空格或按 Esc 关闭。

## 代码/ —— 语法高亮 + 行号

| 文件 | 看什么 |
| --- | --- |
| `demo.py` | Python 高亮、行号 |
| `main.go` | Go 高亮 |
| `App.vue` | Vue 单文件组件 |
| `Button.jsx` | JSX |
| `User.kt` | Kotlin |
| `Point.dart` | Dart |
| `lib.rs` | Rust |
| `README` `Podfile` `LICENSE` `Gemfile` | 无扩展名特殊文件也能高亮 |

工具栏可以切**自动换行**、调**字号**。

## 文档/ —— 数学公式与笔记本

- `formula.md`：行内公式 $e^{i\pi}+1=0$ 与独立块公式
- `demo.ipynb`：Markdown 单元、代码单元、文本输出、PNG 图表输出、错误堆栈

## 压缩包/ —— 内容清单

`demo.zip` `demo.tar` `demo.tgz` `demo.7z` `single.gz`：文件名、大小、压缩后大小、修改时间、目录缩进。
加密压缩包（🔒 标记）和 `.rar` 可以用你自己的文件测试。

## 图片/ —— 尺寸信息条

`gradient.webp` `gradient.avif`：尺寸、格式、位深、DPI、像素量。

## 三维模型/ —— 交互渲染

`cube.glb` `cube.gltf` `cube.obj` `cube.stl` `cube.ply` `cube.dae` `cube.fbx` `cube.usdz`：

- **拖动旋转、滚轮缩放**
- 右上角按钮：实心/线框/点云、包围盒、骨架、网格地面、坐标轴、自动旋转
- 底部统计：网格数、顶点数、三角面数、材质数、渲染器

## 设置

打开「s-Preview」应用可切换高亮主题、字号、暗色模式、3D 默认选项，保存后新预览立即生效。
EOF

open "$DEMO"
echo "演示文件夹已生成并在 Finder 中打开: $DEMO"
find "$DEMO" -type f | wc -l | tr -d ' ' | xargs -I{} echo "共 {} 个文件"
