class_name SSVfx
## Shinobi Striker effect sprites layered on the game's spell / hit effects. The flipbooks are
## the game's own T_EFF_* textures, extracted locally to res://_ss_local/vfx (git-ignored).
## Without them nothing is spawned and the procedural effects stay alone. Visual only.

const ROOT: String = "res://_ss_local/vfx/"
const SHADER: Shader = preload("res://core/graphics/shaders/ss_vfx.gdshader")
const SHADER_MIX: Shader = preload("res://core/graphics/shaders/ss_vfx_mix.gdshader")
## Matter (not light): alpha-blended instead of additive.
const MATTER: Array[StringName] = [&"smoke", &"rock", &"dust"]
## kind -> [texture, flipbook columns, rows]
const KINDS: Dictionary = {
	&"fire": ["fire", 3, 3], &"smoke": ["smoke2", 2, 2], &"lightning": ["lightning", 4, 1],
	&"water": ["water", 2, 2], &"wind": ["wind", 1, 1], &"ring": ["ring", 1, 1],
	&"shock": ["shock", 1, 1], &"rock": ["rock", 2, 2], &"dust": ["dust", 1, 1],
}

static var _materials: Dictionary = {}
static var _quad: QuadMesh


static func available() -> bool:
	return CombatFx.is_enabled() and ResourceLoader.exists(ROOT + "fire.png")


## Element of a technique colour (natures are colour-coded in the game data).
static func element(color: Color) -> StringName:
	if color.s < 0.18:
		return &"smoke" if color.v < 0.75 else &"lightning"
	var h: float = color.h
	if h < 0.09 or h > 0.92:
		return &"fire"
	if h < 0.2:
		return &"lightning" if color.v > 0.8 else &"rock"
	if h < 0.45:
		return &"wind"
	if h < 0.72:
		return &"water"
	return &"smoke"


## One animated sprite. `flat` lays it on the ground (rings, shock waves).
static func sprite(anchor: Node, kind: StringName, at: Vector3, size: float, color: Color, life: float,
		flat: bool = false, rise: float = 0.0, grow: float = 1.6) -> void:
	if not available() or anchor == null or not anchor.is_inside_tree():
		return
	var mat: Material = _material(kind, flat)
	if mat == null:
		return
	if _quad == null:
		_quad = QuadMesh.new()
	var mi := MeshInstance3D.new()
	mi.mesh = _quad
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var root: Node = anchor.get_parent() if anchor.get_parent() != null else anchor
	root.add_child(mi)
	mi.global_position = at
	if flat:
		mi.rotation_degrees.x = -90.0
	mi.scale = Vector3.ONE * size
	mi.set_instance_shader_parameter("tint", color)
	var info: Array = KINDS[kind]
	var frames: int = int(info[1]) * int(info[2])
	var spin0: float = randf() * TAU
	var tween := mi.create_tween()
	tween.tween_method(func(t: float) -> void:
		if not is_instance_valid(mi):
			return
		mi.set_instance_shader_parameter("frame", t * frames)
		mi.set_instance_shader_parameter("fade", 1.0 - t * t)
		mi.set_instance_shader_parameter("spin", spin0 + t * 1.2)
		mi.scale = Vector3.ONE * size * lerpf(1.0, grow, t)
		mi.global_position = at + Vector3.UP * rise * t, 0.0, 1.0, life)
	tween.tween_callback(mi.queue_free)


## Cluster of sprites of one kind around a point.
static func burst(anchor: Node, kind: StringName, at: Vector3, radius: float, color: Color, count: int = 5, life: float = 0.55) -> void:
	if not available():
		return
	for i in count:
		var off := Vector3(randf_range(-1, 1), randf_range(0.0, 0.8), randf_range(-1, 1)) * radius * 0.5
		sprite(anchor, kind, at + off, radius * randf_range(0.7, 1.2), color, life * randf_range(0.8, 1.2), false, radius * 0.4)


