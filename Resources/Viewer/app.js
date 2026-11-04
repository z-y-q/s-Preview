/* s-Preview 预览页应用：模块渲染 + 主题 + 3D 交互 + 测试自报告 */
(function () {
    'use strict';
    window.addEventListener('error', function (e) { window.__SP_ERR__ = String(e.message || e); });

    const root = () => document.getElementById('sp-root');

    // ---------- 工具 ----------
    function fmtBytes(n) {
        if (n === null || n === undefined || isNaN(n)) return '—';
        if (n < 1024) return n + ' B';
        const units = ['KB', 'MB', 'GB', 'TB'];
        let v = n / 1024, i = 0;
        while (v >= 1024 && i < units.length - 1) { v /= 1024; i++; }
        return v.toFixed(v >= 100 ? 0 : 1) + ' ' + units[i];
    }
    function fmtDate(sec) {
        if (!sec) return '—';
        const d = new Date(sec * 1000);
        const p = (x) => String(x).padStart(2, '0');
        return d.getFullYear() + '-' + p(d.getMonth() + 1) + '-' + p(d.getDate()) + ' ' + p(d.getHours()) + ':' + p(d.getMinutes());
    }
    function esc(s) {
        return String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
    }
    function el(tag, cls, html) {
        const e = document.createElement(tag);
        if (cls) e.className = cls;
        if (html !== undefined) e.innerHTML = html;
        return e;
    }
    function report(caseName, data) {
        if (!window.__SP_TEST__) return;
        try {
            window.__SP_REPORTS__ = window.__SP_REPORTS__ || {};
            window.__SP_REPORTS__[caseName] = data || {};
            const q = encodeURIComponent(JSON.stringify(data || {}));
            fetch('spreview-resource://page/report?c=' + encodeURIComponent(caseName) + '&d=' + q).catch(() => {});
        } catch (e) { /* 测试报告失败不影响预览 */ }
    }

    // ---------- 主题 ----------
    const HLJS_DARK_PAIR = {
        'github': 'github-dark', 'atom-one-light': 'atom-one-dark',
        'vs': 'vs2015', 'nnfx-light': 'nnfx-dark', 'tokyo-night-light': 'tokyo-night-dark',
        'default': 'dark', 'xcode': 'github-dark', 'atom-one-dark-reasonable': 'atom-one-dark'
    };
    function applyTheme(p) {
        if (p.dark) document.body.classList.add('sp-dark');
        else document.body.classList.remove('sp-dark');
        const s = p.settings;
        let theme = s.codeTheme || 'github';
        if (s.theme === 'dark' || (s.theme === 'auto' && p.dark)) {
            theme = HLJS_DARK_PAIR[theme] || theme;
        }
        const link = document.getElementById('hljs-theme');
        if (link) link.href = 'vendor/hljs-themes/' + theme + '.css';
    }

    // ---------- 工具栏 ----------
    function buildToolbar(p, extra) {
        const bar = el('div', 'sp-toolbar');
        bar.appendChild(el('span', 'sp-title', esc(p.fileName)));
        bar.appendChild(el('span', 'sp-chip', fmtBytes(p.fileSize)));
        if (p.kind) bar.appendChild(el('span', 'sp-chip', esc(p.kind.split('.').pop())));
        bar.appendChild(el('span', 'sp-space'));
        (extra || []).forEach((b) => bar.appendChild(b));
        return bar;
    }
    function toolbarButton(label, onClick, isOn) {
        const b = el('button', 'sp-btn' + (isOn ? ' sp-on' : ''), esc(label));
        b.addEventListener('click', () => { onClick(b); });
        return b;
    }

    // ---------- 代码 ----------
    function renderCode(p) {
        const s = p.settings;
        const lines = (p.text || '').replace(/\r\n/g, '\n').replace(/\r/g, '\n').split('\n');
        if (lines.length > 1 && lines[lines.length - 1] === '') lines.pop();
        let html = null;
        try {
            html = hljs.highlight(p.text || '', { language: p.language || 'plaintext', ignoreIllegals: true }).value;
        } catch (e) {
            html = esc(p.text || '');
        }
        const wrap = el('div', 'sp-code-scroll');
        const inner = el('div', 'sp-code-wrap' + (s.wordWrap ? ' sp-wrap' : ''));
        const gutter = el('div', 'sp-linenum');
        const n = lines.length;
        const g = Array.from({ length: n }, (_, k) => String(k + 1)).join('\n');
        gutter.textContent = g;
        const code = el('pre', 'sp-code');
        code.innerHTML = html;
        code.style.fontSize = s.fontSize + 'px';
        code.style.tabSize = s.tabWidth;
        gutter.style.fontSize = s.fontSize + 'px';
        if (s.lineNumbers !== false) inner.appendChild(gutter);
        inner.appendChild(code);
        wrap.appendChild(inner);

        const content = el('div', 'sp-content');
        content.style.display = 'flex';
        content.style.flexDirection = 'column';
        const bar = buildToolbar(p, [
            toolbarButton(s.wordWrap ? '自动换行 开' : '自动换行 关', (btn) => {
                s.wordWrap = !s.wordWrap;
                inner.classList.toggle('sp-wrap', s.wordWrap);
                btn.textContent = s.wordWrap ? '自动换行 开' : '自动换行 关';
                btn.classList.toggle('sp-on', s.wordWrap);
            }, s.wordWrap),
            toolbarButton('字号 +', () => {
                s.fontSize = Math.min(24, s.fontSize + 1);
                code.style.fontSize = gutter.style.fontSize = s.fontSize + 'px';
            }),
            toolbarButton('字号 −', () => {
                s.fontSize = Math.max(9, s.fontSize - 1);
                code.style.fontSize = gutter.style.fontSize = s.fontSize + 'px';
            })
        ]);
        content.appendChild(bar);
        content.appendChild(wrap);
        if (p.truncated) {
            content.appendChild(el('div', 'sp-truncate-note', '文件过大，仅显示前 ' + fmtBytes((p.text || '').length) + '，其余内容已省略'));
        }
        root().replaceChildren(content);

        if (p.test) {
            const tokens = code.querySelectorAll('.hljs-keyword,.hljs-string,.hljs-comment,.hljs-title,.hljs-number').length;
            const gw = s.lineNumbers === false ? -1 : Math.round(gutter.getBoundingClientRect().width);
            const expected = Math.round(n * s.fontSize * 1.5) + 24;
            const gh = Math.round(gutter.getBoundingClientRect().height);
            const ch = Math.round(code.getBoundingClientRect().height);
            const aligned = s.lineNumbers === false ? true : (Math.abs(gh - expected) <= 2 && Math.abs(ch - expected) <= 2);
            report('code', { lineNumbers: n, tokens: tokens, language: p.language, rendered: true, gutterWidth: gw, gutterHeight: gh, codeHeight: ch, expected: expected, heightsAligned: aligned });
        }
    }

    // ---------- Markdown ----------
    function renderMarkdown(p) {
        const s = p.settings;
        marked.setOptions({ gfm: true, breaks: false, mangle: false, headerIds: false });
        let html = '';
        try { html = marked.parse(p.text || ''); }
        catch (e) { html = '<p>Markdown 解析失败：' + esc(e.message) + '</p>'; }
        const content = el('div', 'sp-content');
        content.appendChild(buildToolbar(p, []));
        const md = el('div', 'sp-md');
        md.innerHTML = html;
        content.appendChild(md);
        root().replaceChildren(content);
        md.querySelectorAll('pre code').forEach((block) => {
            try { hljs.highlightElement(block); } catch (e) { /* 保持原样 */ }
        });
        if (s.markdownMath && window.renderMathInElement) {
            try {
                renderMathInElement(md, {
                    delimiters: [
                        { left: '$$', right: '$$', display: true },
                        { left: '\\[', right: '\\]', display: true },
                        { left: '\\(', right: '\\)', display: false },
                        { left: '$', right: '$', display: false }
                    ],
                    ignoredTags: ['script', 'noscript', 'style', 'textarea', 'pre', 'code'],
                    throwOnError: false
                });
            } catch (e) { /* 公式失败保持原文本 */ }
        }
        if (p.test) {
            const katexCount = md.querySelectorAll('.katex').length;
            const hlCount = md.querySelectorAll('.hljs-keyword,.hljs-string').length;
            const imgs = Array.from(md.querySelectorAll('img'));
            const imgsLoaded = imgs.filter((i2) => i2.complete && i2.naturalWidth > 0).length;
            report('markdown', { katex: katexCount, codeTokens: hlCount, headings: md.querySelectorAll('h1,h2,h3').length, tables: md.querySelectorAll('table').length, imgsTotal: imgs.length, imgsLoaded: imgsLoaded, rendered: true });
            // 图片异步加载完成后更新计数（供文档截图链路验证）
            const bump = () => {
                const rep = window.__SP_REPORTS__ && window.__SP_REPORTS__.markdown;
                if (rep) rep.imgsLoaded = imgs.filter((i2) => i2.complete && i2.naturalWidth > 0).length;
            };
            imgs.forEach((i2) => { i2.addEventListener('load', bump); i2.addEventListener('error', bump); });
        }
    }

    // ---------- Notebook ----------
    function renderNotebook(p) {
        const s = p.settings;
        const content = el('div', 'sp-content');
        content.appendChild(buildToolbar(p, []));
        const body = el('div', 'sp-md');
        (p.cells || []).forEach((cell, idx) => {
            const cellEl = el('div', 'sp-nb-cell');
            const head = el('div', 'sp-nb-head');
            head.appendChild(el('span', '', esc(cell.type)));
            if (cell.language) head.appendChild(el('span', '', esc(cell.language)));
            if (cell.executionCount !== null && cell.executionCount !== undefined) {
                head.appendChild(el('span', 'sp-nb-exec', '[' + cell.executionCount + ']'));
            }
            cellEl.appendChild(head);
            const bodyEl = el('div', 'sp-nb-body');
            if (cell.type === 'markdown' || cell.type === 'raw') {
                let html = '';
                try { html = marked.parse(cell.source); } catch (e) { html = '<pre>' + esc(cell.source) + '</pre>'; }
                bodyEl.innerHTML = html;
                bodyEl.classList.add('sp-md');
                bodyEl.style.padding = '10px 16px';
                bodyEl.querySelectorAll('pre code').forEach((b) => { try { hljs.highlightElement(b); } catch (e) {} });
                if (s.markdownMath && window.renderMathInElement) {
                    try {
                        renderMathInElement(bodyEl, {
                            delimiters: [{ left: '$$', right: '$$', display: true }, { left: '$', right: '$', display: false }],
                            ignoredTags: ['script', 'noscript', 'style', 'textarea', 'pre', 'code'],
                            throwOnError: false
                        });
                    } catch (e) {}
                }
            } else if (cell.type === 'code') {
                const pre = el('pre', 'sp-nb-code');
                let highlighted = null;
                try { highlighted = hljs.highlight(cell.source, { language: cell.language || 'python', ignoreIllegals: true }).value; }
                catch (e) { highlighted = esc(cell.source); }
                pre.innerHTML = highlighted;
                cellEl.appendChild(pre);
                (cell.outputs || []).forEach((out) => {
                    const outEl = el('div', 'sp-nb-out');
                    const outBody = el('div', 'sp-nb-out-body');
                    if (out.kind === 'image') {
                        const img = el('img');
                        img.src = 'data:' + (out.mimeType || 'image/png') + ';base64,' + out.content.trim();
                        outBody.appendChild(img);
                    } else if (out.kind === 'html') {
                        outBody.innerHTML = out.content;
                    } else if (out.kind === 'error') {
                        outBody.classList.add('sp-nb-error');
                        outBody.textContent = out.content;
                    } else {
                        outBody.textContent = out.content;
                    }
                    if (outBody.firstChild) {
                        outEl.appendChild(outBody);
                        cellEl.appendChild(outEl);
                    }
                });
            } else {
                bodyEl.textContent = cell.source;
            }
            if (bodyEl.firstChild && cell.type !== 'code') cellEl.appendChild(bodyEl);
            body.appendChild(cellEl);
        });
        content.appendChild(body);
        root().replaceChildren(content);
        if (p.test) {
            const mdCells = (p.cells || []).filter((c) => c.type === 'markdown').length;
            const codeCells = (p.cells || []).filter((c) => c.type === 'code').length;
            const katexCount = body.querySelectorAll('.katex').length;
            const imgCount = body.querySelectorAll('.sp-nb-out-body img').length;
            report('notebook', { cells: (p.cells || []).length, mdCells: mdCells, codeCells: codeCells, katex: katexCount, images: imgCount, rendered: true });
        }
    }

    // ---------- 压缩包 ----------
    function renderArchive(p) {
        const s = p.settings;
        const a = p.archive || { entries: [] };
        const content = el('div', 'sp-content');
        const chips = [
            el('span', 'sp-chip', (a.format || 'archive')),
            el('span', 'sp-chip', a.fileCount + ' 个文件 / ' + a.dirCount + ' 个目录'),
            el('span', 'sp-chip', '合计 ' + fmtBytes(a.totalSize)),
        ];
        if (a.totalCompressed > 0) chips.push(el('span', 'sp-chip', '压缩后 ' + fmtBytes(a.totalCompressed)));
        if (a.truncated) chips.push(el('span', 'sp-chip', '条目过多，仅显示前 ' + (a.entries || []).length + ' 项'));
        const bar = el('div', 'sp-toolbar');
        bar.appendChild(el('span', 'sp-title', esc(p.fileName)));
        bar.appendChild(el('span', 'sp-chip', fmtBytes(p.fileSize)));
        chips.forEach((c) => bar.appendChild(c));
        bar.appendChild(el('span', 'sp-space'));
        content.appendChild(bar);

        const wrap = el('div', 'sp-archive');
        const table = el('table');
        const thead = el('thead');
        const hr = el('tr');
        hr.appendChild(el('th', '', '名称'));
        hr.appendChild(el('th', 'num', '大小'));
        if (s.archiveShowCompressed) hr.appendChild(el('th', 'num', '压缩后'));
        if (s.archiveShowDate) hr.appendChild(el('th', '', '修改时间'));
        if (s.archiveShowPermissions) hr.appendChild(el('th', '', '权限'));
        thead.appendChild(hr);
        table.appendChild(thead);
        const tbody = el('tbody');
        (a.entries || []).forEach((e) => {
            const tr = el('tr', e.isDirectory ? 'sp-dir-row' : '');
            const depth = (e.path.match(/\//g) || []).length;
            const indent = '&nbsp;&nbsp;&nbsp;'.repeat(depth);
            const icon = e.isDirectory ? '<span class="sp-dir-icon">▸</span> ' : '';
            const base = e.path.split('/').pop() || e.path;
            const pathTd = el('td', 'sp-path', indent + icon + esc(e.isDirectory ? base + '/' : base));
            if (e.isEncrypted) pathTd.innerHTML += ' <span title="加密">🔒</span>';
            tr.appendChild(pathTd);
            if (!e.isDirectory) tr.appendChild(el('td', 'num', fmtBytes(e.size)));
            else tr.appendChild(el('td', 'num', '—'));
            if (s.archiveShowCompressed) tr.appendChild(el('td', 'num', e.isDirectory ? '—' : fmtBytes(e.compressedSize)));
            if (s.archiveShowDate) tr.appendChild(el('td', '', fmtDate(e.mtime)));
            if (s.archiveShowPermissions) tr.appendChild(el('td', '', ''));
            tbody.appendChild(tr);
        });
        table.appendChild(tbody);
        wrap.appendChild(table);
        content.appendChild(wrap);
        root().replaceChildren(content);

        if (p.test) {
            report('archive', { rows: (a.entries || []).length, files: a.fileCount, dirs: a.dirCount, format: a.format, total: a.totalSize, rendered: true });
        }
    }

    // ---------- 图片 ----------
    function renderImage(p) {
        const content = el('div', 'sp-image');
        content.appendChild(buildToolbar(p, []));
        const body = el('div', 'sp-image-body');
        const img = el('img');
        img.src = 'spreview-resource://file';
        img.alt = p.fileName;
        body.appendChild(img);
        content.appendChild(body);
        const info = el('div', 'sp-image-info');
        info.appendChild(el('span', '', '尺寸 <b>' + (p.imageWidth || '?') + ' × ' + (p.imageHeight || '?') + '</b>'));
        info.appendChild(el('span', '', '格式 <b>' + esc((p.imageFormat || '').toUpperCase()) + '</b>'));
        info.appendChild(el('span', '', '文件 <b>' + fmtBytes(p.fileSize) + '</b>'));
        if (p.imageDepth) info.appendChild(el('span', '', '位深 <b>' + p.imageDepth + 'bit</b>'));
        if (p.imageDPI) info.appendChild(el('span', '', 'DPI <b>' + Math.round(p.imageDPI) + '</b>'));
        if (p.imageAnimated) info.appendChild(el('span', '', '<b>动图</b>'));
        if (p.imageWidth && p.imageHeight) {
            const mp = (p.imageWidth * p.imageHeight) / 1e6;
            if (mp >= 0.1) info.appendChild(el('span', '', '像素 <b>' + mp.toFixed(1) + 'MP</b>'));
        }
        content.appendChild(info);
        root().replaceChildren(content);
        img.onload = () => {
            if (p.test) report('image', { naturalWidth: img.naturalWidth, naturalHeight: img.naturalHeight, loaded: true, infoStrip: true });
        };
        img.onerror = () => {
            body.textContent = '图片解码失败';
            if (p.test) report('image', { loaded: false });
        };
    }

    // ---------- 3D 模型 ----------
    function renderModel(p) {
        const s = p.settings;
        const content = el('div', 'sp-3d');
        const bar = buildToolbar(p, []);
        content.appendChild(bar);
        const holder = el('div');
        holder.style.flex = '1 1 auto';
        holder.style.position = 'relative';
        content.appendChild(holder);
        root().replaceChildren(content);

        const H = window.SPreview3D;
        if (!H || !H.THREE) {
            holder.appendChild(el('div', 'sp-3d-error', '3D 引擎加载失败'));
            return;
        }
        const infoBox = el('div', 'sp-3d-info', '加载中…');
        holder.appendChild(infoBox);
        const ctlWrap = el('div', 'sp-3d-controls');
        holder.appendChild(ctlWrap);

        const state = {
            wireframe: s.modelWireframe, bbox: s.modelBBox, skeleton: s.modelSkeleton,
            grid: s.modelGrid, axes: s.modelAxes, rotate: s.modelAutoRotate, playing: true,
            points: false
        };
        function syncButtons() {
            ctlWrap.querySelectorAll('.sp-btn').forEach((b) => {
                const t = b.textContent;
                ['线框', '点云', '包围盒', '骨架', '网格', '坐标轴', '旋转'].forEach((label) => {
                    if (t.indexOf(label) === 0) {
                        const key = { '线框': 'wireframe', '点云': 'points', '包围盒': 'bbox', '骨架': 'skeleton', '网格': 'grid', '坐标轴': 'axes', '旋转': 'rotate' }[label];
                        b.classList.toggle('sp-on', !!state[key]);
                        b.textContent = label + (state[key] ? ' 开' : ' 关');
                    }
                });
            });
        }
        const V = window.SPreviewViewer3D && window.SPreviewViewer3D.open({
            container: holder,
            resourceURL: 'spreview-resource://page/file',
            format: (p.modelFormat || '').toLowerCase(),
            dark: p.dark,
            backgroundMode: s.modelBackground,
            grid: state.grid, axes: state.axes, wireframe: state.wireframe,
            bbox: state.bbox, skeleton: state.skeleton, autoRotate: state.rotate,
            onStats: (stats) => {
                infoBox.innerHTML =
                    '<b>' + esc(p.fileName) + '</b><br>' +
                    '网格 ' + stats.meshes + ' · 顶点 ' + stats.vertices.toLocaleString() +
                    ' · 三角面 ' + stats.triangles.toLocaleString() + '<br>' +
                    '材质 ' + stats.materials + ' · 动画 ' + stats.animations +
                    (stats.renderer ? '<br>' + esc(stats.renderer) : '');
                if (p.test) {
                    report('model', Object.assign({ rendered: true, renderer: stats.renderer }, stats));
                }
            },
            onError: (msg) => {
                holder.innerHTML = '';
                holder.appendChild(el('div', 'sp-3d-error', '无法渲染模型<br>' + esc(msg)));
                if (p.test) report('model', { rendered: false, error: msg });
            }
        });
        if (!V) return;

        const mk = (label, key, apply) => {
            const b = toolbarButton(label + (state[key] ? ' 开' : ' 关'), (btn) => {
                state[key] = !state[key];
                apply(state[key]);
                btn.textContent = label + (state[key] ? ' 开' : ' 关');
                btn.classList.toggle('sp-on', state[key]);
            }, state[key]);
            ctlWrap.appendChild(b);
            return b;
        };
        mk('线框', 'wireframe', (v) => { if (v) { state.points = false; V.setPoints(false); syncBtns(); } V.setWireframe(v); });
        mk('点云', 'points', (v) => { if (v) { state.wireframe = false; V.setWireframe(false); syncBtns(); } V.setPoints(v); });
        mk('包围盒', 'bbox', (v) => V.setBBox(v));
        mk('骨架', 'skeleton', (v) => V.setSkeleton(v));
        mk('网格', 'grid', (v) => V.setGrid(v));
        mk('坐标轴', 'axes', (v) => V.setAxes(v));
        mk('旋转', 'rotate', (v) => V.setAutoRotate(v));
        const animBtn = toolbarButton('动画 暂停', () => {
            state.playing = !state.playing;
            V.setPlay(state.playing);
            animBtn.textContent = state.playing ? '动画 暂停' : '动画 播放';
        }, true);
        if (V.hasAnimations && !V.hasAnimations()) { animBtn.disabled = true; animBtn.style.opacity = 0.4; }
        ctlWrap.appendChild(animBtn);
        syncButtons();
    }

    // ---------- 文件信息 + 十六进制 ----------
    function renderInfo(p) {
        const content = el('div', 'sp-content');
        const chips = [
            el('span', 'sp-chip', '二进制 / 未识别格式'),
            el('span', 'sp-chip', fmtBytes(p.fileSize)),
        ];
        const bar = el('div', 'sp-toolbar');
        bar.appendChild(el('span', 'sp-title', esc(p.fileName)));
        chips.forEach((x) => bar.appendChild(x));
        bar.appendChild(el('span', 'sp-space'));
        content.appendChild(bar);

        const meta = el('div', 'sp-info-grid');
        const rows = [
            ['文件名', p.fileName],
            ['大小', fmtBytes(p.fileSize)],
            ['UTI 类型', p.kind],
        ];
        rows.forEach(([k, v]) => {
            meta.appendChild(el('div', 'sp-info-k', esc(k)));
            meta.appendChild(el('div', 'sp-info-v', esc(v)));
        });
        content.appendChild(meta);

        const dump = el('pre', 'sp-hexdump');
        dump.textContent = p.text || '';
        dump.style.fontSize = Math.max(10, p.settings.fontSize - 1) + 'px';
        const scroll = el('div', 'sp-content');
        scroll.style.flex = '1 1 auto';
        scroll.appendChild(dump);
        content.appendChild(scroll);
        root().replaceChildren(content);

        if (p.test) {
            report('info', { rendered: true, dumpLines: (p.text || '').split('\n').length });
        }
    }

    // ---------- 入口 ----------
    function render(p) {
        window.__SP_TEST__ = !!p.test;
        try {
            applyTheme(p);
            switch (p.module) {
                case 'code': return renderCode(p);
                case 'markdown': return renderMarkdown(p);
                case 'notebook': return renderNotebook(p);
                case 'archive': return renderArchive(p);
                case 'image': return renderImage(p);
                case 'model': return renderModel(p);
                case 'info': return renderInfo(p);
                default: return renderCode(p);
            }
        } catch (e) {
            const r = root();
            r.replaceChildren();
            const panel = el('div', 'sp-error-panel');
            panel.appendChild(el('div', 'sp-err-title', '预览生成失败'));
            panel.appendChild(el('div', '', esc(e && e.message ? e.message : String(e))));
            r.appendChild(panel);
            report('error', { message: e && e.message });
        }
    }

    window.SPreview = { render: render };
})();
