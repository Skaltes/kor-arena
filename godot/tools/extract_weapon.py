# Modelin kendi silahini ayri bir GLB'ye cikarir: sap ortasi orijinde, namlu +Z (Godot'ta +Y), yassi yuzu X ekseninde.
# Kullanim: blender -b --python extract_weapon.py -- <model.gltf> <parca adi> <boy metre> <cikti.glb>
# Silahin hangi ucunun kabza oldugu: kalin/genis olmayan, modelde yukarida kalan uc (sirttaki kilicin kabzasi omuz ustunde).
import bpy, sys
import numpy as np
from mathutils import Matrix, Vector

args = sys.argv[sys.argv.index("--") + 1:]
src, part, length, out = args[0], args[1], float(args[2]), args[3]
grip = float(args[4]) if len(args) > 4 else 0.12  # kabza ucundan sap ortasina, boyun orani
flip = len(args) > 5 and args[5] == "ters"  # kabza modelde asagida kaliyorsa
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
obj = bpy.data.objects[part]
for o in list(bpy.data.objects):
    if o != obj:
        bpy.data.objects.remove(o)
mw = obj.matrix_world.copy()
obj.parent = None
obj.data.transform(mw)
obj.matrix_world = Matrix.Identity(4)
P = np.array([v.co[:] for v in obj.data.vertices])
c = P.mean(axis=0)
_, _, vt = np.linalg.svd(P - c, full_matrices=False)
axis, width = Vector(vt[0]), Vector(vt[1])
t = (P - c) @ vt[0]
if ((c + vt[0] * t.max())[2] < (c + vt[0] * t.min())[2]) != flip:  # eksen kabzadan uca baksin
    axis = -axis
    t = -t
L = t.max() - t.min()
pommel = Vector(c) + axis * t.min()
origin = pommel + axis * (grip * L)
x = width.normalized()
z = axis.normalized()
y = z.cross(x).normalized()
x = y.cross(z).normalized()
rot = Matrix((x, y, z))  # satirlar: model -> yerel
k = length / L
M = Matrix.Scale(k, 4) @ rot.to_4x4() @ Matrix.Translation(-origin)
obj.data.transform(M)
obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True, export_animations=False)
print("SILAH", part, "boy", round(L, 3), "->", length, "olcek", round(k, 4))
