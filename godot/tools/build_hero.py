# Blender betigi: Quaternius govdesinin uzerine, govdeye birebir oturan zirhlar uretir.
# Calistirma: blender -b -P tools/build_hero.py
# Cikti: assets/quaternius/Hero.glb (govde + 3 sinifin parcalari), assets/quaternius/Weapons.glb
import math
import os

import bmesh
import bpy
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "quaternius", "base", "Superhero_Male_FullBody.gltf")
OUT = os.path.join(ROOT, "assets", "quaternius", "Hero.glb")
OUT_W = os.path.join(ROOT, "assets", "quaternius", "Weapons.glb")

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
body = next(o for o in bpy.data.objects if o.type == "MESH" and o.name.startswith("SuperHero"))
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
groups = {g.index: g.name for g in body.vertex_groups}


def bone_pos(name):
    return arm.matrix_world @ arm.data.bones[name].head_local


print("KEMIK", {n: tuple(round(c, 3) for c in bone_pos(n)) for n in ["pelvis", "spine_03", "Head", "upperarm_l", "lowerarm_l", "hand_l", "thigh_l", "calf_l", "foot_l"]})
materials = {}


def mat(name):
    if name not in materials:
        materials[name] = bpy.data.materials.new(name)
    return materials[name]


def weights(v):
    return {groups[g.group]: g.weight for g in v.groups}


