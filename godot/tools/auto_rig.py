# Iskeleti olmayan insan modeline Quaternius iskeletini oturtur ve deriyi baglar (Blender 5.2, arka planda).
# Eklem yerleri modelin seklinden bulunur: govde Quaternius oranlariyla olceklenir, kol ve bacaklar
# modelin kendi kol/bacak dogrultusuna cevrilir. Deri: her nokta en yakin iki kemige, mesafeyle yumusak gecisli.
# Zirh gibi sert parcalar icin uygundur. Cikti model_prep.py'ye verilir (kemik adlari zaten Quaternius).
# Kullanim: blender -b --python auto_rig.py -- <Hero.glb> <model.gltf> <ayar.json> <cikti.glb>
# ayar.json: {"remove": ["Object_2"], "head_top_mesh": "Object_3", "arm_mesh": "Object_5"}
import bpy, sys, json, math
from mathutils import Vector, Matrix, Quaternion

args = sys.argv[sys.argv.index("--") + 1:]
hero_path, src, cfg_path, out = args
cfg = json.load(open(cfg_path, encoding="utf-8"))
bpy.ops.wm.read_factory_settings(use_empty=True)
ctx = bpy.context

# --- Quaternius iskeleti ve govde bilgisi ---
bpy.ops.import_scene.gltf(filepath=hero_path)
hero = next(o for o in bpy.data.objects if o.type == "ARMATURE")
body = next(o for o in bpy.data.objects if o.name == "SuperHero_Male")
deform = {g.name for g in body.vertex_groups}
hero_top = max((body.matrix_world @ v.co).z for v in body.data.vertices)
for o in list(bpy.data.objects):
    if o.type == "MESH":
        bpy.data.objects.remove(o)
for a in list(bpy.data.actions):
    bpy.data.actions.remove(a)
if hero.animation_data:
    hero.animation_data_clear()
for pb in hero.pose.bones:
    pb.matrix_basis.identity()
ctx.view_layer.update()
HW = hero.matrix_world
HB = {b.name: (HW @ b.head_local, HW @ b.tail_local) for b in hero.data.bones}

# --- model ---
before = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=src)
new = set(bpy.data.objects) - before
for o in list(new):
    if o.type == "MESH" and o.name in cfg.get("remove", []):
        bpy.data.objects.remove(o)
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
# tum donusumleri mesh verisine isle, ebeveynleri sil
for m in meshes:
    mw = m.matrix_world.copy()
    m.parent = None
    m.data.transform(mw)
    m.matrix_world = Matrix.Identity(4)
for o in list(bpy.data.objects):
    if o.type not in ("MESH", "ARMATURE"):
        bpy.data.objects.remove(o)
ctx.view_layer.update()
pts = [v.co.copy() for m in meshes for v in m.data.vertices]
ground = min(p.z for p in pts)
top_mesh = bpy.data.objects[cfg["head_top_mesh"]]
top = max(v.co.z for v in top_mesh.data.vertices)
s = (top - ground) / hero_top  # Quaternius -> model olcegi
cx = sum(p.x for p in pts) / len(pts)


def body_y(z0, z1):
    sel = [p.y for p in pts if z0 <= p.z <= z1 and abs(p.x - cx) < 0.15 * (top - ground)]
    return (min(sel) + max(sel)) / 2


chest_y = body_y(ground + 0.65 * (top - ground), ground + 0.75 * (top - ground))
hero_chest_y = HB["spine_03"][0].y


def body_map(p):
    return Vector((cx + p.x * s, chest_y + (p.y - hero_chest_y) * s, ground + p.z * s))


def chain(root):
    out = [root]
    for b in hero.data.bones[root].children_recursive:
        out.append(b.name)
    return out


def similarity(a0, a1, b0, b1):
    # a0->b0 tasir, a dogrultusunu b dogrultusuna cevirir, boyu esitler
    q = (a1 - a0).normalized().rotation_difference((b1 - b0).normalized())
    k = (b1 - b0).length / (a1 - a0).length
    return lambda p: b0 + (q @ ((p - a0) * k))


pos = {n: [body_map(h), body_map(t)] for n, (h, t) in HB.items()}

