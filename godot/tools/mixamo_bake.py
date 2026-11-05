# Mixamo FBX hareketlerini Quaternius iskeletine aktarip tek GLB'ye yazar (Blender 5.2, arka planda).
# Kullanim: blender -b --python mixamo_bake.py -- <Hero.glb> <mixamo-animasyon/Sinif klasoru> <cikti.glb> <harita.json>
# harita.json: {"P_Idle": "paladin_idle.fbx", "P_Power": "zip:sword and shield slash (3).fbx", ...}
# "zip:" ile baslayan ad klasordeki zip paketlerinin icinde aranir. "Paladin|zip:..." gibi "|" oncesi baska bir
# sinifin klasorunu belirtir (o sinifa ayrilmis hareket). Mixamo ham dosyalari dagitilamaz,
# yalnizca bu aracla uretilen GLB oyunun icine gomulur; ham dosyalar ve GLB git disindadir.
# Yer degistiren hareketler (kosarak saplama, ziplayarak vurus) yerinde oynatilir; one atilmayi oyun kendisi yapar.
# Haritada adin basina "!" konursa kucuk adimli hareket de yerinde tutulur.
# Ayrica <cikti>.json'a her hareketin el/ayak hizlarini yazar: vurus anlari buradan olculur.
import bpy, sys, os, json, zipfile, tempfile
from mathutils import Matrix, Vector
args = sys.argv[sys.argv.index("--") + 1:]
glb, folder, out, mapping = args
MAP = {"Hips": "pelvis", "Spine": "spine_01", "Spine1": "spine_02", "Spine2": "spine_03", "Neck": "neck_01", "Head": "Head"}
for s, t in (("Left", "l"), ("Right", "r")):
    MAP.update({s + "Shoulder": "clavicle_" + t, s + "Arm": "upperarm_" + t, s + "ForeArm": "lowerarm_" + t, s + "Hand": "hand_" + t,
                s + "UpLeg": "thigh_" + t, s + "Leg": "calf_" + t, s + "Foot": "foot_" + t, s + "ToeBase": "ball_" + t})
    for f, n in (("Thumb", "thumb"), ("Index", "index"), ("Middle", "middle"), ("Ring", "ring"), ("Pinky", "pinky")):
        for i in (1, 2, 3):
            MAP[s + "Hand" + f + str(i)] = "%s_0%d_%s" % (n, i, t)
TRACK = ["hand_r", "hand_l", "foot_r", "foot_l"]
TRAVEL = 0.25  # bu kadardan fazla yer degistiren hareket yerinde oynatilir

names = json.load(open(mapping, encoding="utf-8"))
_packs = {}


def packs(d):
    # klasordeki her zip ayri bir gecici klasore acilir (bir kez)
    if d not in _packs:
        _packs[d] = []
        for f in sorted(os.listdir(d)):
            if f.lower().endswith(".zip"):
                p = tempfile.mkdtemp(prefix="mixamo_")
                zipfile.ZipFile(os.path.join(d, f)).extractall(p)
                _packs[d].append((os.path.splitext(f)[0], p))
    return _packs[d]


def source(name):
    d = folder
    if "|" in name:
        other, name = name.split("|", 1)
        d = os.path.join(os.path.dirname(os.path.normpath(folder)), other)
    if name.startswith("zip:"):
        want = name[4:]
        pack = ""
        if "/" in want:  # "zip:Paket Adi/dosya.fbx": ayni adli dosya baska pakette de olabilir
            pack, want = want.split("/", 1)
        for stem, p in packs(d):
            if pack and stem != pack:
                continue
            for root, _, files in os.walk(p):
                if want in files:
                    return os.path.join(root, want)
        raise SystemExit("BULUNAMADI " + name)
    return os.path.join(d, name)


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)
tgt = next(o for o in bpy.data.objects if o.type == "ARMATURE")
for o in list(bpy.data.objects):
    if o.type == "MESH":
        bpy.data.objects.remove(o)
if tgt.animation_data:
    tgt.animation_data_clear()
for a in list(bpy.data.actions):
    bpy.data.actions.remove(a)
for pb in tgt.pose.bones:
    pb.rotation_mode = "QUATERNION"
    pb.matrix_basis.identity()
