# Kumas kemikleri: modeldeki etek/pelerin parcalarina kucuk kemik zincirleri ekler ve o koselerin agirligini zincire
# verir. Oyunda bu zincirleri SpringBoneSimulator3D sallar (CharacterView._build_cloth). model_prep.py'den SONRA calisir.
# Kullanim: blender -b --python cloth_rig.py -- <model.glb (yerinde guncellenir)> <ayar.json>
# ayar.json: {"pieces": [{"object": "Object_8", "island": 1, "name": "palto", "joints": 3, "split": "angle4"}, ...]}
#   island: parcadaki bagli kose adasinin sirasi (bmesh sirasi; arac her adanin kutusunu yazar, kontrol icin).
#   split: yok = tek zincir, "x2" = sol/sag iki zincir, "angle4" = on/arka/sol/sag (bacaklari saran etek).
# Kemik adlari "kumas_<ad>[_<yon>]_<i>"; kok kemigi pelvis'e baglidir. Ust kisim (ilk %20) eski agirligini korur ki
# kumas govdeden kopmasin.
import bpy, sys, json, bmesh, math
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
path, cfg_path = args
cfg = json.load(open(cfg_path, encoding="utf-8"))
PIN = 0.2

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=path)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
meshes = [o for o in bpy.data.objects if o.type == "MESH" and not o.name.startswith("Icosphere")]
for o in list(bpy.data.objects):
    if o.type == "MESH" and o.name.startswith("Icosphere"):
        bpy.data.objects.remove(o)
if any(b.name.startswith("kumas_") for b in arm.data.bones):
    raise SystemExit("ZATEN VAR: model once model_prep ile yeniden uretilmeli")


def islands(o):
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bm.verts.ensure_lookup_table()
    seen, out = set(), []
    for v in bm.verts:
        if v.index in seen:
            continue
        stack, isl = [v], []
        seen.add(v.index)
        while stack:
            x = stack.pop()
            isl.append(x.index)
            for e in x.link_edges:
                y = e.other_vert(x)
                if y.index not in seen:
                    seen.add(y.index)
                    stack.append(y)
        out.append(isl)
    return out


pelvis = arm.matrix_world @ arm.data.bones["pelvis"].head_local
chains = []  # (ad, nokta listesi)
assign = []  # (obje, kose, {kemik: agirlik}, pin)
for piece in cfg["pieces"]:
    o = bpy.data.objects[piece["object"]]
    isl = islands(o)[piece["island"]]
    co = {k: o.matrix_world @ o.data.vertices[k].co for k in isl}
    xs = [c.x for c in co.values()]
    print("PARCA %s: %d kose x %.2f..%.2f y %.2f..%.2f z %.2f..%.2f" % (piece["name"], len(isl), min(xs), max(xs),
          min(c.y for c in co.values()), max(c.y for c in co.values()), min(c.z for c in co.values()), max(c.z for c in co.values())))
    # her kosenin alt zincirlere payi (toplam 1)
    split = piece.get("split", "")
    if split == "angle4":
        dirs = {"on": Vector((0, -1)), "arka": Vector((0, 1)), "sol": Vector((1, 0)), "sag": Vector((-1, 0))}
        def share(c):
            d = Vector((c.x - pelvis.x, c.y - pelvis.y))
            if d.length < 1e-4:
                return {k: 0.25 for k in dirs}
            d.normalize()
            w = {k: max(0.0, d.dot(v)) ** 2 for k, v in dirs.items()}
            s = sum(w.values())
            return {k: x / s for k, x in w.items()}
    elif split == "x2":
        mid, half = (min(xs) + max(xs)) / 2, max(0.02, (max(xs) - min(xs)) * 0.2)
        def share(c):
            a = min(1.0, max(0.0, (c.x - mid + half) / (2 * half)))
            return {"sol": a, "sag": 1.0 - a}
    else:
        def share(c):
            return {"": 1.0}
    shares = {k: share(c) for k, c in co.items()}
    n = int(piece.get("joints", 3))
    for sub in shares[isl[0]]:
        mine = [k for k in isl if shares[k][sub] >= 0.5] or isl
        top, bot = max(co[k].z for k in mine), min(co[k].z for k in mine)
        span = max(top - bot, 0.05)
        hi = [co[k] for k in mine if co[k].z > top - span * 0.15]
        lo = [co[k] for k in mine if co[k].z < bot + span * 0.15]
        p0 = sum(hi, Vector()) / len(hi)
        p1 = sum(lo, Vector()) / len(lo)
        p0.z, p1.z = top, bot
        name = "kumas_" + piece["name"] + ("_" + sub if sub else "")
        chains.append((name, [p0.lerp(p1, i / n) for i in range(n + 1)]))
        for k in isl:
            a = shares[k][sub]
            if a <= 0.0:
                continue
            t = min(1.0, max(0.0, (top - co[k].z) / span))
            s = min(max(t * n, 0.5), n - 0.5)
            w = {}
            for i in range(n):
                h = max(0.0, 1.0 - abs(s - (i + 0.5)))
                if h > 0.0:
                    w["%s_%d" % (name, i)] = h * a
            assign.append((o, k, w, min(1.0, max(0.0, (PIN - t) / PIN))))

# kemikler
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
inv = arm.matrix_world.inverted()
for name, pts in chains:
    parent = arm.data.edit_bones["pelvis"]
    for i in range(len(pts) - 1):
        b = arm.data.edit_bones.new("%s_%d" % (name, i))
        b.head, b.tail = inv @ pts[i], inv @ pts[i + 1]
        b.parent = parent
        b.use_connect = i > 0
        parent = b
    print("ZINCIR", name, "ust %.2f alt %.2f" % (pts[0].z, pts[-1].z))
bpy.ops.object.mode_set(mode="OBJECT")

# agirliklar: kumas payi eski agirliklarin yerini alir, ust serit eskisiyle karisir
merged = {}
for o, k, w, pin in assign:
    m = merged.setdefault((o.name, k), [o, {}, pin])
    for b, x in w.items():
        m[1][b] = m[1].get(b, 0.0) + x
    m[2] = max(m[2], pin)
for (_, k), (o, w, pin) in merged.items():
    v = o.data.vertices[k]
    old = {o.vertex_groups[g.group].name: g.weight for g in v.groups}
    tot = sum(old.values()) or 1.0
    for g in list(v.groups):
        o.vertex_groups[g.group].remove([k])
    s = sum(w.values()) or 1.0
    final = {b: x / tot * pin for b, x in old.items()}
    for b, x in w.items():
        final[b] = final.get(b, 0.0) + x / s * (1.0 - pin)
    for b, x in final.items():
        if x > 0.001:
            vg = o.vertex_groups.get(b) or o.vertex_groups.new(name=b)
            vg.add([k], x, "REPLACE")
print("KOSE", len(merged))

bpy.ops.object.select_all(action="DESELECT")
arm.select_set(True)
for m in meshes:
    m.select_set(True)
bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_animations=False)
print("BITTI", path)
