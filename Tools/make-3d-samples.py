#!/usr/bin/env python3
# 生成八种三维模型样本（同一立方体，不同格式）
import struct
import json
import math
import os
import base64
import zipfile

out = 'TestSamples/models'
os.makedirs(out, exist_ok=True)

positions = [[-1, -1, -1], [1, -1, -1], [1, 1, -1], [-1, 1, -1], [-1, -1, 1], [1, -1, 1], [1, 1, 1], [-1, 1, 1]]
indices = [0, 1, 2, 0, 2, 3, 4, 6, 5, 4, 7, 6, 0, 7, 4, 0, 3, 7, 1, 5, 6, 1, 6, 2, 1, 4, 7, 1, 7, 0, 3, 2, 6, 3, 6, 7]
faces = [(0, 1, 2), (0, 2, 3), (4, 6, 5), (4, 7, 6), (0, 7, 4), (0, 3, 7), (1, 5, 6), (1, 6, 2), (1, 4, 7), (1, 7, 0), (3, 2, 6), (3, 6, 7)]

# ---------- GLB ----------
posbin = b''.join(struct.pack('<fff', *v) for v in positions)
idxbin = b''.join(struct.pack('<H', i) for i in indices)
minp = [min(v[i] for v in positions) for i in range(3)]
maxp = [max(v[i] for v in positions) for i in range(3)]
buf_len = len(posbin) + len(idxbin)
gltf_obj = {
    "asset": {"version": "2.0", "generator": "s-preview-sample"},
    "scene": 0, "scenes": [{"nodes": [0]}],
    "nodes": [{"mesh": 0, "name": "Cube"}],
    "meshes": [{"primitives": [{"attributes": {"POSITION": 0}, "indices": 1, "mode": 4, "material": 0}], "name": "CubeMesh"}],
    "accessors": [
        {"bufferView": 0, "componentType": 5126, "count": len(positions), "type": "VEC3", "min": minp, "max": maxp},
        {"bufferView": 1, "componentType": 5123, "count": len(indices), "type": "SCALAR"}],
    "bufferViews": [
        {"buffer": 0, "byteOffset": 0, "byteLength": len(posbin), "target": 34962},
        {"buffer": 0, "byteOffset": len(posbin), "byteLength": len(idxbin), "target": 34963}],
    "buffers": [{"byteLength": buf_len}],
    "materials": [{"name": "blue", "pbrMetallicRoughness": {"baseColorFactor": [0.2, 0.5, 0.9, 1.0], "metallicFactor": 0.1, "roughnessFactor": 0.6}}],
}
binjson = json.dumps(gltf_obj, separators=(',', ':')).encode()
while len(binjson) % 4:
    binjson += b' '
binchunk = posbin + idxbin
while len(binchunk) % 4:
    binchunk += b'\x00'
total = 12 + 8 + len(binjson) + 8 + len(binchunk)
outb = struct.pack('<III', 0x46546C67, 2, total)
outb += struct.pack('<II', len(binjson), 0x4E4F534A) + binjson
outb += struct.pack('<II', len(binchunk), 0x004E4942) + binchunk
open(f'{out}/cube.glb', 'wb').write(outb)

# ---------- glTF（base64 内嵌 buffer） ----------
g = json.loads(json.dumps(gltf_obj))
g["buffers"] = [{"byteLength": buf_len, "uri": "data:application/octet-stream;base64," + base64.b64encode(posbin + idxbin).decode()}]
open(f'{out}/cube.gltf', 'w').write(json.dumps(g))

# ---------- OBJ ----------
lines = ['# 立方体'] + [f'v {v[0]} {v[1]} {v[2]}' for v in positions]
lines += [f'f {a + 1} {b + 1} {c + 1}' for a, b, c in faces]
open(f'{out}/cube.obj', 'w').write('\n'.join(lines) + '\n')

# ---------- STL（ascii） ----------
def facet(p1, p2, p3):
    ux, uy, uz = p2[0] - p1[0], p2[1] - p1[1], p2[2] - p1[2]
    vx, vy, vz = p3[0] - p1[0], p3[1] - p1[1], p3[2] - p1[2]
    nx, ny, nz = uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx
    ln = math.sqrt(nx * nx + ny * ny + nz * nz) or 1
    body = "".join(f"      vertex {p[0]} {p[1]} {p[2]}\n" for p in (p1, p2, p3))
    return (f"  facet normal {nx / ln:.3f} {ny / ln:.3f} {nz / ln:.3f}\n    outer loop\n"
            + body + "    endloop\n  endfacet\n")

stl = "solid cube\n" + "".join(facet(positions[a], positions[b], positions[c]) for a, b, c in faces) + "endsolid cube\n"
open(f'{out}/cube.stl', 'w').write(stl)

# ---------- PLY（ascii） ----------
ply = ["ply", "format ascii 1.0", "element vertex 8",
       "property float x", "property float y", "property float z",
       f"element face {len(faces)}", "property list uchar int vertex_indices", "end_header"]
ply += [f"{v[0]} {v[1]} {v[2]}" for v in positions]
ply += ["3 %d %d %d" % f for f in faces]
open(f'{out}/cube.ply', 'w').write("\n".join(ply) + "\n")

