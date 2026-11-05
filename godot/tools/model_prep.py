# Sketchfab karakterini oyuna hazirlar (Blender 5.2, arka planda):
#  1. Istenmeyen parcalari (modelin kendi silahlari vb.) siler.
#  2. Modelin ilk karedeki duruşunu kalici duruş yapar (bazi modellerde iskelet yan yatik gelir).
#  3. Kemikleri Quaternius adlariyla yeniden adlandirir (oyun kodu bu adlari kullanir).
#  4. Yuzunu oyunun yonune cevirir, boyunu ayarlar.
#  5. Kollari/bacaklari Quaternius karakterinin T durusuna getirir: Mixamo hareketleri bu durusa gore aktarilir.
#  6. Kemik eksenlerini Quaternius ile ayni yapar: silah, kalkan ve el ayarlari degismeden calisir.
# Kullanim: blender -b --python model_prep.py -- <Hero.glb> <model.gltf> <ayar.json> <cikti.glb>
# ayar.json: {"remove": ["Object_9"], "height": 1.0, "bones": {"Bip01 Pelvis_08": "pelvis", ...}}
#   height: modelin Head kemigi yuksekliginin Quaternius karakterine orani.
import bpy, sys, json, math
from mathutils import Matrix, Vector, Quaternion

args = sys.argv[sys.argv.index("--") + 1:]
hero_path, src, cfg_path, out = args
cfg = json.load(open(cfg_path, encoding="utf-8"))
# yon hizalamasi: kemik -> yonunu belirleyen alt kemik (Quaternius adlariyla)
AIM = {}
for s in ("l", "r"):
    AIM.update({"clavicle_" + s: "upperarm_" + s, "upperarm_" + s: "lowerarm_" + s, "lowerarm_" + s: "hand_" + s,
                "hand_" + s: "middle_01_" + s, "thigh_" + s: "calf_" + s, "calf_" + s: "foot_" + s, "foot_" + s: "ball_" + s})

bpy.ops.wm.read_factory_settings(use_empty=True)

# --- Quaternius karakterinin kemik bilgileri (dunya uzayinda) ---
bpy.ops.import_scene.gltf(filepath=hero_path)
hero = next(o for o in bpy.data.objects if o.type == "ARMATURE")
H = {}
HERO_ARM = (hero.name, hero.data.name)  # oyun kodu animasyon yollarinda ayni dugum adini bekler
for b in hero.data.bones:
    m = hero.matrix_world @ b.matrix_local
    H[b.name] = (m.to_translation(), m.to_quaternion(), b.length * hero.matrix_world.to_scale()[0])
for o in list(bpy.data.objects):
    bpy.data.objects.remove(o)
for a in list(bpy.data.actions):
    bpy.data.actions.remove(a)

# --- model ---
bpy.ops.import_scene.gltf(filepath=src)
for o in list(bpy.data.objects):
    if o.type == "MESH" and (o.name in cfg.get("remove", []) or o.name.startswith("Icosphere") or not o.vertex_groups):
        bpy.data.objects.remove(o)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
ctx = bpy.context
ctx.scene.frame_set(0)
ctx.view_layer.update()


def bake_pose_as_rest():
    # mesh'ler o anki duruşla dondurulur, sonra duruş iskeletin yeni dinlenme hali olur
    for m in meshes:
        mod = next((x for x in m.modifiers if x.type == "ARMATURE"), None)
        if mod is None:
            continue
        ctx.view_layer.objects.active = m
        bpy.ops.object.select_all(action="DESELECT")
        m.select_set(True)
        name = mod.name
        bpy.ops.object.modifier_apply(modifier=name)
        new = m.modifiers.new("Armature", "ARMATURE")
        new.object = arm
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    ctx.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    bpy.ops.pose.select_all(action="SELECT")
    bpy.ops.pose.armature_apply(selected=False)
    bpy.ops.object.mode_set(mode="OBJECT")


bake_pose_as_rest()
if arm.animation_data:
    arm.animation_data_clear()
for a in list(bpy.data.actions):
    bpy.data.actions.remove(a)



def bake_world(extra=Matrix.Identity(4)):
    # nesne donusumlerini (ve istenen ek donusumu) dogrudan kemik ve mesh verisine isler; hepsi kimlik donusumlu kalir
    for m in meshes:
        mw = extra @ m.matrix_world
        m.parent = None
        m.data.transform(mw)
        m.matrix_world = Matrix.Identity(4)
    aw = extra @ arm.matrix_world
    arm.parent = None
    arm.data.transform(aw)
    arm.matrix_world = Matrix.Identity(4)
    for m in meshes:
        m.parent = arm
        m.matrix_parent_inverse = Matrix.Identity(4)
    # Armature.transform poz kemiklerini kendiliginden yenilemez: eski konumlarla poz verilirse mesh asiri uzar
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    ctx.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.object.mode_set(mode="OBJECT")
    ctx.view_layer.update()