## SS layer for the generic technique effects (KitVisuals.fx) and hit bursts.
static func for_effect(anchor: Node, effect: String, ground: Vector3, radius: float, color: Color) -> void:
	if not available():
		return
	var el: StringName = element(color)
	var r: float = maxf(radius, 0.6)
	match effect:
		"explosion", "burst", "ember":
			burst(anchor, el, ground + Vector3.UP * 0.8, r, color, 6)
			sprite(anchor, &"shock", ground + Vector3.UP * 0.05, r * 1.4, color, 0.35, true, 0.0, 2.2)
			burst(anchor, &"smoke", ground + Vector3.UP * 0.6, r, Color(0.75, 0.72, 0.7, 0.55), 3, 0.9)
		"wave", "ring", "dust":
			sprite(anchor, &"ring", ground + Vector3.UP * 0.05, r * 2.0, color, 0.45, true, 0.0, 1.5)
			burst(anchor, &"smoke", ground + Vector3.UP * 0.3, r * 0.8, Color(0.8, 0.75, 0.68, 0.5), 4, 0.8)
		"spikes", "rocks", "cracks", "column":
			burst(anchor, &"rock", ground + Vector3.UP * 0.5, r, Color(0.85, 0.75, 0.6), 5, 0.6)
			burst(anchor, &"smoke", ground + Vector3.UP * 0.3, r, Color(0.7, 0.62, 0.52, 0.55), 3, 0.9)
		"bolt", "sparks":
			burst(anchor, &"lightning", ground + Vector3.UP * 1.0, r, color.lightened(0.3), 4, 0.35)
		"smoke", "crows", "implosion", "spheres":
			burst(anchor, &"smoke", ground + Vector3.UP * 0.7, r, Color(0.85, 0.85, 0.88, 0.7), 6, 0.9)
		_:
			burst(anchor, el, ground + Vector3.UP * 0.8, r, color, 4)


## Signature SS layer for the named spells (SpellVfx ids).
static func for_spell(anchor: Node, vfx: StringName, at: Vector3, color: Color, active: bool) -> void:
	if not available():
		return
	match vfx:
		&"rasengan", &"rasenshuriken":
			sprite(anchor, &"wind", at, 0.9 if active else 0.6, Color(0.55, 0.8, 1.0), 0.5, false, 0.0, 1.3)
		&"chidori", &"raikiri", &"kirin":
			burst(anchor, &"lightning", at, 0.7, Color(0.75, 0.9, 1.0), 3, 0.3)
		&"katon", &"fire_zone", &"black_fire":
			burst(anchor, &"fire", at, 1.2 if active else 0.6, Color(0.1, 0.05, 0.1) if vfx == &"black_fire" else Color(1.0, 0.55, 0.15), 6)
		&"shunshin", &"leap", &"clone", &"kamui", &"flash":
			burst(anchor, &"smoke", at, 0.9, Color(0.9, 0.9, 0.92, 0.75), 5, 0.8)
		&"sand_coffin", &"sand_tsunami", &"stomp", &"okasho", &"crater":
			burst(anchor, &"rock", at, 1.2, Color(0.9, 0.8, 0.6), 5)
			burst(anchor, &"smoke", at, 1.2, Color(0.8, 0.7, 0.55, 0.6), 4, 0.9)
		&"heal", &"byakugou":
			sprite(anchor, &"ring", at, 2.0, Color(0.4, 1.0, 0.6), 0.6, true)
		_:
			if active:
				burst(anchor, element(color), at, 0.8, color, 3)


static func _material(kind: StringName, flat: bool) -> Material:
	var key: String = "%s/%s" % [kind, flat]
	if _materials.has(key):
		return _materials[key]
	var m: ShaderMaterial = null
	var info: Array = KINDS.get(kind, [])
	var path: String = ROOT + str(info[0]) + ".png" if not info.is_empty() else ""
	if path != "" and ResourceLoader.exists(path):
		m = ShaderMaterial.new()
		m.shader = SHADER_MIX if MATTER.has(kind) else SHADER
		m.set_shader_parameter("flipbook", load(path))
		m.set_shader_parameter("grid", Vector2i(int(info[1]), int(info[2])))
		m.set_shader_parameter("billboard", not flat)
	_materials[key] = m
	return m