# ---------- DAE（Collada） ----------
dae = """<?xml version="1.0" encoding="utf-8"?>
<COLLADA xmlns="http://www.collada.org/2005/11/COLLADASchema" version="1.4.1">
 <asset><created>2026-01-01T00:00:00</created><modified>2026-01-01T00:00:00</modified><unit name="meter" meter="1"/><up_axis>Y_UP</up_axis></asset>
 <library_effects><effect id="fx"><profile_COMMON><technique sid="common"><lambert>
  <diffuse><color sid="diffuse">0.2 0.6 0.9 1</color></diffuse>
 </lambert></technique></profile_COMMON></effect></library_effects>
 <library_materials><material id="mat" name="blue"><instance_effect url="#fx"/></material></library_materials>
 <library_geometries><geometry id="cube"><mesh>
  <source id="pos"><float_array id="pos-array" count="24">-1 -1 -1 1 -1 -1 1 1 -1 -1 1 -1 -1 -1 1 1 -1 1 1 1 1 -1 1 1</float_array>
   <technique_common><accessor source="#pos-array" count="8" stride="3"><param name="X" type="float"/><param name="Y" type="float"/><param name="Z" type="float"/></accessor></technique_common></source>
  <vertices><input semantic="POSITION" source="#pos"/></vertices>
  <triangles count="12" material="msym"><input offset="0" semantic="VERTEX" source="#vertices"/>
   <p>0 1 2 0 2 3 4 6 5 4 7 6 0 7 4 0 3 7 1 5 6 1 6 2 1 4 7 1 7 0 3 2 6 3 6 7</p></triangles>
 </mesh></geometry></library_geometries>
 <library_visual_scenes><visual_scene id="scene">
  <node id="n1" name="Cube" type="NODE"><instance_geometry url="#cube"><bind_material><technique_common>
   <instance_material symbol="msym" target="#mat"/></technique_common></bind_material></instance_geometry></node>
 </visual_scene></library_visual_scenes>
 <scene><instance_visual_scene url="#scene"/></scene>
</COLLADA>
"""
open(f'{out}/cube.dae', 'w').write(dae)

# ---------- USDZ（Xform + Mesh 结构，three.js USDZLoader 可解析） ----------
usda = """#usda 1.0
(
    defaultPrim = "Cube"
    metersPerUnit = 1
    upAxis = "Y"
)

def Xform "Cube"
{
    def Mesh "Cube"
    {
        int[] faceVertexCounts = [4, 4, 4, 4, 4, 4]
        int[] faceVertexIndices = [0, 1, 2, 3, 4, 5, 6, 7, 0, 3, 2, 1, 4, 7, 6, 5, 0, 4, 5, 1, 1, 5, 6, 2]
        point3f[] points = [(-1, -1, -1), (1, -1, -1), (1, 1, -1), (-1, 1, -1), (-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)]
        color3f[] primvars:displayColor = [(0.2, 0.6, 0.9)]
    }
}
"""
with zipfile.ZipFile(f'{out}/cube.usdz', 'w') as z:
    z.writestr('cube.usda', usda)

# ---------- FBX（ascii 7.4，three.js FBXLoader 可解析） ----------
fbx = """; FBX 7.4.0 ascii project file
FBXHeaderExtension:  {
\tFBXHeaderVersion: 1003
\tFBXVersion: 7400
\tCreationTimeStamp:  {
\t\tVersion: 1000
\t\tYear: 2026
\t\tMonth: 1
\t\tDay: 1
\t\tHour: 0
\t\tMinute: 0
\t\tSecond: 0
\t\tMillisecond: 0
\t}
\tCreator: "s-preview"
}
GlobalSettings:  {
\tVersion: 1000
\tProperties70:  {
\t\tP: "UpAxis", "int", "Integer", "",1
\t\tP: "UpAxisSign", "int", "Integer", "",1
\t\tP: "FrontAxis", "int", "Integer", "",2
\t\tP: "FrontAxisSign", "int", "Integer", "",1
\t\tP: "UnitScaleFactor", "double", "Number", "",1
\t}
}
Objects:  {
\tGeometry: 1000000, "Geometry::Cube", "Mesh" {
\t\tVertices: *24 {
\t\t\ta: -1,-1,-1,1,-1,-1,1,1,-1,-1,1,-1,-1,-1,1,1,-1,1,1,1,1,-1,1,1
\t\t}
\t\tPolygonVertexIndex: *36 {
\t\t\ta: 0,1,2,-4,0,2,3,-4,4,6,5,-4,4,7,6,-4,0,7,4,-4,0,3,7,-4,1,5,6,-4,1,6,2,-4,1,4,7,-4,1,7,0,-4,3,2,6,-4,3,6,7,-4
\t\t}
\t\tGeometryVersion: 124
\t}
\tModel: 1000001, "Model::Cube", "Mesh" {
\t\tVersion: 232
\t\tProperties70:  {
\t\t\tP: "Lcl Translation", "Lcl Translation", "", "A",0,0,0
\t\t}
\t\tShading: T
\t\tCulling: "CullingOff"
\t}
}
Connections:  {
\tC: "OO",1000000,1000001
\tC: "OO",1000001,0
}
"""
open(f'{out}/cube.fbx', 'w').write(fbx)

print('models:', sorted(os.listdir(out)))