bpy.context.view_layer.update()
order = [b.name for b in tgt.data.bones]
# bukulme kemikleri (bazi modellerde onkolun yarisini tasir) onkolla birlikte doner
pairs = [(k, v) for k, v in MAP.items()] + [(s + "ForeArm", "lowerarm_twist_" + t) for s, t in (("Left", "l"), ("Right", "r"))]
pairs = sorted([p for p in pairs if p[1] in tgt.pose.bones], key=lambda p: order.index(p[1]))
s = bpy.context.scene
s.render.fps = 30
hip_rest = (tgt.matrix_world @ tgt.pose.bones["pelvis"].bone.matrix_local).translation.copy()
inv = tgt.matrix_world.inverted()
report = {}
for title, fname in names.items():
    pinned = fname.startswith("!")  # "!" ile baslayan: kucuk adimlar dahil govde yatayda hep yerinde (dar menzil)
    fname = fname.lstrip("!")
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=source(fname))
    new = set(bpy.data.objects) - before
    src = next(o for o in new if o.type == "ARMATURE")
    fa, fb = src.animation_data.action.frame_range
    fa, fb = int(fa), int(fb)
    hips = src.pose.bones["mixamorig:Hips"]
    rest_src = src.matrix_world @ hips.bone.matrix_local
    ratio = hip_rest.z / rest_src.translation.z
    s.frame_set(fa)
    bpy.context.view_layer.update()
    h0 = (src.matrix_world @ hips.matrix).translation.copy()
    s.frame_set(fb)
    bpy.context.view_layer.update()
    travel = ((src.matrix_world @ hips.matrix).translation - h0)
    travel.z = 0.0
    in_place = pinned or travel.length > TRAVEL
    tgt.animation_data_create()
    track = {b: [] for b in TRACK}
    for fr in range(fa, fb + 1):
        s.frame_set(fr)
        bpy.context.view_layer.update()
        hip_now = (src.matrix_world @ hips.matrix).translation
        for k, v in pairs:
            ps = src.pose.bones.get("mixamorig:" + k)
            if ps is None:  # Mixamo'ya yuklenen modelde (eldiven) parmak kemigi olmayabilir: o kemik dinlenmede kalir
                continue
            q_now = (src.matrix_world @ ps.matrix).decompose()[1]
            q_rest = (src.matrix_world @ ps.bone.matrix_local).decompose()[1]
            pt = tgt.pose.bones[v]
            q_t = (tgt.matrix_world @ pt.bone.matrix_local).decompose()[1]
            world = (q_now @ q_rest.inverted()) @ q_t
            if v == "pelvis":
                d_ = (hip_now - rest_src.translation) * ratio
                if in_place:
                    d_.x = (h0.x - rest_src.translation.x) * ratio
                    d_.y = (h0.y - rest_src.translation.y) * ratio
                pos = hip_rest + d_
            else:
                pos = (tgt.matrix_world @ pt.matrix).translation
            pt.matrix = inv @ (Matrix.Translation(pos) @ world.to_matrix().to_4x4())
            bpy.context.view_layer.update()
            pt.keyframe_insert("rotation_quaternion", frame=fr - fa)
            if v == "pelvis":
                pt.keyframe_insert("location", frame=fr - fa)
        for b in TRACK:
            track[b].append([round(x, 4) for x in (tgt.matrix_world @ tgt.pose.bones[b].matrix).translation])
    act = tgt.animation_data.action
    act.name = title
    act.use_fake_user = True
    tr = tgt.animation_data.nla_tracks.new()
    tr.name = title
    tr.strips.new(title, 0, act)
    tgt.animation_data.action = None
    for pb in tgt.pose.bones:
        pb.matrix_basis.identity()
    bpy.context.view_layer.update()
    for o in new:
        bpy.data.objects.remove(o)
    report[title] = {"file": fname, "frames": fb - fa + 1, "in_place": in_place, "track": track}
    print("YAPILDI", title, fb - fa + 1, "kare", "yerinde" if in_place else "")
bpy.ops.object.select_all(action="DESELECT")
tgt.select_set(True)
bpy.context.view_layer.objects.active = tgt
os.makedirs(os.path.dirname(out), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True, export_animations=True, export_animation_mode="NLA_TRACKS", export_materials="NONE")
json.dump(report, open(os.path.splitext(out)[0] + ".json", "w", encoding="utf-8"))
print("BITTI", os.path.getsize(out))
