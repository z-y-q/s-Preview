/* s-Preview 预览页应用：模块渲染 + 主题 + 3D 交互 + 测试自报告 */
(function () {
    'use strict';
    window.addEventListener('error', function (e) { window.__SP_ERR__ = String(e.message || e); window.__SP_STACK__ = String((e.error && e.error.stack) || ''); });

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

    // ---------- 压缩包：目录树 + 选择性解压 ----------
    const A = window.__SP_ARCHIVE__ = window.__SP_ARCHIVE__ || {
        entries: [], folders: new Map(), filesAt: new Map(), totalsCache: new Map(),
        current: '', selection: new Set(), expanded: new Set(['']), name: '', total: 0
    };

    function renderArchive(p) {
        A.name = p.fileName;
        A.total = p.fileSize;
        renderArchiveShell();
        renderTree();
        renderBreadcrumb();
        if (window.__SP_TEST__) {
            report('archive', { rows: A.entries.length, rendered: A.entries.length > 0, pending: A.entries.length === 0 });
        }
    }

    function openFolder(path) {
        A.current = path;
        renderBreadcrumb();
        renderFileList();
        renderTree();
    }

    function archiveInit() {
        fetch('spreview-resource://page/archive.tsv').then((r) => r.text()).then((t) => {
            A.entries = [];
            const lines = t.split('\n');
            for (const line of lines) {
                if (!line) continue;
                const c = line.split('\t');
                if (c.length < 5) continue;
                let p0 = c[0];
                while (p0.length > 1 && p0.endsWith('/')) p0 = p0.slice(0, -1);
                A.entries.push({ p: p0, s: Number(c[1]), cs: Number(c[2]), m: Number(c[3]), f: c[4] });
            }
            buildArchiveTree();
            renderArchiveShell();
            renderTree();
            renderBreadcrumb();
            renderFileList();
            updateArchiveFooter();
            if (window.__SP_TEST__) {
                report('archive', { rows: A.entries.length, rendered: true, treeFolders: A.folders.size });
            }
        }).catch((e) => {
            root().replaceChildren();
            const panel = el('div', 'sp-error-panel');
            panel.appendChild(el('div', 'sp-err-title', '清单加载失败'));
            panel.appendChild(el('div', '', esc(e)));
            root().appendChild(panel);
        });
    }

    function archiveError(msg) {
        root().replaceChildren();
        const panel = el('div', 'sp-error-panel');
        panel.appendChild(el('div', 'sp-err-title', '压缩包解析失败'));
        panel.appendChild(el('div', '', esc(msg)));
        root().appendChild(panel);
    }

    function parentPath(p) {
        const i = p.lastIndexOf('/');
        return i < 0 ? '' : p.slice(0, i);
    }

    function buildArchiveTree() {
        A.folders = new Map();
        A.filesAt = new Map();
        A.totalsCache = new Map();
        A.folders.set('', { sub: new Map(), files: [] });
        for (const e of A.entries) {
            const isDir = e.f.indexOf('d') >= 0;
            const comps = e.p.split('/');
            let cur = '';
            for (let i = 0; i < comps.length - (isDir ? 1 : 0); i++) {
                const next = i === 0 ? comps[0] : cur + '/' + comps[i];
                if (!A.folders.has(next)) A.folders.set(next, { sub: new Map(), files: [] });
                if (cur !== '') {
                    A.folders.get(cur).sub.set(comps[i], next);
                }
                cur = next;
            }
            if (isDir) {
                if (!A.folders.has(e.p)) A.folders.set(e.p, { sub: new Map(), files: [] });
                const pp = parentPath(e.p);
                if (A.folders.has(pp)) A.folders.get(pp).sub.set(comps[comps.length - 1], e.p);
            } else {
                if (!A.folders.has(cur)) A.folders.set(cur, { sub: new Map(), files: [] });
                A.folders.get(cur).files.push(e);
            }
        }
        // 子树合计（延迟计算 + 缓存）
        A.totals = (path) => {
            if (A.totalsCache.has(path)) return A.totalsCache.get(path);
            const f = A.folders.get(path) || { sub: new Map(), files: [] };
            let count = f.files.length;
            let size = 0;
            for (const fe of f.files) size += fe.s;
            f.sub.forEach((child) => {
                const t = A.totals(child);
                count += t.count;
                size += t.size;
            });
            const t = { count, size };
            A.totalsCache.set(path, t);
            return t;
        };
    }

    function renderArchiveShell() {
        if (A.entries.length === 0) {
            root().replaceChildren();
            const panel = el('div', 'sp-loading', '正在解析压缩包清单…');
            root().appendChild(panel);
            return;
        }
        const content = el('div', 'sp-content sp-arch-content');
        const bar = el('div', 'sp-toolbar');
        bar.appendChild(el('span', 'sp-title', esc(A.name)));
        bar.appendChild(el('span', 'sp-chip', fmtBytes(A.total)));
        bar.appendChild(el('span', 'sp-space'));
        const up = toolbarButton('上级', () => {
            if (A.current !== '') {
                A.current = parentPath(A.current);
                renderBreadcrumb();
                renderFileList();
            }
        });
        bar.appendChild(up);
        const selAll = toolbarButton('全选当前', () => {
            selectAllIn(A.current, true);
            renderFileList();
            updateArchiveFooter();
        });
        bar.appendChild(selAll);
        const none = toolbarButton('取消选择', () => {
            A.selection.clear();
            renderTree();
            renderFileList();
            updateArchiveFooter();
        });
        bar.appendChild(none);
        content.appendChild(bar);

        const crumb = el('div', 'sp-crumbs');
        content.appendChild(crumb);

        const body = el('div', 'sp-arch-body');
        const tree = el('div', 'sp-arch-tree');
        body.appendChild(tree);
        const list = el('div', 'sp-arch-list');
        body.appendChild(list);
        content.appendChild(body);

        const footer = el('div', 'sp-arch-footer');
        const status = el('span', '', '');
        footer.appendChild(status);
        footer.appendChild(el('span', 'sp-space'));
        const btn = toolbarButton('解压所选…', () => extractSelected(), false);
        btn.classList.add('sp-extract-btn');
        footer.appendChild(btn);
        content.appendChild(footer);
        root().replaceChildren(content);
        A.statusEl = status;
        A.crumbEl = crumb;
        updateArchiveFooter('已就绪：' + A.entries.length + ' 个条目');
    }

    function renderTree() {
        const tree = root().querySelector('.sp-arch-tree');
        if (!tree) return;
        tree.replaceChildren();
        const rootNode = el('div', 'sp-tree-node sp-root-node');
        const label = el('span', 'sp-tree-label', esc(A.name || '根目录'));
        const t = A.totals('');
        label.title = t.count + ' 个文件';
        rootNode.appendChild(label);
        rootNode.addEventListener('click', () => {
            A.current = '';
            renderBreadcrumb();
            renderFileList();
        });
        tree.appendChild(rootNode);
        tree.appendChild(renderTreeChildren('', 1));
    }

    function renderTreeChildren(path, depth) {
        const wrap = el('div');
        const f = A.folders.get(path);
        if (!f) return wrap;
        const subs = Array.from(f.sub.keys()).sort();
        for (const sub of subs) {
            const childPath = path === '' ? sub : path + '/' + sub;
            const childFolder = A.folders.get(childPath);
            if (!childFolder) continue;
            const node = el('div', 'sp-tree-node');
            node.style.paddingLeft = (depth * 16 + 8) + 'px';
            const expanded = A.expanded.has(childPath);
            const arrow = el('span', 'sp-tree-arrow', childFolder.sub.size > 0 ? (expanded ? '▾' : '▸') : '');
            const label = el('span', 'sp-tree-label', esc(sub) + '/');
            node.appendChild(arrow);
            node.appendChild(label);
            const t = A.totals(childPath);
            const badge = el('span', 'sp-tree-badge', String(t.count));
            badge.title = '子树共 ' + t.count + ' 个文件';
            node.appendChild(badge);
            if (A.selection.has(childPath)) node.classList.add('sp-selected');
            node.addEventListener('click', (ev) => {
                if (ev.target === arrow) {
                    if (expanded) A.expanded.delete(childPath);
                    else A.expanded.add(childPath);
                    renderTree();
                    return;
                }
                A.current = childPath;
                A.expanded.add(childPath);
                renderBreadcrumb();
                renderFileList();
                renderTree();
            });
            wrap.appendChild(node);
            if (expanded) {
                wrap.appendChild(renderTreeChildren(childPath, depth + 1));
            }
        }
        return wrap;
    }

    function renderBreadcrumb() {
        const crumb = A.crumbEl;
        if (!crumb) return;
        crumb.replaceChildren();
        const segs = A.current === '' ? [] : A.current.split('/');
        const home = el('span', 'sp-crumb-item', esc(A.name || '根目录'));
        home.addEventListener('click', () => {
            A.current = '';
            renderBreadcrumb();
            renderFileList();
        });
        crumb.appendChild(home);
        let acc = '';
        for (const s of segs) {
            acc = acc === '' ? s : acc + '/' + s;
            crumb.appendChild(el('span', 'sp-crumb-sep', '›'));
            const item = el('span', 'sp-crumb-item' + (acc === A.current ? ' sp-crumb-cur' : ''), esc(s));
            const path = acc;
            item.addEventListener('click', () => {
                A.current = path;
                renderBreadcrumb();
                renderFileList();
            });
            crumb.appendChild(item);
        }
    }

    function childrenOf(path) {
        const f = A.folders.get(path) || { sub: new Map(), files: [] };
        const out = [];
        const subs = Array.from(f.sub.keys()).sort();
        for (const s of subs) {
            out.push({ isDir: true, name: s, path: path === '' ? s : path + '/' + s });
        }
        const files = f.files.slice().sort((a, b) => a.p.localeCompare(b.p));
        for (const fe of files) {
            out.push({ isDir: false, name: fe.p.split('/').pop(), entry: fe });
        }
        return out;
    }

    function renderFileList() {
        const list = root().querySelector('.sp-arch-list');
        if (!list) return;
        list.replaceChildren();
        const table = el('table');
        const thead = el('thead');
        const hr = el('tr');
        hr.appendChild(el('th', 'sp-col-check', ''));
        hr.appendChild(el('th', '', '名称'));
        hr.appendChild(el('th', 'num', '大小'));
        hr.appendChild(el('th', 'num', '压缩后'));
        hr.appendChild(el('th', '', '修改时间'));
        thead.appendChild(hr);
        table.appendChild(thead);
        const tbody = el('tbody');
        for (const item of childrenOf(A.current)) {
            const tr = el('tr', item.isDir ? 'sp-dir-row' : '');
            const checked = A.selection.has(item.path);
            const cb = document.createElement('input');
            cb.type = 'checkbox';
            cb.checked = checked;
            cb.addEventListener('change', () => {
                if (cb.checked) A.selection.add(item.path);
                else A.selection.delete(item.path);
                tr.classList.toggle('sp-row-selected', cb.checked);
                updateArchiveFooter();
            });
            const checkTd = el('td', 'sp-col-check');
            checkTd.appendChild(cb);
            tr.appendChild(checkTd);
            const icon = item.isDir
                ? '<svg viewBox="0 0 16 16" class="sp-fi sp-fi-dir"><path d="M1.5 3.5h4.6l1.4 1.6h7.4v7.9a1 1 0 0 1-1 1h-11.9a1 1 0 0 1-1-1v-8.5a1 1 0 0 1 1-1z"/></svg>'
                : '<svg viewBox="0 0 16 16" class="sp-fi sp-fi-file"><path d="M4 1.5h5.2L12.5 4.8v9.7a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1v-12a1 1 0 0 1 1-1z"/><path d="M9.2 1.5v3.3h3.3" class="sp-fi-fold"/></svg>';
            const nameTd = el('td', 'sp-name');
            const inner = el('span', 'sp-name-inner');
            inner.innerHTML = icon + ' <span>' + esc(item.name) + (item.isDir ? '/' : '') + '</span>';
            nameTd.appendChild(inner);
            if (item.isDir) {
                nameTd.addEventListener('dblclick', () => {
                    A.current = item.path;
                    A.expanded.add(item.path);
                    renderBreadcrumb();
                    renderFileList();
                    renderTree();
                });
                nameTd.addEventListener('click', () => {
                    A.current = item.path;
                    A.expanded.add(item.path);
                    renderBreadcrumb();
                    renderFileList();
                    renderTree();
                });
                nameTd.classList.add('sp-clickable');
            }
            tr.appendChild(nameTd);
            if (item.isDir) {
                const t = A.totals(item.path);
                tr.appendChild(el('td', 'num', t.count + ' 个文件'));
                tr.appendChild(el('td', 'num', '—'));
                tr.appendChild(el('td', '', '—'));
            } else {
                const e = item.entry;
                tr.appendChild(el('td', 'num', fmtBytes(e.s)));
                tr.appendChild(el('td', 'num', fmtBytes(e.cs)));
                tr.appendChild(el('td', '', fmtDate(e.m) + (e.f.indexOf('e') >= 0 ? ' 🔒' : '')));
            }
            if (checked) tr.classList.add('sp-row-selected');
            tbody.appendChild(tr);
        }
        table.appendChild(tbody);
        list.appendChild(table);
    }

    function selectAllIn(path, on) {
        const f = A.folders.get(path) || { sub: new Map(), files: [] };
        for (const fe of f.files) {
            if (on) A.selection.add(fe.p);
            else A.selection.delete(fe.p);
        }
        f.sub.forEach((child) => selectAllIn(child, on));
    }

    function selectionSummary() {
        let files = 0, size = 0, dirs = 0;
        for (const p of A.selection) {
            if (A.folders.has(p)) {
                dirs += 1;
                const t = A.totals(p);
                files += t.count;
                size += t.size;
            } else {
                files += 1;
                const e = A.entries.find((x) => x.p === p);
                if (e) size += e.s;
            }
        }
        return { files, size, dirs };
    }

    function updateArchiveFooter(msg) {
        if (A.statusEl) {
            if (msg) {
                A.statusEl.textContent = msg;
            } else {
                const sum = selectionSummary();
                A.statusEl.textContent = '已选 ' + sum.files + ' 个文件' + (sum.dirs ? '（含 ' + sum.dirs + ' 个文件夹）' : '') + ' · ' + fmtBytes(sum.size);
            }
        }
    }

    function extractSelected() {
        if (A.selection.size === 0) {
            updateArchiveFooter('请先勾选要解压的文件或文件夹');
            return;
        }
        const auto = !!window.__SP_TEST__;
        window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.spreview
            && window.webkit.messageHandlers.spreview.postMessage({ action: 'extract', paths: Array.from(A.selection), auto: auto });
        updateArchiveFooter('解压中…');
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

    window.SPreview = { render: render, archiveInit: archiveInit, archiveError: archiveError };

    // 原生 → 页面：解压进度与完成（由 Swift 侧注入调用）
    window.SPreview.archiveProgress = function (done, total, current) {
        updateArchiveFooter('解压中 ' + done + '/' + total + ' · ' + current);
    };
    window.SPreview.archiveDone = function (ok, count, info) {
        if (ok) updateArchiveFooter('解压完成：' + count + ' 个文件 → ' + info);
        else if (info === 'cancelled') updateArchiveFooter('已取消');
        else updateArchiveFooter('解压失败：' + info);
    };
})();