bake_world()
for o in list(bpy.data.objects):
    if o.type not in ("ARMATURE", "MESH"):
        bpy.data.objects.remove(o)

# --- yeniden adlandirma ---
names = dict(cfg.get("bones", {}))
# "base": sonundaki _NN numarasi ve "mixamorig:" atilmis adla esleme (Sketchfab kemik adlarina sira numarasi ekler)
import re
for b in arm.data.bones:
    base = re.sub(r"_\d+$", "", b.name).replace("mixamorig:", "")
    if base in cfg.get("base", {}):
        names[b.name] = cfg["base"][base]
for b in arm.data.bones:
    if b.name in names:
        b.name = names[b.name]
ctx.view_layer.update()
pb = arm.pose.bones


def wpos(n):
    return arm.matrix_world @ pb[n].head


# --- yon ve boy ---
# omuz cizgisinden bulunan gogus yonu Quaternius ile ayni olsun (sol/sag anatomik, ayna olmaz)
fwd = (wpos("upperarm_l") - wpos("upperarm_r")).cross(Vector((0, 0, 1)))
hf = (H["upperarm_l"][0] - H["upperarm_r"][0]).cross(Vector((0, 0, 1)))
fwd.z = 0
ang = math.atan2(fwd.x, fwd.y) - math.atan2(hf.x, hf.y)
ground = min(v.co.z for m in meshes for v in m.data.vertices)
scale = cfg.get("height", 1.0) * H["Head"][0].z / (wpos("Head").z - ground)
bake_world(Matrix.Scale(scale, 4) @ Matrix.Rotation(-ang, 4, "Z") @ Matrix.Translation((0, 0, -ground)))
# yatayda ortala (kalca Quaternius gibi x=y=0'da)
p = wpos("pelvis")
bake_world(Matrix.Translation((-p.x, -p.y, 0)))
print("YON", round(math.degrees(ang), 1), "OLCEK", round(scale, 4))

# --- T durusu: kol ve bacak yonleri Quaternius ile ayni olsun ---
order = [b.name for b in arm.data.bones]  # ebeveynden cocuga sirali
twist = cfg.get("twist", {})  # bukulme kemigi -> izledigi kemik
for name in order:
    if name not in AIM or AIM[name] not in pb or name not in H or AIM[name] not in H:
        continue
    ctx.view_layer.update()
    cur = wpos(AIM[name]) - wpos(name)
    want = H[AIM[name]][0] - H[name][0]
    if cur.length < 1e-4 or want.length < 1e-4:
        continue
    q = cur.normalized().rotation_difference(want.normalized())
    m = arm.matrix_world @ pb[name].matrix
    t = m.to_translation()
    pb[name].matrix = arm.matrix_world.inverted() @ (Matrix.Translation(t) @ (q.to_matrix().to_4x4() @ m.to_3x3().to_4x4()))
    ctx.view_layer.update()
    for tw, follow in twist.items():
        if follow == name and tw in pb:
            mt = arm.matrix_world @ pb[tw].matrix
            pb[tw].matrix = arm.matrix_world.inverted() @ (Matrix.Translation(wpos(name)) @ (q.to_matrix().to_4x4() @ mt.to_3x3().to_4x4()))
            ctx.view_layer.update()
bake_pose_as_rest()

# --- kemik eksenleri Quaternius ile ayni (dinlenme halinde mesh etkilenmez) ---
bpy.ops.object.select_all(action="DESELECT")
arm.select_set(True)
ctx.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
eb = arm.data.edit_bones
inv = arm.matrix_world.inverted()
for e in eb:
    e.use_connect = False
for e in eb:
    if e.name in H:
        head = e.head.copy()
        length = max(e.length, 0.02)
        rot = (inv.to_3x3() @ H[e.name][1].to_matrix())
        mat = rot.to_4x4()
        mat.translation = head
        e.matrix = mat
        e.length = length
bpy.ops.object.mode_set(mode="OBJECT")

arm.name, arm.data.name = HERO_ARM
missing = [n for n in set(names.values()) if n not in arm.data.bones]
print("EKSIK KEMIK", missing)
print("BOY", round(wpos("Head").z, 3), "Quaternius", round(H["Head"][0].z, 3), "UCGEN", sum(len(p.vertices) - 2 for m in meshes for p in m.data.polygons))
bpy.ops.object.select_all(action="DESELECT")
arm.select_set(True)
for m in meshes:
    m.select_set(True)
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True, export_animations=False)
print("BITTI", out)
