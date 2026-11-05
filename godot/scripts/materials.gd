class_name Mats
## Tum karakter ve silah malzemeleri: Poly Haven CC0 dokulari. Her renk bir kez uretilir ve paylasilir.

const DIR := "res://assets/pbr/%s_%s.jpg"
const RECIPES := {
	"M_Bronze": {"tex": "metal", "tint": Color(1.0, 0.68, 0.34), "metal": 1.0, "rough": 0.55, "uv": 2.5},
	"M_Metal": {"tex": "metal", "tint": Color(0.75, 0.76, 0.8), "metal": 1.0, "rough": 0.6, "uv": 2.0},
	"M_Steel": {"tex": "metal", "tint": Color(0.95, 0.96, 1.0), "metal": 1.0, "rough": 0.3, "uv": 1.0},
	"M_Gold": {"tex": "metal", "tint": Color(1.0, 0.72, 0.28), "metal": 1.0, "rough": 0.5, "uv": 3.0},
	"M_Leather": {"tex": "leather", "tint": Color(0.92, 0.82, 0.72), "metal": 0.0, "rough": 1.0, "uv": 4.0},
	"M_DarkLeather": {"tex": "leather", "tint": Color(0.42, 0.42, 0.48), "metal": 0.0, "rough": 1.0, "uv": 4.0},
	"M_DarkCloth": {"tex": "leather", "tint": Color(0.27, 0.32, 0.34), "metal": 0.0, "rough": 1.0, "uv": 6.0},
	"M_Cloth": {"tex": "leather", "tint": Color(1, 1, 1), "metal": 0.0, "rough": 0.9, "uv": 5.0},
	"M_Plume": {"tex": "leather", "tint": Color(1.0, 0.75, 0.7), "metal": 0.0, "rough": 0.9, "uv": 3.0},
	"M_Fur": {"tex": "leather", "tint": Color(0.36, 0.25, 0.17), "metal": 0.0, "rough": 1.0, "uv": 14.0},
	"M_Bone": {"tex": "marble", "tint": Color(0.92, 0.86, 0.72), "metal": 0.0, "rough": 0.6, "uv": 1.0},
	"M_Wood": {"tex": "wood", "tint": Color(0.75, 0.55, 0.4), "metal": 0.0, "rough": 0.8, "uv": 1.0},
	"M_Shield": {"tex": "wood", "tint": Color(0.75, 0.2, 0.15), "metal": 0.0, "rough": 0.6, "uv": 1.5},
	# Sketchfab zirhlarinin yaninda: koyu demir ve is kararmis ahsap (kullanici: kirmizi kalkan, turuncu sap goze batiyor)
	"M_IronDark": {"tex": "metal", "tint": Color(0.5, 0.51, 0.55), "metal": 1.0, "rough": 0.45, "uv": 2.0},
	"M_WoodDark": {"tex": "wood", "tint": Color(0.3, 0.22, 0.17), "metal": 0.0, "rough": 0.85, "uv": 1.0},
	"M_SteelDark": {"tex": "metal", "tint": Color(0.7, 0.72, 0.76), "metal": 1.0, "rough": 0.32, "uv": 1.0},
	# Berserker baltasi (kullanici: "gorunumu kotu"): ayna gibi celik karanlik arenayi yansitip DUZ SIYAH gorunuyordu.
	# Dovme celik: daha az ayna, doku ve isik okunur; sap deri sarili.
	"M_AxeSteel": {"tex": "metal", "tint": Color(1.35, 1.35, 1.4), "metal": 0.45, "rough": 0.36, "uv": 2.5},
	"M_AxeGrip": {"tex": "leather", "tint": Color(0.55, 0.38, 0.28), "metal": 0.0, "rough": 0.7, "uv": 3.0},
}

static var _cache := {}


static func get_mat(id: String, tint: Color = Color.WHITE, glow: float = 0.0) -> StandardMaterial3D:
	var key := "%s|%s|%.2f" % [id, tint.to_html(), glow]
	if _cache.has(key):
		return _cache[key]
	var r: Dictionary = RECIPES[id]
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(DIR % [r["tex"], "albedo"])
	m.albedo_color = Color(r["tint"]) * tint
	m.normal_enabled = true
	m.normal_texture = load(DIR % [r["tex"], "normal"])
	m.normal_scale = 0.55
	var rough_path: String = DIR % [r["tex"], "rough"]
	if ResourceLoader.exists(rough_path):
		m.roughness_texture = load(rough_path)
	m.roughness = r["rough"]
	m.metallic = r["metal"]
	if float(r["metal"]) < 0.5: # mat yuzeylerde kenar kirpismasi olmasin
		m.normal_scale = 0.3
		m.metallic_specular = 0.25
	m.uv1_scale = Vector3.ONE * float(r["uv"])
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = tint
		m.emission_energy_multiplier = glow
	_cache[key] = m
	return m
