/* 3D 查看器：three.js 场景、交互控制、动画播放、统计信息 */
(function () {
    'use strict';

    function open(opt) {
        const H = window.SPreview3D;
        const T = H.THREE;
        const container = opt.container;
        const dark = opt.dark;
        const backgroundMode = opt.backgroundMode || 'auto';

        let width = container.clientWidth || 800;
        let height = container.clientHeight || 600;
        if (height < 50) height = 600;

        const scene = new T.Scene();
        const bgColor = backgroundMode === 'light' ? 0xf2f2f4 : (backgroundMode === 'dark' ? 0x1e1e20 : (dark ? 0x1e1e20 : 0xf2f2f4));
        scene.background = new T.Color(bgColor);

        const camera = new T.PerspectiveCamera(45, width / height, 0.01, 10000);
        camera.position.set(3, 2.4, 3.6);

        const renderer = new T.WebGLRenderer({ antialias: true, alpha: false });
        renderer.setPixelRatio(window.devicePixelRatio || 1);
        renderer.setSize(width, height);
        renderer.outputColorSpace = T.SRGBColorSpace;
        container.appendChild(renderer.domElement);

        // 环境光照
        const pmrem = new T.PMREMGenerator(renderer);
        try {
            const env = pmrem.fromScene(new H.RoomEnvironment(), 0.04).texture;
            scene.environment = env;
        } catch (e) { /* 环境贴图失败不阻断 */ }
        scene.add(new T.AmbientLight(0xffffff, dark ? 0.55 : 0.6));
        const dir = new T.DirectionalLight(0xffffff, dark ? 1.6 : 1.2);
        dir.position.set(4, 6, 3);
        scene.add(dir);

        const controls = new H.OrbitControls(camera, renderer.domElement);
        controls.enableDamping = true;
        controls.autoRotateSpeed = 2.2;

        // 辅助元素容器
        const helpers = new T.Group();
        scene.add(helpers);
        let grid = null, axes = null, boxHelper = null, skeletonHelper = null;
        let autoRotate = !!opt.autoRotate;
        controls.autoRotate = autoRotate;
        let playing = true;
        let mixer = null;
        const animations = [];
        let rootModel = null;
        const wireframeMats = [];

        function makeGrid(size) {
            if (grid) { helpers.remove(grid); grid = null; }
            if (!opt.grid) return;
            const div = Math.max(8, Math.min(60, Math.round(size)));
            grid = new T.GridHelper(size * 2, div, dark ? 0x4a4a52 : 0x9a9aa4, dark ? 0x2e2e34 : 0xc8c8ce);
            helpers.add(grid);
        }
        function makeAxes(size) {
            if (axes) { helpers.remove(axes); axes = null; }
            if (!opt.axes) return;
            axes = new T.AxesHelper(size);
            helpers.add(axes);
        }

        let pointsMode = false;
        function applyWireframe(v) {
            wireframeMats.forEach((m) => { try { m.wireframe = v && !pointsMode; } catch (e) {} });
        }
        function applyPoints(v) {
            pointsMode = v;
            wireframeMats.forEach((m) => { try { m.wireframe = false; } catch (e) {} });
            if (rootModel) {
                rootModel.traverse((o) => {
                    if (o.isMesh) o.visible = !v;
                    if (o.isPoints) o.visible = v;
                });
                if (v && rootModel) {
                    let added = false;
                    rootModel.traverse((o) => {
                        if (!added && o.isMesh && o.geometry && o.geometry.attributes && o.geometry.attributes.position) {
                            const pg = new T.Points(o.geometry, new T.PointsMaterial({ size: fitSize / 120, color: dark ? 0x9fd0ff : 0x2a7fd4 }));
                            o.add(pg);
                            added = true;
                            pointsObj = pg;
                        }
                    });
                } else if (pointsObj) {
                    pointsObj.removeFromParent();
                    pointsObj = null;
                }
            }
        }
        let pointsObj = null;
        function applyBBox(v) {
            if (boxHelper) { scene.remove(boxHelper); boxHelper = null; }
            if (v && rootModel) {
                boxHelper = new T.BoxHelper(rootModel, 0x0a84ff);
                scene.add(boxHelper);
            }
        }
        function applySkeleton(v) {
            if (skeletonHelper) { scene.remove(skeletonHelper); skeletonHelper = null; }
            if (v && rootModel) {
                const skinned = [];
                rootModel.traverse((o) => { if (o.isSkinnedMesh) skinned.push(o); });
                if (skinned.length) {
                    skeletonHelper = new T.SkeletonHelper(skinned[0]);
                    scene.add(skeletonHelper);
                }
            }
        }
        function applyGrid(v) { opt.grid = v; const s = fitSize || 2; makeGrid(s); if (grid) grid.position.y = -minY; }
        function applyAxes(v) { opt.axes = v; makeAxes(fitSize || 2); }
        function applyRotate(v) { autoRotate = v; controls.autoRotate = v; }
        function setPlay(v) { playing = v; }

        let fitSize = 2;
        let minY = 0;

        function prepModel(model) {
            rootModel = model;
            scene.add(model);
            const box = new T.Box3().setFromObject(model);
            if (!box.isEmpty()) {
                const size = box.getSize(new T.Vector3());
                const center = box.getCenter(new T.Vector3());
                fitSize = Math.max(size.x, size.y, size.z) || 2;
                minY = box.min.y;
                model.position.sub(center);
                model.position.y += (size.y / 2);
            }
            makeGrid(fitSize);
            makeAxes(fitSize);
            if (grid) grid.position.y = -minY - 0.0001;
            const dist = fitSize * 2.2;
            camera.position.set(dist * 0.75, dist * 0.6, dist * 0.9);
            controls.target.set(0, fitSize * 0.35, 0);
            controls.update();
            // 收集统计与线框材质
            let meshes = 0, triangles = 0, vertices = 0, materials = 0;
            const seenMats = new Set();
            model.traverse((o) => {
                if (o.isMesh) {
                    meshes++;
                    const g = o.geometry;
                    if (g) {
                        if (g.index) triangles += g.index.count / 3;
                        else if (g.attributes && g.attributes.position) triangles += g.attributes.position.count / 3;
                        if (g.attributes && g.attributes.position) vertices += g.attributes.position.count;
                        if (!g.attributes.normal && g.attributes && g.attributes.position) g.computeVertexNormals();
                    }
                    if (o.isPoints) {
                        meshes++;
                        if (o.geometry && o.geometry.attributes && o.geometry.attributes.position) {
                            vertices += o.geometry.attributes.position.count;
                        }
                    }
                    const mats = Array.isArray(o.material) ? o.material : [o.material];
                    mats.forEach((m) => {
                        if (!m || seenMats.has(m)) return;
                        seenMats.add(m);
                        materials++;
                        wireframeMats.push(m);
                    });
                    if (o.isSkinnedMesh && o.skeleton) {
                        // 骨骼动画可用
                    }
                }
            });
            applyWireframe(!!opt.wireframe);
            applyBBox(!!opt.bbox);
            applySkeleton(!!opt.skeleton);
            return { meshes, triangles: Math.round(triangles), vertices, materials, animations: animations.length };
        }

        function setupAnimations(object) {
            if (object.animations && object.animations.length) {
                animations.push(...object.animations);
                mixer = new T.AnimationMixer(object);
            }
        }

        function makeDefaultMaterial() {
            return new T.MeshStandardMaterial({ color: dark ? 0x9fb7c9 : 0x8fa8bc, metalness: 0.1, roughness: 0.65 });
        }

        function loaderFor(format) {
            switch (format) {
                case 'glb':
                case 'gltf': {
                    const loader = new H.GLTFLoader();
                    const draco = new H.DRACOLoader();
                    draco.setDecoderPath('vendor/draco/');
                    loader.setDRACOLoader(draco);
                    return loader;
                }
                case 'obj': return new H.OBJLoader();
                case 'stl': return new H.STLLoader();
                case 'ply': return new H.PLYLoader();
                case 'fbx': return new H.FBXLoader();
                case 'dae': return new H.ColladaLoader();
                case 'usdz': return new H.USDZLoader();
                default: return null;
            }
        }

        let disposed = false;
        function load() {
            const format = (opt.format || '').toLowerCase();
            const loader = loaderFor(format);
            if (!loader) { opt.onError && opt.onError('不支持的模型格式：' + format); return; }
            const url = opt.resourceURL;

            const done = (model, anims) => {
                if (disposed) return;
                if (anims && anims.length) { animations.push(...anims); mixer = new T.AnimationMixer(model); }
                const stats = prepModel(model);
                opt.onStats && opt.onStats(Object.assign(stats, { renderer: rendererInfo() }));
                if (mixer) { animations.forEach((c) => mixer.clipAction(c).play()); }
            };

            if (format === 'stl' || format === 'ply') {
                fetch(url).then((r) => r.arrayBuffer()).then((buf) => {
                    const geometry = loader.parse(buf);
                    geometry.computeVertexNormals && geometry.computeVertexNormals();
                    const mesh = new T.Mesh(geometry, makeDefaultMaterial());
                    done(mesh);
                }).catch((e) => opt.onError && opt.onError(e.message || String(e)));
            } else if (format === 'obj') {
                fetch(url).then((r) => r.text()).then((text) => {
                    const model = loader.parse(text);
                    model.traverse((o) => { if (o.isMesh && !o.material.isMeshStandardMaterial) o.material = makeDefaultMaterial(); });
                    done(model);
                }).catch((e) => opt.onError && opt.onError(e.message || String(e)));
            } else if (format === 'dae') {
                fetch(url).then((r) => r.text()).then((text) => {
                    const collada = loader.parse(text, '');
                    const model = collada.scene;
                    done(model, collada.animations || model.animations);
                }).catch((e) => opt.onError && opt.onError(e.message || String(e)));
            } else {
                // glb / gltf / fbx / usdz：二进制解析
                fetch(url).then((r) => r.arrayBuffer()).then((buf) => {
                    if (format === 'glb') {
                        loader.parse(buf, '', (gltf) => done(gltf.scene, gltf.animations), (e) => opt.onError && opt.onError(e.message || '解析失败'));
                    } else if (format === 'gltf') {
                        const text = new TextDecoder().decode(buf);
                        loader.parse(text, '', (gltf) => done(gltf.scene, gltf.animations), (e) => opt.onError && opt.onError(e.message || '解析失败（外部资源引用的 .gltf 无法在预览中加载，建议使用 .glb）'));
                    } else if (format === 'fbx') {
                        try {
                            const model = loader.parse(buf, '');
                            done(model, model.animations);
                        } catch (e) { opt.onError && opt.onError(e.message || String(e)); }
                    } else if (format === 'usdz') {
                        try {
                            const model = loader.parse(buf);
                            done(model);
                        } catch (e) { opt.onError && opt.onError(e.message || String(e)); }
                    }
                }).catch((e) => opt.onError && opt.onError(e.message || String(e)));
            }
        }

        function rendererInfo() {
            try {
                const gl = renderer.getContext();
                const dbg = gl.getExtension('WEBGL_debug_renderer_info');
                if (dbg) return String(gl.getParameter(dbg.UNMASKED_RENDERER_WEBGL));
                return String(gl.getParameter(gl.VERSION));
            } catch (e) { return ''; }
        }

        // 渲染循环
        const clock = new T.Clock();
        function loop() {
            if (disposed) return;
            requestAnimationFrame(loop);
            const dt = clock.getDelta();
            if (playing && mixer) mixer.update(dt);
            controls.update();
            if (boxHelper) boxHelper.update();
            renderer.render(scene, camera);
        }

        function onResize() {
            const w = container.clientWidth || 800;
            const h = container.clientHeight || 600;
            camera.aspect = w / h;
            camera.updateProjectionMatrix();
            renderer.setSize(w, h);
        }
        const ro = new ResizeObserver(onResize);
        ro.observe(container);
        loop();
        load();

        return {
            dispose() { disposed = true; ro.disconnect(); renderer.dispose(); },
            setWireframe: applyWireframe,
            setPoints: applyPoints,
            setBBox: applyBBox,
            setSkeleton: applySkeleton,
            setGrid: applyGrid,
            setAxes: applyAxes,
            setAutoRotate: applyRotate,
            setPlay: setPlay,
            hasAnimations: () => animations.length > 0
        };
    }

    window.SPreviewViewer3D = { open: open };
})();
