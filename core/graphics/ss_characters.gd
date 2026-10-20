class_name SSCharacters
## Real Shinobi Striker characters, converted locally from the user's game files
## (nsdump glb, see core/graphics/README.md) into res://_ss_local/characters/<id>/<id>.glb
## (git-ignored, never committed). Each GLB carries the SS skeleton, the SS animation clips
## and a <id>.glb.ss.json sidecar describing the SS toon materials (BC / SC palette maps).
## Missing files -> null: ShinobiModel falls back to its primitive body.

const ROOT: String = "res://_ss_local/characters/"
const CHARACTER_SHADER: Shader = preload("res://core/graphics/shaders/ss_character.gdshader")
## Avatar built from the SS character-creation parts (face, body upper/lower, hair).
const DEFAULT_AVATAR: StringName = &"avatar_male"
## Clips that loop.
const LOOPS: Array[StringName] = [&"idle", &"run", &"walk", &"fall", &"guard", &"stunned", &"charge_run", &"concentrate", &"jog"]

static var _scenes: Dictionary = {}
static var _materials: Dictionary = {}


static func model_id(look: ShinobiLook) -> StringName:
	return look.ss_model if look != null and look.ss_model != &"" else DEFAULT_AVATAR


static func scene_for(look: ShinobiLook) -> PackedScene:
	var id: StringName = model_id(look)
	if _scenes.has(id):
		return _scenes[id]
	var path: String = "%s%s/%s.glb" % [ROOT, id, id]
	var scene: PackedScene = load(path) as PackedScene if ResourceLoader.exists(path) else null
	_scenes[id] = scene
	return scene


## Instantiates the SS figure with SS toon materials, looping clips set.
static func instantiate(look: ShinobiLook) -> Node3D:
	# No fixed SS hero: the SS character-creator avatar (real parts and colours).
	if (look == null or look.ss_model == &"") and SSAvatars.available():
		var avatar: Node3D = SSAvatars.instantiate(look.ss_avatar if look != null else {})
		if avatar != null:
			return avatar
	var scene: PackedScene = scene_for(look)
	if scene == null:
		return null
	var id: StringName = model_id(look)
	var root := scene.instantiate() as Node3D
	var mats: Dictionary = _materials_for(id)
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var src: Material = mi.mesh.surface_get_material(i)
			var key: String = src.resource_name if src != null else ""
			if mats.has(key):
				mi.set_surface_override_material(i, mats[key])
	for node: Node in root.find_children("*", "AnimationPlayer", true, false):
		var ap := node as AnimationPlayer
		for clip: StringName in LOOPS:
			if ap.has_animation(clip):
				ap.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	return root


static func _materials_for(id: StringName) -> Dictionary:
	if _materials.has(id):
		return _materials[id]
	var out: Dictionary = {}
	var dir: String = "%s%s/" % [ROOT, id]
	var file := FileAccess.open("%s%s.glb.ss.json" % [dir, id], FileAccess.READ)
	if file != null:
		var data: Variant = JSON.parse_string(file.get_as_text())
		if data is Dictionary:
			for entry: Dictionary in (data as Dictionary).get("materials", []):
				out[entry.name] = material_from(dir, entry)
	_materials[id] = out
	return out


## SS toon material for one sidecar entry (BC / SC palettes, Skin_BC, colour mask).
static func material_from(dir: String, e: Dictionary) -> Material:
	var source: String = e.get("source", "")
	if source.ends_with("M_Line"):
		return SSGraphics.outline_material()  # SS line shell (M_Line): pushed out along normals
	if source == "None" or source == "":
		var hidden := StandardMaterial3D.new()
		hidden.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		hidden.albedo_color = Color(0, 0, 0, 0)
		return hidden
	var m := ShaderMaterial.new()
	m.shader = CHARACTER_SHADER
	m.set_shader_parameter("uc_texture", SSGraphics.uc_texture())
	var bc: Texture2D = _texture(dir, e.get("bc", ""))
	var sc: Texture2D = _texture(dir, e.get("sc", ""))
	m.set_shader_parameter("use_bc_map", bc != null)
	m.set_shader_parameter("use_sc_map", sc != null)
	if bc != null:
		m.set_shader_parameter("bc_map", bc)
	if sc != null:
		m.set_shader_parameter("sc_map", sc)
	var base := Color.WHITE
	if e.has("color"):
		var c: Array = e.color
		base = Color8(int(c[0]), int(c[1]), int(c[2]))
	m.set_shader_parameter("base_color", base)
	var shade: Color = SSGraphics.shade_of(base)
	if e.has("shade"):
		var s: Array = e.shade
		shade = Color8(int(s[0]), int(s[1]), int(s[2]))
	m.set_shader_parameter("shade_color", shade)
	m.set_shader_parameter("alpha_clip", bool(e.get("alpha", false)))
	m.set_shader_parameter("derive_shade", sc == null and bc != null)
	var mask: Texture2D = _texture(dir, e.get("mask", ""))
	m.set_shader_parameter("use_mask", mask != null)
	if mask != null:
		m.set_shader_parameter("mask_map", mask)
	return m


static func _texture(dir: String, rel: String) -> Texture2D:
	if rel == "":
		return null
	var path: String = dir + rel
	return load(path) as Texture2D if ResourceLoader.exists(path) else null
