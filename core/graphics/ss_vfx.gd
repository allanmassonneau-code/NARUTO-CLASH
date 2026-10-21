class_name SSVfx
## Shinobi Striker effect sprites for every spell. The flipbooks are the game's own T_EFF_*
## textures (res://_ss_local/vfx). Each technique gets an SS profile (SSVfxProfiles):
## cast burst, projectile body + wake, impact, persistent zone layers, textured tethers.
## Without the textures nothing is spawned and the procedural effects stay alone. Visual only.

const ROOT: String = "res://_ss_local/vfx/"
const SHADER: Shader = preload("res://core/graphics/shaders/ss_vfx.gdshader")
const SHADER_MIX: Shader = preload("res://core/graphics/shaders/ss_vfx_mix.gdshader")
const LINE_SHADER: Shader = preload("res://core/graphics/shaders/ss_vfx_line.gdshader")
const LINE_SHADER_MIX: Shader = preload("res://core/graphics/shaders/ss_vfx_line_mix.gdshader")
## kind -> [texture, flipbook columns, rows]
const KINDS: Dictionary = {
	&"fire": ["fire", 3, 3], &"ember": ["ember", 8, 7], &"smoke": ["smoke2", 2, 2], &"cloud": ["cloud", 1, 1],
	&"lightning": ["lightning", 4, 1], &"water": ["water", 2, 2], &"splash": ["splash", 1, 1],
	&"bubble": ["bubble", 2, 2], &"bubble_big": ["bubble_big", 1, 1], &"wind": ["wind", 1, 1],
	&"blur": ["blur", 1, 1], &"speed": ["speed", 1, 1], &"ring": ["ring", 1, 1], &"ring_thin": ["ring_thin", 1, 1],
	&"rays": ["rays", 1, 1], &"flash": ["flash", 1, 1], &"comic": ["comic", 1, 1], &"glint": ["glint", 1, 1],
	&"glow": ["glow", 1, 1], &"orb": ["orb", 1, 1], &"shell": ["shell", 1, 1], &"shock": ["shock", 1, 1],
	&"spikes": ["spikes", 2, 2], &"shards": ["shards", 2, 2], &"rock": ["rock", 2, 2], &"dust": ["dust", 1, 1],
	&"sand": ["sand", 2, 2], &"ice": ["ice", 1, 1], &"ink": ["ink", 4, 3], &"crack": ["crack", 1, 1],
	&"magma": ["magma", 1, 1], &"seal": ["seal", 4, 1], &"seal_strip": ["seal_strip", 1, 1],
	&"chakra_flame": ["chakra_flame", 4, 4], &"glow_soft": ["glow_soft", 1, 1], &"orb_soft": ["orb_soft", 1, 1],
}
## Matter (not light): alpha-blended instead of additive. Dark tints are always alpha-blended.
const MATTER: Array[StringName] = [&"smoke", &"cloud", &"rock", &"dust", &"sand", &"ink", &"spikes", &"crack", &"shards"]

static var _materials: Dictionary = {}
static var _quad: QuadMesh


static func available() -> bool:
	return CombatFx.is_enabled() and ResourceLoader.exists(ROOT + "fire.png")


## Element of a colour, for effects without a technique (legacy hit bursts).
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


# --- Technique hooks ---------------------------------------------------------------------

## Cast burst on the caster's hand + aura for self-buffs.
static func tech_cast(t: Tk) -> void:
	if not available() or t == null or t.caster == null or not t.caster.is_inside_tree():
		return
	var p: Dictionary = SSVfxProfiles.profile(t.id)
	var hand: Vector3 = t.caster.global_position + Vector3.UP * 1.1 + t.dir * 0.6
	play_layers(t.caster, p.cast, hand, p.scale, p.color)
	if p.aura:
		play_layers(t.caster, [["rays", 1.3, 1, 0.5], ["shock@flat", 1.6, 1, 0.4]], t.caster.global_position + Vector3.UP * 1.0, p.scale, p.color)


## Impact layers of a technique effect. Returns true when SS replaces the procedural shape.
static func tech_effect(id: StringName, anchor: Node, effect: String, ground: Vector3, radius: float) -> bool:
	if not available() or anchor == null or not anchor.is_inside_tree():
		return false
	var p: Dictionary = SSVfxProfiles.profile(id)
	var size: float = maxf(radius, 0.6) * float(p.impact_scale) * 0.7
	play_layers(anchor, p.impact, ground + Vector3.UP * 0.7, size, p.color)
	return effect in ["burst", "explosion", "ember", "smoke", "dust", "sparks", "bolt", "rocks"]