def carve(name, test, offset, thick, material):
    """Govdeden test()'i gecen yuzleri kopyalar, disari iter, kalinlik verir. Agirliklar korunur."""
    bpy.ops.object.select_all(action="DESELECT")
    new = body.copy()
    new.data = body.data.copy()
    new.name = name
    bpy.context.collection.objects.link(new)
    bm = bmesh.new()
    bm.from_mesh(new.data)
    dl = bm.verts.layers.deform.active
    keep = {}
    for v in bm.verts:
        w = {groups[i]: x for i, x in v[dl].items()}
        keep[v.index] = test(v.co, w)
    bye = [f for f in bm.faces if not all(keep[v.index] for v in f.verts)]
    bmesh.ops.delete(bm, geom=bye, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(new.data)
    bm.free()
    new.data.materials.clear()
    new.data.materials.append(mat(material))
    d = new.modifiers.new("d", "DISPLACE")
    d.strength = offset
    d.mid_level = 0.0
    d.direction = "NORMAL"
    s = new.modifiers.new("s", "SOLIDIFY")
    s.thickness = thick
    s.offset = -1.0
    bpy.context.view_layer.objects.active = new
    new.select_set(True)
    bpy.ops.object.modifier_apply(modifier="d")
    bpy.ops.object.modifier_apply(modifier="s")
    bpy.ops.object.shade_smooth()
    new.select_set(False)
    return new


def finish(o, name, material, bone=None, bevel=0.0):
    """Sonradan modellenen parca: UV acilir, bir kemige ya da govde agirliklarina baglanir."""
    o.name = name
    o.data.name = name
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if bevel > 0.0:
        b = o.modifiers.new("b", "BEVEL")
        b.width = bevel
        b.segments = 2
        b.limit_method = "ANGLE"
        bpy.ops.object.modifier_apply(modifier="b")
    bpy.ops.object.shade_smooth()
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(island_margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")
    o.data.materials.clear()
    o.data.materials.append(mat(material))
    if bone is not None:
        g = o.vertex_groups.new(name=bone)
        g.add(range(len(o.data.vertices)), 1.0, "REPLACE")
        m = o.modifiers.new("Armature", "ARMATURE")
        m.object = arm
        o.parent = arm
    o.select_set(False)
    return o


def transfer_weights(o):
    """Etek, pelerin gibi parcalar yakindaki govde agirliklarini alir: bacakla birlikte oynar."""
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    m = o.modifiers.new("dt", "DATA_TRANSFER")
    m.object = body
    m.use_vert_data = True
    m.data_types_verts = {"VGROUP_WEIGHTS"}
    m.vert_mapping = "NEAREST"
    bpy.ops.object.datalayout_transfer(modifier="dt")
    bpy.ops.object.modifier_apply(modifier="dt")
    a = o.modifiers.new("Armature", "ARMATURE")
    a.object = arm
    o.parent = arm
    o.select_set(False)


def sphere(loc, scale, seg=24, rings=14):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings, location=loc)
    o = bpy.context.active_object
    o.scale = scale
    return o


def cube(loc, scale, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(location=loc, rotation=rot)
    o = bpy.context.active_object
    o.scale = scale
    return o


def cyl(loc, r1, r2, h, rot=(0, 0, 0), seg=20):
    bpy.ops.mesh.primitive_cone_add(vertices=seg, radius1=r1, radius2=r2, depth=h, location=loc, rotation=rot)
    return bpy.context.active_object


def join(objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    return bpy.context.active_object


def cut_below(o, z):
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if (o.matrix_world @ v.co).z < z], context="VERTS")
    bm.to_mesh(o.data)
    bm.free()


def sum_w(w, names):
    return sum(w.get(n, 0.0) for n in names)


TORSO = ["spine_01", "spine_02", "spine_03", "clavicle_l", "clavicle_r"]
LEGS = ["thigh_l", "thigh_r", "calf_l", "calf_r"]
FEET = ["foot_l", "foot_r", "ball_l", "ball_r"]
UPPER = ["upperarm_l", "upperarm_r"]
LOWER = ["lowerarm_l", "lowerarm_r"]
HANDS_PREFIX = ("hand_", "index", "middle", "ring", "pinky", "thumb")


def hand_w(w):
    return sum(x for n, x in w.items() if n.startswith(HANDS_PREFIX))


head = bone_pos("Head")
pelvis_z = bone_pos("pelvis").z
chest_z = bone_pos("spine_03").z
shoulder = bone_pos("upperarm_l")
waist = pelvis_z + 0.1

# ---- SAVASCI: Roma kas zirhi, deri etek, tolgali miğfer ----
carve("W_Tunic", lambda c, w: sum_w(w, TORSO + UPPER + ["pelvis"]) > 0.4 and abs(c.x) < 0.42 and c.z > pelvis_z - 0.12, 0.006, 0.004, "M_Cloth")
carve("W_Cuirass", lambda c, w: sum_w(w, TORSO) > 0.55 and c.z > waist - 0.02 and c.z < chest_z + 0.2 and abs(c.x) < 0.24, 0.019, 0.008, "M_Bronze")
carve("W_Belt", lambda c, w: abs(c.z - (waist - 0.05)) < 0.045 and sum_w(w, TORSO + ["pelvis"]) > 0.5, 0.024, 0.008, "M_Leather")
carve("W_Greaves", lambda c, w: sum_w(w, ["calf_l", "calf_r"]) > 0.6 and c.z > 0.14, 0.012, 0.005, "M_Bronze")
carve("W_Boots", lambda c, w: sum_w(w, FEET + ["calf_l", "calf_r"]) > 0.5 and c.z < 0.17, 0.008, 0.005, "M_Leather")
carve("W_Bracers", lambda c, w: sum_w(w, LOWER) > 0.6, 0.009, 0.004, "M_Bronze")
carve("W_Gloves", lambda c, w: hand_w(w) > 0.5, 0.004, 0.002, "M_Leather")

strips = []
for i in range(18):
    a = i / 18.0 * math.tau
    x = math.sin(a) * 0.205
    y = math.cos(a) * 0.15
    strips.append(cube((x, y, pelvis_z - 0.14), (0.034, 0.008, 0.15), (0.12 * math.cos(a), -0.12 * math.sin(a), -a)))
skirt = join(strips)
finish(skirt, "W_Skirt", "M_Leather", bevel=0.004)
transfer_weights(skirt)

for side, sx in (("l", 1), ("r", -1)):
    s = bone_pos("upperarm_" + side)
    plates = []
    for i in range(3):
        p = sphere((s.x + sx * (0.04 + i * 0.03), s.y, s.z + 0.015 - i * 0.022), (0.115 - i * 0.012, 0.125 - i * 0.012, 0.09))
        cut_below(p, s.z - 0.03 - i * 0.022)
        plates.append(p)
    finish(join(plates), "W_Pauldron_" + side, "M_Bronze", bone="upperarm_" + side)

dome = sphere((head.x, head.y + 0.012, head.z + 0.1), (0.136, 0.15, 0.135), 32, 18)
cut_below(dome, head.z + 0.075)
brim = cyl((head.x, head.y + 0.012, head.z + 0.078), 0.15, 0.14, 0.025, seg=32)
neck = cube((head.x, head.y + 0.135, head.z + 0.02), (0.1, 0.022, 0.075), (0.25, 0, 0))
cheeks = [cube((head.x + s * 0.122, head.y - 0.03, head.z + 0.0), (0.012, 0.055, 0.075), (0, s * 0.1, 0)) for s in (-1, 1)]
finish(join([dome, brim, neck] + cheeks), "W_Helmet", "M_Bronze", bone="Head", bevel=0.005)
crest = []
for i in range(17):
    a = math.pi * (i / 16.0) * 0.86 + 0.1
    y = head.y + 0.012 + math.cos(a) * 0.165
    z = head.z + 0.1 + math.sin(a) * 0.165
    crest.append(cube((head.x, y, z), (0.016, 0.022, 0.05), (a - math.pi / 2, 0, 0)))
finish(join(crest), "W_Crest", "M_Plume", bone="Head", bevel=0.004)

bpy.ops.mesh.primitive_grid_add(x_subdivisions=8, y_subdivisions=14, size=1, location=(0, 0.16, chest_z - 0.42), rotation=(math.pi / 2, 0, 0))
cape = bpy.context.active_object
cape.scale = (0.5, 1.15, 1)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
for v in cape.data.vertices:
    t = (chest_z + 0.15 - v.co.z) / 1.15
    v.co.y += t * t * 0.12 + 0.02 * math.sin(v.co.x * 22) * t
    v.co.x *= 0.85 + t * 0.4
finish(cape, "W_Cape", "M_Cloth")
s = cape.modifiers.new("s", "SOLIDIFY")
s.thickness = 0.008
bpy.context.view_layer.objects.active = cape
bpy.ops.object.modifier_apply(modifier="s")
g = cape.vertex_groups.new(name="spine_03")
g.add(range(len(cape.data.vertices)), 1.0, "REPLACE")
m = cape.modifiers.new("Armature", "ARMATURE")
m.object = arm
cape.parent = arm

# ---- SUIKASTCI: koyu deri, baslik, maske ----
carve("A_Tunic", lambda c, w: sum_w(w, TORSO + UPPER + ["pelvis"]) > 0.4 and abs(c.x) < 0.5 and c.z > pelvis_z - 0.2, 0.012, 0.005, "M_DarkLeather")
carve("A_Pants", lambda c, w: sum_w(w, LEGS + ["pelvis"]) > 0.5 and c.z > 0.2, 0.007, 0.004, "M_DarkCloth")
carve("A_Boots", lambda c, w: sum_w(w, FEET + ["calf_l", "calf_r"]) > 0.5 and c.z < 0.36, 0.013, 0.005, "M_Leather")
carve("A_Bracers", lambda c, w: sum_w(w, LOWER) > 0.5, 0.012, 0.005, "M_Leather")
carve("A_Gloves", lambda c, w: hand_w(w) > 0.5, 0.004, 0.002, "M_DarkLeather")
carve("A_Belt", lambda c, w: abs(c.z - (waist - 0.04)) < 0.035 and sum_w(w, TORSO + ["pelvis"]) > 0.5, 0.022, 0.007, "M_Leather")
carve("A_Hood", lambda c, w: sum_w(w, ["Head", "neck_01"]) > 0.5 and not (c.y < head.y - 0.03 and c.z < head.z + 0.115 and c.z > head.z - 0.09 and abs(c.x) < 0.085), 0.05, 0.02, "M_DarkCloth")
carve("A_Mask", lambda c, w: sum_w(w, ["Head", "neck_01"]) > 0.5 and c.y < head.y + 0.04 and c.z < head.z + 0.02, 0.012, 0.004, "M_DarkCloth")
carve("A_Sash", lambda c, w: abs((c.z - chest_z) - (c.x * 1.1)) < 0.045 and sum_w(w, TORSO) > 0.4, 0.02, 0.006, "M_Leather")

# ---- BALYOZCU: ciplak govdeli dev, kurk, deri, boynuzlu miğfer ----
carve("B_Pants", lambda c, w: sum_w(w, LEGS + ["pelvis"]) > 0.5 and c.z > 0.42, 0.012, 0.005, "M_Leather")
carve("B_Boots", lambda c, w: sum_w(w, FEET + ["calf_l", "calf_r"]) > 0.5 and c.z < 0.4, 0.016, 0.006, "M_Fur")
carve("B_Bracers", lambda c, w: sum_w(w, LOWER) > 0.6, 0.012, 0.006, "M_Leather")
carve("B_Gloves", lambda c, w: hand_w(w) > 0.5, 0.005, 0.002, "M_Leather")
carve("B_Belt", lambda c, w: abs(c.z - (waist - 0.07)) < 0.065 and sum_w(w, TORSO + ["pelvis"]) > 0.5, 0.03, 0.01, "M_Bronze")
carve("B_Strap", lambda c, w: abs((c.z - chest_z) + (c.x * 1.1)) < 0.04 and sum_w(w, TORSO) > 0.4, 0.016, 0.006, "M_Leather")
carve("B_Fur", lambda c, w: sum_w(w, ["clavicle_l", "clavicle_r", "spine_03"]) > 0.5 and c.z > chest_z + 0.09 and abs(c.x) < 0.29, 0.05, 0.03, "M_Fur")

dome = sphere((head.x, head.y + 0.01, head.z + 0.1), (0.135, 0.148, 0.13), 32, 18)
cut_below(dome, head.z + 0.07)
band = cyl((head.x, head.y + 0.01, head.z + 0.08), 0.146, 0.142, 0.05, seg=32)
nose = cube((head.x, head.y - 0.15, head.z + 0.04), (0.014, 0.008, 0.055))
finish(join([dome, band, nose]), "B_Helmet", "M_Metal", bone="Head", bevel=0.004)
horns = []
for s in (-1, 1):
    for i in range(7):
        t = i / 6.0
        horns.append(sphere((head.x + s * (0.13 + t * 0.15), head.y + 0.01, head.z + 0.12 + t * t * 0.17), (0.034 * (1 - t * 0.8), 0.034 * (1 - t * 0.8), 0.04), 10, 6))
finish(join(horns), "B_Horns", "M_Bone", bone="Head")
for side, sx in (("l", 1), ("r", -1)):
    s = bone_pos("upperarm_" + side)
    p = sphere((s.x + sx * 0.03, s.y, s.z + 0.01), (0.125, 0.135, 0.095))
    cut_below(p, s.z - 0.02)
    spikes = [cyl((s.x + sx * (0.02 + i * 0.05), s.y + (i - 1) * 0.05, s.z + 0.11), 0.022, 0.0, 0.08, seg=8) for i in range(3)]
    finish(join([p] + spikes), "B_Pauldron_" + side, "M_Metal", bone="upperarm_" + side)

# Kas zirhi gibi kisimlar govdenin ayni yerini ortuyor; gereksiz govde kopyasi yok.
bpy.ops.object.select_all(action="DESELECT")
for o in bpy.data.objects:
    o.select_set(o.type == "MESH" or o.type == "ARMATURE")
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_skins=True, export_animations=False, export_morph=False, export_apply=False, export_yup=True)
print("HERO BITTI", [o.name for o in bpy.data.objects if o.type == "MESH"])

