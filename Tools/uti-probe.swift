import UniformTypeIdentifiers
let exts = ["py","go","js","jsx","ts","tsx","vue","kt","kts","dart","md","markdown","ipynb","zip","7z","rar","tar","gz","tgz","bz2","xz","webp","avif","glb","gltf","obj","stl","ply","fbx","dae","usdz","txt","swift","rs","lua","json","yaml","yml","toml","xml","html","css","scss","rb","php","java","c","cpp","h","m","mm","sh","sql","r","pl","ps1","ini","conf","log","csv"]
let groups = ["public.plain-text","public.source-code","public.image","public.archive","public.data","public.content","public.3d-content","public.shell-script"]
for e in exts {
    let t = UTType(filenameExtension: e)
    let conform = groups.compactMap { g -> String? in
        guard let ct = UTType(g), let t = t, t.conforms(to: ct) else { return nil }
        return g
    }.joined(separator: ",")
    print("\(e)\t\(t?.identifier ?? "nil")\t[\(conform)]")
}