# --- kollar: modelin kol noktalarinin en uzak ucu parmak ucu sayilir ---
arm_mesh = bpy.data.objects[cfg["arm_mesh"]]
arm_pts = [v.co.copy() for v in arm_mesh.data.vertices]
for side, sign in (("l", 1.0), ("r", -1.0)):
    # Quaternius'ta sol kol +X tarafinda mi? kemik konumundan anlasilir
    hsign = 1.0 if HB["upperarm_" + side][0].x > 0 else -1.0
    S = pos["upperarm_" + side][0]
    side_pts = [p for p in arm_pts if (p.x - cx) * hsign > 0]
    tip = max(side_pts, key=lambda p: (p - S).length)
    hero_tip = max((HB[n][1] for n in chain("hand_" + side)), key=lambda p: (p - HB["upperarm_" + side][0]).length)
    f = similarity(HB["upperarm_" + side][0], hero_tip, S, tip)
    for n in chain("upperarm_" + side):
        pos[n] = [f(HB[n][0]), f(HB[n][1])]

# --- bacaklar: ayak bilegi, bacagin alt dilim merkezi ---
for side in ("l", "r"):
    hsign = 1.0 if HB["thigh_" + side][0].x > 0 else -1.0
    H0 = pos["thigh_" + side][0]
    zl = ground + 0.07 * (top - ground)
    low = [p for p in pts if p.z < zl and (p.x - cx) * hsign > 0]
    ankle = Vector((sum(p.x for p in low) / len(low), sum(p.y for p in low) / len(low), ground + (HB["foot_" + side][0].z) * s))
    f = similarity(HB["thigh_" + side][0], HB["foot_" + side][0], H0, ankle)
    for n in chain("thigh_" + side):
        pos[n] = [f(HB[n][0]), f(HB[n][1])]

# --- iskeleti modele tasi ---
bpy.ops.object.select_all(action="DESELECT")
hero.select_set(True)
ctx.view_layer.objects.active = hero
hero.matrix_world = Matrix.Identity(4)
bpy.ops.object.mode_set(mode="EDIT")
for e in hero.data.edit_bones:
    e.use_connect = False
for e in hero.data.edit_bones:
    if e.name in pos:
        roll_ref = e.z_axis.copy()
        e.head, e.tail = pos[e.name]
        e.align_roll(roll_ref)
bpy.ops.object.mode_set(mode="OBJECT")
ctx.view_layer.update()

# --- deri: en yakin iki kemik, mesafeye gore ---
segs = [(b.name, b.head_local.copy(), b.tail_local.copy()) for b in hero.data.bones if b.name in deform]
armpit = min(pos["upperarm_l"][0].z, pos["upperarm_r"][0].z) - cfg.get("armpit", 0.05) * (top - ground)
head_cut = pos["neck_01"][0].z + cfg.get("head_cut", 0.35) * (pos["Head"][0].z - pos["neck_01"][0].z)  # bu yukseklikten yukarisi bas
head_x = pos["Head"][0].x
head_r = cfg.get("head_r", 0.13) * (top - ground)


def seg_dist(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
    return (p - (a + ab * t)).length


for m in meshes:
    for g in list(m.vertex_groups):
        m.vertex_groups.remove(g)
    allow = cfg.get("allow", {}).get(m.name)  # bu parcanin baglanabilecegi kemikler (ad baslangiclari)
    msegs = [sg for sg in segs if allow is None or any(sg[0].startswith(a) for a in allow)]
    groups = {n: m.vertex_groups.new(name=n) for n, _, _ in msegs}
    head_group = groups.get("Head") or m.vertex_groups.new(name="Head")
    for v in m.data.vertices:
        # miğfer, boynuz, sac: tek parca halinde basla doner (boyunla paylasilinca mifer egilip sikisiyordu)
        if v.co.z > head_cut and abs(v.co.x - head_x) < head_r:
            head_group.add([v.index], 1.0, "REPLACE")
            continue
        cand = msegs
        if m.name != cfg["arm_mesh"] and v.co.z < armpit:  # koltuk altindan asagisi kola baglanmaz (gövde kolla acilmasin)
            cand = [sg for sg in msegs if not sg[0].startswith(("clavicle", "upperarm", "lowerarm", "hand"))] or msegs
        d = sorted(((seg_dist(v.co, a, b), n) for n, a, b in cand))[:2]
        w0 = 1.0 / max(d[0][0], 1e-4) ** 4
        w1 = 1.0 / max(d[1][0], 1e-4) ** 4
        tot = w0 + w1
        groups[d[0][1]].add([v.index], w0 / tot, "REPLACE")
        if w1 / tot > 0.02:
            groups[d[1][1]].add([v.index], w1 / tot, "REPLACE")
    m.parent = hero
    mod = m.modifiers.new("Armature", "ARMATURE")
    mod.object = hero
print("OLCEK", round(s, 4), "ZEMIN", round(ground, 3), "TEPE", round(top, 3))
bpy.ops.object.select_all(action="DESELECT")
hero.select_set(True)
for m in meshes:
    m.select_set(True)
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True, export_animations=False)
print("BITTI", out)