# ---- SILAHLAR: el kemigine sonradan baglanir (Y ekseni boyunca, sap orijinde) ----
for o in list(bpy.data.objects):
    bpy.data.objects.remove(o)


def wpn(o, name, material, bevel=0.003):
    o.name = name
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if bevel > 0.0:
        b = o.modifiers.new("b", "BEVEL")
        b.width = bevel
        b.segments = 2
        b.limit_method = "ANGLE"
        bpy.ops.object.modifier_apply(modifier="b")
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.uv.smart_project(island_margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")
    o.data.materials.clear()
    o.data.materials.append(mat(material))
    return o


def blade(length, width, thick, tip):
    """Ortasi kabarik, ucu sivri kilic agzi: glTF'te +Y uca bakar."""
    verts = [(-width, 0, -thick * 0.2), (width, 0, -thick * 0.2), (width * 0.86, length - tip, -thick * 0.2), (0, length, 0), (-width * 0.86, length - tip, -thick * 0.2), (0, 0, thick), (0, length - tip, thick)]
    verts2 = [(x, y, -z) for x, y, z in verts]
    faces = [(0, 1, 5), (1, 2, 6, 5), (2, 3, 6), (3, 4, 6), (4, 0, 5, 6)]
    all_v = verts + verts2
    all_f = faces + [tuple(i + 7 for i in reversed(f)) for f in faces]
    me = bpy.data.meshes.new("blade")
    me.from_pydata(all_v, [], all_f)
    me.update()
    o = bpy.data.objects.new("blade", me)
    bpy.context.collection.objects.link(o)
    me2 = o.data
    bm = bmesh.new()
    bm.from_mesh(me2)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
    bm.to_mesh(me2)
    bm.free()
    o.rotation_euler = (math.pi / 2, 0, 0)  # Blender'da +Z uca: disari aktarimda +Y olur
    return o


def sword(name, length, width, guard, grip):
    wpn(blade(length, width, 0.009, width * 2.4), name + "_Blade", "M_Steel", 0.0)
    b = bpy.data.objects[name + "_Blade"]
    b.location.z += 0.1
    bpy.context.view_layer.objects.active = b
    bpy.ops.object.select_all(action="DESELECT")
    b.select_set(True)
    bpy.ops.object.transform_apply(location=True)
    wpn(join([cube((0, 0, 0.095), (guard, 0.017, 0.016)), sphere((guard, 0, 0.095), (0.024, 0.024, 0.024), 10, 8), sphere((-guard, 0, 0.095), (0.024, 0.024, 0.024), 10, 8), sphere((0, 0, -grip - 0.015), (0.027, 0.027, 0.027), 12, 8)]), name + "_Guard", "M_Gold", 0.002)
    wpn(cyl((0, 0, -grip / 2 + 0.04), 0.017, 0.015, grip + 0.08, seg=10), name + "_Grip", "M_Leather", 0.0)


sword("Sword", 0.72, 0.038, 0.095, 0.1)
sword("Great", 1.05, 0.044, 0.15, 0.2)
sword("Dagger", 0.34, 0.03, 0.055, 0.075)


def axe():
    """Sakalli savas baltasi: sap +Z, agiz +X yonunde."""
    outline = [(0.02, 0.6), (0.1, 0.6), (0.2, 0.7), (0.25, 0.53), (0.21, 0.36), (0.1, 0.46), (0.02, 0.46)]
    t = 0.014
    verts = [(x, t, z) for x, z in outline] + [(x, -t, z) for x, z in outline]
    n = len(outline)
    faces = [tuple(range(n)), tuple(reversed(range(n, n * 2)))]
    faces += [(i, (i + 1) % n, (i + 1) % n + n, i + n) for i in range(n)]
    me = bpy.data.meshes.new("axe")
    me.from_pydata(verts, [], faces)
    me.update()
    o = bpy.data.objects.new("axe", me)
    bpy.context.collection.objects.link(o)
    bpy.context.view_layer.objects.active = o
    wpn(o, "Axe_Blade", "M_Steel", 0.004)
    wpn(join([cyl((0, 0, 0.53), 0.035, 0.035, 0.17, seg=10), cyl((-0.06, 0, 0.53), 0.0, 0.03, 0.12, (0, -math.pi / 2, 0), seg=8)]), "Axe_Guard", "M_Metal", 0.002)
    wpn(cyl((0, 0, 0.24), 0.018, 0.022, 0.78, seg=10), "Axe_Grip", "M_Wood", 0.0)


axe()

wpn(cyl((0, 0, 0.42), 0.024, 0.03, 1.25, seg=10), "Sledge_Shaft", "M_Wood", 0.0)
head_parts = [cube((0, 0, 1.0), (0.185, 0.09, 0.09)), cube((0.2, 0, 1.0), (0.03, 0.105, 0.105)), cube((-0.2, 0, 1.0), (0.03, 0.105, 0.105))]
wpn(join(head_parts), "Sledge_Head", "M_Metal", 0.012)
wpn(join([cyl((0, 0, z), 0.04, 0.04, 0.03, seg=12) for z in (0.82, 0.9)] + [cube((0, 0, 1.0), (0.1, 0.096, 0.096))]), "Sledge_Band", "M_Bronze", 0.004)

bpy.ops.mesh.primitive_uv_sphere_add(segments=40, ring_count=20, location=(0, 0, 0))
sh = bpy.context.active_object
sh.scale = (0.33, 0.33, 0.09)
wpn(sh, "Shield_Body", "M_Shield", 0.0)
wpn(join([sphere((0, 0, 0.075), (0.09, 0.09, 0.045), 20, 10)] + [cyl((0, 0, 0.03), 0.33, 0.33, 0.012, seg=40)]), "Shield_Boss", "M_Bronze", 0.0)

for o in bpy.data.objects:
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=OUT_W, export_format="GLB", use_selection=True, export_apply=True, export_yup=True)
print("SILAH BITTI", [o.name for o in bpy.data.objects])