## SS body of a technique projectile (replaces the glowing sphere), or null.
static func projectile_body(proj: Node3D, id: StringName, size: float) -> Node3D:
	if not available():
		return null
	var p: Dictionary = SSVfxProfiles.profile(id)
	var root := Node3D.new()
	var s: float = maxf(size, 0.25) * 3.2 * float(p.trail_scale) * p.scale
	var first: bool = true
	for layer: Array in p.trail:
		loop(root, layer[0], Vector3.ZERO, s * float(layer[1]) * (1.0 if first else 0.8), p.color)
		first = false
	# Wake: one sprite left behind every few frames.
	var wake := Timer.new()
	wake.wait_time = 0.07
	wake.autostart = true
	var layer0: Array = p.trail[0]
	wake.timeout.connect(func() -> void:
		if is_instance_valid(proj) and proj.is_inside_tree():
			sprite(proj, layer0[0], proj.global_position, s * float(layer0[1]) * 0.7, Color(p.color, 0.7), 0.35, false, 0.0, 1.3))
	root.add_child(wake)
	return root


## SS layers on a persistent technique object (zones, walls, pillars, orbs).
static func object_layers(o: KitObject, visual: Node3D) -> bool:
	if not available() or o == null:
		return false
	var p: Dictionary = SSVfxProfiles.profile(o.technique_id)
	var r: float = maxf(o.radius, 0.6) * float(p.zone_scale)
	for layer: Array in p.zone:
		var kind: String = layer[0]
		var flat: bool = kind.ends_with("@flat")
		var k: StringName = StringName(kind.trim_suffix("@flat"))
		var n: int = int(layer[2])
		for i in n:
			var a: float = TAU * i / maxf(n, 1)
			var off := Vector3.ZERO if (flat or n == 1) else Vector3(cos(a), 0.0, sin(a)) * r * 0.6
			var y: float = 0.06 if flat else 0.8
			loop(visual, k, off + Vector3.UP * y, (r * 2.0 if flat else r * float(layer[1])) * (float(layer[1]) if flat else 1.0), p.color, flat)
	return true


## Textured material for a technique tether / thread / chain, or null.
static func line_material(id: StringName) -> Material:
	if not available():
		return null
	var p: Dictionary = SSVfxProfiles.profile(id)
	var key: String = "line/%s/%s" % [p.line, p.color.to_html()]
	if _materials.has(key):
		return _materials[key]
	var tex: String = ROOT + str(p.line) + ".png"
	var m: ShaderMaterial = null
	if ResourceLoader.exists(tex):
		m = ShaderMaterial.new()
		m.shader = LINE_SHADER_MIX if (p.color as Color).get_luminance() < 0.35 else LINE_SHADER
		m.set_shader_parameter("pattern", load(tex))
		m.set_shader_parameter("tint", p.color)
	_materials[key] = m
	return m


# --- Named spells (characters' AbilityData.vfx) and generic effects ------------------------

static func for_spell(anchor: Node, vfx: StringName, at: Vector3, color: Color, active: bool) -> void:
	if not available():
		return
	var id: StringName = {&"rasengan": &"sub_s_sphere_spirale", &"rasenshuriken": &"sub_s_sphere_spirale",
		&"chidori": &"raiton_c", &"raikiri": &"raiton_c", &"kirin": &"raiton_s", &"katon": &"katon_c",
		&"fire_zone": &"katon_b", &"black_fire": &"katon_b", &"shunshin": &"sub_b_shunshin", &"leap": &"sub_b_shunshin",
		&"clone": &"sub_b_clone", &"kamui": &"sub_b_voile", &"flash": &"sub_s_hiraishin", &"sand_coffin": &"clan_sabaku_b",
		&"sand_tsunami": &"clan_sabaku_a", &"stomp": &"doton_c", &"okasho": &"doton_c", &"crater": &"doton_a",
		&"heal": &"sub_b_absorption", &"byakugou": &"sub_a_huit_portes", &"susanoo": &"clan_uchiha_s_susanoo",
		&"shadow": &"clan_nara_d", &"kaiten": &"futon_b", &"gentle_fist": &"sub_b_paume_d_absorption"}.get(vfx, &"")
	if id == &"":
		if active:
			burst(anchor, element(color), at, 0.8, color, 3)
		return
	var p: Dictionary = SSVfxProfiles.profile(id)
	var c: Color = Color(0.1, 0.05, 0.1) if vfx == &"black_fire" else p.color
	play_layers(anchor, p.impact if active else p.cast, at, p.scale, c)


## SS layer for KitVisuals.fx without a technique id (colour-coded).
static func for_effect(anchor: Node, effect: String, ground: Vector3, radius: float, color: Color) -> void:
	if not available():
		return
	burst(anchor, element(color), ground + Vector3.UP * 0.8, maxf(radius, 0.6), color, 4)


