class_name SSProps
## Real Shinobi Striker environment meshes (buildings, walls, grounds, props), converted
## locally from the user's game files (nsdump glbstatic) into res://_ss_local/env/<set>/
## (git-ignored, never committed). Each <name>.glb is centred on its footprint with its
## base at y = 0; <name>.glb.ss.json gives its size and SS materials (palette BC maps).
## Missing files -> null / false: callers keep their primitive fallback.

const ROOT: String = "res://_ss_local/env/"
const KONOHA: String = "konoha"
const FOREST: String = "forest"
const ENV_SHADER: Shader = preload("res://core/graphics/shaders/ss_character.gdshader")

static var _scenes: Dictionary = {}
static var _info: Dictionary = {}
static var _materials: Dictionary = {}


static func available(name: String, set_name: String = KONOHA) -> bool:
	return _scene(name, set_name) != null


## Footprint / height in metres (x, y, z), Vector3.ZERO when unknown.
static func size_of(name: String, set_name: String = KONOHA) -> Vector3:
	var info: Dictionary = _sidecar(name, set_name)
	var s: Array = info.get("size", [])
	return Vector3(s[0], s[1], s[2]) if s.size() == 3 else Vector3.ZERO


## Instance with SS materials, or null.
static func instance(name: String, set_name: String = KONOHA) -> Node3D:
	var scene: PackedScene = _scene(name, set_name)
	if scene == null:
		return null
	var root := scene.instantiate() as Node3D
	var mats: Dictionary = _materials_for(name, set_name)
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var src: Material = mi.mesh.surface_get_material(i)
			var key: String = src.resource_name if src != null else ""
			if mats.has(key):
				mi.set_surface_override_material(i, mats[key])
	return root


## SS material of one of a mesh's slots (source path ending with `slot`), sampled in world
## space every `tile` metres: real SS grounds on game-sized planes. Null if unavailable.
static func ground_material(mesh_name: String, slot: String, tile: float, set_name: String = KONOHA) -> Material:
	var key: String = "%s/%s/%s/%s" % [set_name, mesh_name, slot, tile]
	if _materials.has(key):
		return _materials[key]
	var result: Material = null
	var mats: Dictionary = _materials_for(mesh_name, set_name)
	for e: Dictionary in _sidecar(mesh_name, set_name).get("materials", []):
		if String(e.get("source", "")).ends_with(slot) and mats.has(e.name):
			var m := (mats[e.name] as ShaderMaterial).duplicate() as ShaderMaterial
			m.set_shader_parameter("world_uv", true)
			m.set_shader_parameter("uv_tile", tile)
			m.set_shader_parameter("uc_scale", 0.25)
			result = m
			break
	_materials[key] = result
	return result


## First mesh of an SS scene with its SS materials baked in (for MultiMesh scatter).
static func mesh(name: String, set_name: String = KONOHA) -> Mesh:
	var key: String = "mesh/%s/%s" % [set_name, name]
	if _materials.has(key):
		return _materials[key]
	var result: Mesh = null
	var inst: Node3D = instance(name, set_name)
	if inst != null:
		var meshes: Array[Node] = inst.find_children("*", "MeshInstance3D", true, false)
		if not meshes.is_empty():
			var mi := meshes[0] as MeshInstance3D
			var copy := mi.mesh.duplicate() as ArrayMesh
			if copy != null:
				for i in copy.get_surface_count():
					var m: Material = mi.get_surface_override_material(i)
					if m != null:
						copy.surface_set_material(i, m)
				result = copy
		inst.free()
	_materials[key] = result
	return result


static func _scene(name: String, set_name: String) -> PackedScene:
	var path: String = "%s%s/%s.glb" % [ROOT, set_name, name]
	if _scenes.has(path):
		return _scenes[path]
	var scene: PackedScene = load(path) as PackedScene if ResourceLoader.exists(path) else null
	_scenes[path] = scene
	return scene


static func _sidecar(name: String, set_name: String) -> Dictionary:
	var path: String = "%s%s/%s.glb.ss.json" % [ROOT, set_name, name]
	if _info.has(path):
		return _info[path]
	var info: Dictionary = {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file != null:
		var data: Variant = JSON.parse_string(file.get_as_text())
		if data is Dictionary:
			info = data
	_info[path] = info
	return info


static func _materials_for(name: String, set_name: String) -> Dictionary:
	var out: Dictionary = {}
	var dir: String = "%s%s/" % [ROOT, set_name]
	for e: Dictionary in _sidecar(name, set_name).get("materials", []):
		var source: String = e.get("source", "")
		if _materials.has(source):
			out[e.name] = _materials[source]
			continue
		var m := ShaderMaterial.new()
		m.shader = ENV_SHADER
		m.set_shader_parameter("uc_texture", SSGraphics.uc_texture())
		m.set_shader_parameter("uc_scale", 1.0)
		m.set_shader_parameter("rim_strength", 0.0)
		var bc: Texture2D = _texture(dir, e.get("bc", ""))
		var sc: Texture2D = _texture(dir, e.get("sc", ""))
		m.set_shader_parameter("use_bc_map", bc != null)
		m.set_shader_parameter("use_sc_map", sc != null)
		if bc != null:
			m.set_shader_parameter("bc_map", bc)
		if sc != null:
			m.set_shader_parameter("sc_map", sc)
		var base := Color(0.7, 0.7, 0.7)
		if e.has("color"):
			var c: Array = e.color
			base = Color8(int(c[0]), int(c[1]), int(c[2]))
		elif bc != null:
			base = Color.WHITE
		m.set_shader_parameter("base_color", base)
		m.set_shader_parameter("shade_color", SSGraphics.shade_of(base))
		m.set_shader_parameter("derive_shade", sc == null and bc != null)
		m.set_shader_parameter("alpha_clip", bool(e.get("alpha", false)))
		if e.has("mix"):
			m.set_shader_parameter("mix_color", Vector3(e.mix[0], e.mix[1], e.mix[2]))
		if e.has("shadow_mix"):
			m.set_shader_parameter("shadow_mix", Vector3(e.shadow_mix[0], e.shadow_mix[1], e.shadow_mix[2]))
		_materials[source] = m
		out[e.name] = m
	return out


static func _texture(dir: String, rel: String) -> Texture2D:
	if rel == "":
		return null
	var path: String = dir + rel
	return load(path) as Texture2D if ResourceLoader.exists(path) else null
