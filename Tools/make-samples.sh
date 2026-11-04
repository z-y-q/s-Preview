#!/bin/bash
# 生成全部测试样本
set -euo pipefail
cd "$(dirname "$0")/.."
S=TestSamples
rm -rf "$S/code" "$S/docs" "$S/models"
mkdir -p "$S/code" "$S/docs" "$S/models" "$S/arch"

# ---------- 源代码样本 ----------
cat > "$S/code/demo.py" <<'EOF'
#!/usr/bin/env python3
"""快速排序示例"""
from typing import List


def quick_sort(items: List[int]) -> List[int]:
    if len(items) <= 1:
        return items
    pivot = items[len(items) // 2]
    left = [x for x in items if x < pivot]
    mid = [x for x in items if x == pivot]
    right = [x for x in items if x > pivot]
    return quick_sort(left) + mid + quick_sort(right)


if __name__ == "__main__":
    data = [3, 6, 1, 8, 2, 9, 4]
    print(quick_sort(data))  # [1, 2, 3, 4, 6, 8, 9]
EOF

cat > "$S/code/main.go" <<'EOF'
package main

import (
	"fmt"
	"strings"
)

// 单词倒序输出
func reverseWords(s string) string {
	words := strings.Fields(s)
	for i, j := 0, len(words)-1; i < j; i, j = i+1, j-1 {
		words[i], words[j] = words[j], words[i]
	}
	return strings.Join(words, " ")
}

func main() {
	fmt.Println(reverseWords("hello quick look world"))
}
EOF

cat > "$S/code/App.vue" <<'EOF'
<template>
  <div class="counter">
    <button @click="dec">-</button>
    <span>{{ count }}</span>
    <button @click="inc">+</button>
  </div>
</template>

<script setup>
import { ref } from 'vue'

const count = ref(0)
const inc = () => count.value++
const dec = () => count.value--
</script>

<style scoped>
.counter { display: flex; gap: 8px; font-size: 20px; }
</style>
EOF

cat > "$S/code/Button.jsx" <<'EOF'
import React, { useState } from 'react';

export default function Button({ label = 'click' }) {
  const [n, setN] = useState(0);
  return (
    <button className="btn" onClick={() => setN(n + 1)}>
      {label} × {n}
    </button>
  );
}
EOF

cat > "$S/code/User.kt" <<'EOF'
data class User(val id: Int, val name: String, val tags: List<String> = emptyList())

fun main() {
    val users = listOf(User(1, "Alice", listOf("admin")), User(2, "Bob"))
    users.filter { "admin" in it.tags }
        .forEach { println("${it.id}: ${it.name}") }
}
EOF

cat > "$S/code/Point.dart" <<'EOF'
class Point {
  final double x;
  final double y;

  Point(this.x, this.y);

  double distanceTo(Point other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return dx * dx + dy * dy;
  }

  @override
  String toString() => 'Point($x, $y)';
}

void main() {
  print(Point(1, 2).distanceTo(Point(4, 6)));
}
EOF

cat > "$S/code/lib.rs" <<'EOF'
use std::collections::HashMap;

/// 统计词频
fn word_count(text: &str) -> HashMap<&str, usize> {
    let mut map = HashMap::new();
    for word in text.split_whitespace() {
        *map.entry(word).or_insert(0) += 1;
    }
    map
}

fn main() {
    let counts = word_count("the quick brown fox the lazy dog");
    println!("{:?}", counts);
}
EOF

cat > "$S/code/README" <<'EOF'
s-Preview
一个让 macOS Quick Look 支持更多文件格式的预览插件。

特性：
- 源代码语法高亮与行号
- Markdown 与 Jupyter 渲染
- 压缩包内容清单
- webp/avif 图片信息
- 三维模型交互预览
EOF

cat > "$S/code/Podfile" <<'EOF'
platform :ios, '15.0'
use_frameworks!

target 'MyApp' do
  pod 'Alamofire', '~> 5.8'
  pod 'SnapKit', '~> 5.9'
  pod 'Kingfisher', '~> 7.0'
end
EOF

cat > "$S/code/LICENSE" <<'EOF'
MIT License

Copyright (c) 2026 s-Preview contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction.
EOF

cat > "$S/code/Gemfile" <<'EOF'
source 'https://rubygems.org'

gem 'rails', '~> 7.1'
gem 'pg', '~> 1.5'
gem 'puma', '~> 6.4'
EOF

# ---------- 文档样本 ----------
cat > "$S/docs/formula.md" <<'EOF'
# 数学公式排版演示

欧拉恒等式（行内）：$e^{i\pi} + 1 = 0$

质能方程（独立块）：

$$
E = mc^2
$$

高斯分布：

$$
f(x) = \frac{1}{\sigma\sqrt{2\pi}} e^{-\frac{1}{2}\left(\frac{x-\mu}{\sigma}\right)^2}
$$

## 代码块

```python
def fib(n):
    a, b = 0, 1
    for _ in range(n):
        a, b = b, a + b
    return a
```

## 表格

| 项 | 值 |
| --- | --- |
| $\pi$ | 3.14159 |
| $e$ | 2.71828 |
EOF

python3 - <<'PYEOF'
import base64, json
# 1x1 红色 PNG
png = base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==')
nb = {
  "cells": [
    {"cell_type": "markdown", "metadata": {}, "source": ["# 演示笔记本\n", "\n", "内联公式 $\\sum_{i=1}^n i = \\frac{n(n+1)}{2}$"]},
    {"cell_type": "code", "execution_count": 1, "metadata": {}, "outputs": [],
     "source": ["import numpy as np\n", "np.arange(6)"]},
    {"cell_type": "code", "execution_count": 2, "metadata": {}, "outputs": [
        {"output_type": "stream", "name": "stdout", "text": ["hello notebook\n"]}
    ], "source": ["print('hello notebook')"]},
    {"cell_type": "code", "execution_count": 3, "metadata": {}, "outputs": [
        {"output_type": "display_data", "data": {"image/png": base64.b64encode(png).decode(), "text/plain": ["<Figure>"]}, "metadata": {}}
    ], "source": ["import matplotlib.pyplot as plt"]},
    {"cell_type": "code", "execution_count": 4, "metadata": {}, "outputs": [
        {"output_type": "error", "ename": "ValueError", "evalue": "bad value", "traceback": ["Traceback (most recent call last):\n", "ValueError: bad value"]}
    ], "source": ["raise ValueError('bad value')"]}
  ],
  "metadata": {"language_info": {"name": "python"}},
  "nbformat": 4,
  "nbformat_minor": 5
}
with open('TestSamples/docs/demo.ipynb', 'w') as f:
    json.dump(nb, f, ensure_ascii=False, indent=1)
print('notebook written')
PYEOF

# ---------- 图片样本 ----------
cat > "$S/docs/gradient.png.src" <<'EOF'
EOF
rm -f "$S/docs/gradient.png.src"
python3 - <<'PYEOF'
import struct, zlib
w, h = 120, 90
rows = b''
for y in range(h):
    rows += b'\x00'
    for x in range(w):
        rows += bytes([x * 2 % 256, y * 2 % 256, 180])
def chunk(t, d):
    c = struct.pack('>I', len(d)) + t + d
    return c + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
png = b'\x89PNG\r\n\x1a\n'
png += chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0))
png += chunk(b'IDAT', zlib.compress(rows))
png += chunk(b'IEND', b'')
open('TestSamples/docs/gradient.png', 'wb').write(png)
print('png written')
PYEOF
python3 Tools/make-3d-samples.py
CWEPB=$(command -v cwebp || echo /opt/homebrew/bin/cwebp)
"$CWEPB" -quiet TestSamples/docs/gradient.png -o TestSamples/docs/gradient.webp && echo WEBP_OK || echo WEBP_FAIL
sips -s format avif TestSamples/docs/gradient.png --out TestSamples/docs/gradient.avif >/dev/null 2>&1 && echo AVIF_OK || echo AVIF_FAIL

echo "-- 样本生成完成"
ls "$S/code" "$S/docs"