# --- Primitives --------------------------------------------------------------------------

## Plays profile layers [kind(@flat), size, count, life] at a point.
static func play_layers(anchor: Node, layers: Array, at: Vector3, scale: float, color: Color) -> void:
	for layer: Array in layers:
		var kind: String = layer[0]
		var flat: bool = kind.ends_with("@flat")
		var k: StringName = StringName(kind.trim_suffix("@flat"))
		var size: float = float(layer[1]) * scale
		var n: int = int(layer[2])
		var life: float = maxf(float(layer[3]), 0.2)
		for i in n:
			var off := Vector3.ZERO if n == 1 or flat else Vector3(randf_range(-1, 1), randf_range(-0.2, 0.6), randf_range(-1, 1)) * size * 0.45
			var p: Vector3 = Vector3(at.x, 0.06, at.z) if flat else at + off
			sprite(anchor, k, p, size * (1.0 if n == 1 else randf_range(0.75, 1.15)), color, life * randf_range(0.85, 1.15), flat, 0.0 if flat else size * 0.3)


static func burst(anchor: Node, kind: StringName, at: Vector3, radius: float, color: Color, count: int = 5, life: float = 0.55) -> void:
	play_layers(anchor, [[String(kind), radius, count, life]], at, 1.0, color)


## One animated sprite (frees itself). `flat` lays it on the ground.
static func sprite(anchor: Node, kind: StringName, at: Vector3, size: float, color: Color, life: float,
		flat: bool = false, rise: float = 0.0, grow: float = 1.6) -> void:
	if not available() or anchor == null or not anchor.is_inside_tree():
		return
	var mi: MeshInstance3D = _quad_instance(kind, flat, color)
	if mi == null:
		return
	var root: Node = anchor.get_parent() if anchor.get_parent() != null else anchor
	root.add_child(mi)
	mi.global_position = at
	mi.scale = Vector3.ONE * size
	var frames: int = _frames(kind)
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


## Looping sprite attached to `parent` (lives as long as it): projectile bodies, zones.
static func loop(parent: Node3D, kind: StringName, local: Vector3, size: float, color: Color, flat: bool = false) -> void:
	var mi: MeshInstance3D = _quad_instance(kind, flat, color)
	if mi == null:
		return
	parent.add_child(mi)
	mi.position = local
	mi.scale = Vector3.ONE * size
	var frames: int = _frames(kind)
	var period: float = 0.12 * frames if frames > 1 else 1.6
	var spin0: float = randf() * TAU
	var tween := mi.create_tween().set_loops()
	tween.tween_method(func(t: float) -> void:
		if not is_instance_valid(mi):
			return
		mi.set_instance_shader_parameter("frame", t * frames)
		mi.set_instance_shader_parameter("spin", spin0 + t * TAU * (0.25 if flat else 0.5))
		mi.set_instance_shader_parameter("fade", 0.85 + 0.15 * sin(t * TAU)), 0.0, 1.0, period)


static func _quad_instance(kind: StringName, flat: bool, color: Color) -> MeshInstance3D:
	var mat: Material = _material(kind, flat, color.get_luminance() < 0.3)
	if mat == null:
		return null
	if _quad == null:
		_quad = QuadMesh.new()
	var mi := MeshInstance3D.new()
	mi.mesh = _quad
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if flat:
		mi.rotation_degrees.x = -90.0
	mi.set_instance_shader_parameter("tint", color)
	return mi


static func _frames(kind: StringName) -> int:
	var info: Array = KINDS.get(kind, ["", 1, 1])
	return int(info[1]) * int(info[2])


static func _material(kind: StringName, flat: bool, dark: bool = false) -> Material:
	var key: String = "%s/%s/%s" % [kind, flat, dark]
	if _materials.has(key):
		return _materials[key]
	var m: ShaderMaterial = null
	var info: Array = KINDS.get(kind, [])
	var path: String = ROOT + str(info[0]) + ".png" if not info.is_empty() else ""
	if path != "" and ResourceLoader.exists(path):
		m = ShaderMaterial.new()
		m.shader = SHADER_MIX if MATTER.has(kind) or dark else SHADER
		m.set_shader_parameter("flipbook", load(path))
		m.set_shader_parameter("grid", Vector2i(int(info[1]), int(info[2])))
		m.set_shader_parameter("billboard", not flat)
		if flat and not MATTER.has(kind) and not dark:
			m.set_shader_parameter("emission", 0.7)   # big ground layers: no white-out
	_materials[key] = m
	return m
