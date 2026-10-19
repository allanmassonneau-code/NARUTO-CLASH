class_name CharacterPresentation
extends Node
## Reads gameplay state and mirrors it visually. Never drives the simulation.

enum Role { LOCAL_PLAYER, ALLY, ENEMY }

const ROLE_COLORS: Array[Color] = [Color(0.3, 1.0, 0.4), Color(0.3, 0.6, 1.0), Color(1.0, 0.25, 0.2)]

@export var model: ShinobiModel
@export var visual_pivot: Node3D
@export var overhead: Label3D
@export var counter_bubble: MeshInstance3D
@export var cast_indicator: MeshInstance3D
@export var team_ring: MeshInstance3D

var _character: CombatCharacter
var _flash: float = 0.0
var _last_health: float = 0.0
var _cast_mesh := ImmediateMesh.new()
var _enabled: bool = true
var _role: Role = Role.ENEMY
var _hp_fill: Sprite3D
var _hp_recoverable: Sprite3D
var _hp_bar_texture: ImageTexture
var _cast_back: Sprite3D
var _cast_fill: Sprite3D
## Small damage (burn, drain, ring) is summed and shown as one number.
var _dot_pending: float = 0.0
var _dot_timer: float = 0.0
var _was_stunned: bool = false
var _was_dead: bool = false
var _was_immaterial: bool = false

const BAR_WIDTH_PX: int = 120
const BAR_HEIGHT_PX: int = 12
const BAR_HEIGHT: float = 2.55


func setup(character: CombatCharacter) -> void:
	_character = character
	_enabled = CombatFx.is_enabled()
	_last_health = character.health.current_health
	if not _enabled:
		return
	model.build(character.data.look if character.data.look != null else ShinobiLook.new())
	cast_indicator.top_level = true
	cast_indicator.mesh = _cast_mesh
	var line_mat := StandardMaterial3D.new()
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.vertex_color_use_as_albedo = true
	line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	line_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cast_indicator.material_override = line_mat
	_build_health_bar()
	set_role(Role.ENEMY if character.team != 0 else Role.ALLY)


func set_role(role: Role) -> void:
	_role = role
	if not _enabled:
		return
	_hp_fill.modulate = ROLE_COLORS[role]
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = ROLE_COLORS[role]
	team_ring.material_override = mat
	overhead.modulate = ROLE_COLORS[role].lightened(0.5)


func _process(delta: float) -> void:
	if _character == null or not _enabled:
		return
	var hp: float = _character.health.current_health
	if hp < _last_health - 0.01:
		var lost: float = _last_health - hp
		if lost >= 2.5:
			_on_damaged(lost)
		else:
			_dot_pending += lost
	_last_health = hp
	_dot_timer -= delta
	if _dot_pending > 0.0 and (_dot_pending >= 3.0 or _dot_timer <= 0.0):
		CombatFx.damage_number(_character, _character.global_position + Vector3.UP * 2.3, maxf(_dot_pending, 1.0), Color(1.0, 0.55, 0.3))
		_flash = 0.06
		_dot_pending = 0.0
		_dot_timer = 0.5
	_update_health_bar()
	_flash = maxf(0.0, _flash - delta)
	_audio_cues()

	var status: StatusController = _character.status
	var abilities: AbilityController = _character.abilities
	var tint := Color(1, 1, 1, 0)
	var fade: float = 0.0
	var pose: StringName = &""
	if _character.is_dead():
		tint = Color(0.1, 0.1, 0.1, 0.6)
	elif status.has_status(StatusController.Type.STUN):
		tint = Color(1.0, 0.9, 0.2, 0.45)
		pose = &"stunned:"
	elif status.has_status(StatusController.Type.ROOT):
		tint = Color(0.4, 0.3, 0.15, 0.35)
	elif status.has_status(StatusController.Type.EMPOWER):
		tint = Color(0.75, 0.3, 1.0, 0.2 + 0.1 * sin(Time.get_ticks_msec() * 0.01))
	elif status.has_status(StatusController.Type.SLOW):
		tint = Color(0.3, 0.5, 1.0, 0.25)
	if status.has_status(StatusController.Type.IMMATERIAL):
		fade = 0.65
	if abilities.is_casting() and pose == &"":
		var a: AbilityData = abilities.current
		var anim: String = String(a.anim) if a.anim != &"" else _default_anim(a)
		if abilities.phase == AbilityController.Phase.STARTUP:
			pose = StringName(anim + ":windup")
			tint = Color(a.color, 0.18)
		else:
			pose = StringName(anim + ":strike")
	_track_spell(delta)
	if _flash > 0.0:
		tint = Color(1.0, 0.15, 0.15, 0.6)
	var planar_speed: float = Vector2(_character.velocity.x, _character.velocity.z).length()
	model.animate(delta, planar_speed, pose, tint, fade)
	visual_pivot.rotation.x = deg_to_rad(-85.0) if _character.is_dead() else 0.0
	visual_pivot.position.y = 0.25 if _character.is_dead() else 0.0
	team_ring.visible = not _character.is_dead()
	counter_bubble.visible = status.has_status(StatusController.Type.COUNTER)
	_update_overhead()
	_update_cast_indicator()


## Hit feedback: flash, hitstop, damage number, sparks, camera shake.
func _on_damaged(amount: float) -> void:
	_flash = 0.12
	var heavy: bool = amount >= 15.0
	model.hitstop(0.09 if heavy else 0.05)
	Sfx.play(&"hit_heavy" if heavy else &"hit", _character.global_position, 0.0 if _role == Role.LOCAL_PLAYER else -2.0)
	var at: Vector3 = _character.global_position
	CombatFx.damage_number(_character, at + Vector3.UP * 2.3, amount, Color(1.0, 0.85, 0.3) if heavy else Color.WHITE)
	CombatFx.burst(_character, at + Vector3.UP * 1.0, Color(1.0, 0.9, 0.6), 0.9 if heavy else 0.6)
	var camera := get_viewport().get_camera_3d() as ArenaCamera
	if camera != null:
		if _role == Role.LOCAL_PLAYER:
			camera.shake(0.35 if heavy else 0.18)
		elif heavy:
			camera.shake(0.12)


func _build_health_bar() -> void:
	var image := Image.create(BAR_WIDTH_PX, BAR_HEIGHT_PX, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	_hp_bar_texture = ImageTexture.create_from_image(image)
	var back := _bar_sprite(Color(0.05, 0.05, 0.08, 0.85), 0)
	back.scale = Vector3(1.04, 1.4, 1.0)
	_hp_recoverable = _bar_sprite(Color(0.85, 0.85, 0.85, 0.55), 1)
	_hp_fill = _bar_sprite(Color.WHITE, 2)
	_cast_back = _bar_sprite(Color(0.05, 0.05, 0.08, 0.85), 0)
	_cast_back.scale = Vector3(0.8, 0.7, 1.0)
	_cast_back.position.y = BAR_HEIGHT - 0.17
	_cast_fill = _bar_sprite(Color.WHITE, 1)
	_cast_fill.scale = Vector3(0.78, 0.45, 1.0)
	_cast_fill.position.y = BAR_HEIGHT - 0.17


func _bar_sprite(color: Color, priority: int) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture = _hp_bar_texture
	sprite.pixel_size = 0.01
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.no_depth_test = true
	sprite.shaded = false
	sprite.modulate = color
	sprite.render_priority = priority
	sprite.centered = false
	sprite.offset = Vector2(-BAR_WIDTH_PX / 2.0, -BAR_HEIGHT_PX / 2.0)
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0, 0, BAR_WIDTH_PX, BAR_HEIGHT_PX)
	sprite.position = Vector3(0, BAR_HEIGHT, 0)
	_character.add_child(sprite)
	return sprite


func _update_health_bar() -> void:
	var health: HealthComponent = _character.health
	var alive: bool = not _character.is_dead()
	_hp_fill.visible = alive
	_hp_recoverable.visible = alive
	var w: float = BAR_WIDTH_PX * clampf(health.current_health / health.max_health, 0.0, 1.0)
	var w_rec: float = BAR_WIDTH_PX * clampf((health.current_health + health.recoverable_health) / health.max_health, 0.0, 1.0)
	_hp_fill.region_rect = Rect2(0, 0, maxf(w, 0.01), BAR_HEIGHT_PX)
	_hp_recoverable.region_rect = Rect2(0, 0, maxf(w_rec, 0.01), BAR_HEIGHT_PX)
	# Cast bar (others only; the local player has the HUD cast bar).
	var abilities: AbilityController = _character.abilities
	var casting: bool = alive and _role != Role.LOCAL_PLAYER and abilities.phase == AbilityController.Phase.STARTUP \
		and abilities.current.startup_time >= 0.25
	_cast_back.visible = casting
	_cast_fill.visible = casting
	if casting:
		var progress: float = clampf(abilities.phase_elapsed / abilities.current.startup_time, 0.0, 1.0)
		_cast_fill.region_rect = Rect2(0, 0, maxf(BAR_WIDTH_PX * progress, 0.01), BAR_HEIGHT_PX)
		_cast_fill.modulate = abilities.current.color.lightened(0.3)


func _default_anim(a: AbilityData) -> String:
	match a.kind:
		AbilityData.Kind.COUNTER:
			return "guard"
		AbilityData.Kind.SELF_HEAL:
			return "heal"
		AbilityData.Kind.DASH:
			return "dash"
		AbilityData.Kind.PROJECTILE:
			return "throw"
		AbilityData.Kind.GROUND_AREA, AbilityData.Kind.SUMMON_CLONE:
			return "seal"
		AbilityData.Kind.TELEPORT:
			return "dash"
	return "jab"


## Spell effects follow the cast phases (works for local, server-mirrored
## and puppet fighters since it only reads the synced cast state).
var _spell_ability: AbilityData
var _spell_phase: int = AbilityController.Phase.IDLE
var _spell_held: Node3D
var _afterimage_timer: float = 0.0


func _track_spell(delta: float) -> void:
	var abilities: AbilityController = _character.abilities
	var a: AbilityData = abilities.current
	var phase: int = abilities.phase
	if a != _spell_ability:
		if _spell_ability != null:
			# Previous cast ended (finished, cancelled or interrupted).
			var interrupted: bool = _spell_phase == AbilityController.Phase.STARTUP
			SpellVfx.on_end(_character, _spell_ability, _spell_held, interrupted)
			_spell_held = null
		_spell_ability = a
		_spell_phase = AbilityController.Phase.IDLE
		if a != null and phase == AbilityController.Phase.STARTUP:
			_spell_held = SpellVfx.on_startup(_character, a, model)
			_cast_sound(a, phase)
	if a == null:
		_spell_phase = phase
		return
	if phase != _spell_phase:
		if _spell_phase == AbilityController.Phase.IDLE and phase != AbilityController.Phase.STARTUP and _spell_held == null:
			_spell_held = SpellVfx.on_startup(_character, a, model)  # startup was too short to observe
		if phase == AbilityController.Phase.ACTIVE:
			SpellVfx.on_active(_character, a, _spell_held)
			_cast_sound(a, phase)
		if phase == AbilityController.Phase.RECOVERY and _spell_phase == AbilityController.Phase.ACTIVE:
			SpellVfx.on_end(_character, a, _spell_held, false)
			_spell_held = null
		_spell_phase = phase
	if phase == AbilityController.Phase.ACTIVE and a.kind == AbilityData.Kind.DASH:
		_afterimage_timer -= delta
		if _afterimage_timer <= 0.0:
			_afterimage_timer = 0.035
			SpellVfx.afterimage(_character, a.color)


func _update_overhead() -> void:
	# Only what you can't read from the body: name and crowd control.
	var text: String = _character.data.short_name if _character.data.short_name != "" else _character.data.display_name.get_slice(" ", 0)
	if _character.status.has_status(StatusController.Type.STUN):
		text = "STUN"
	elif _character.status.has_status(StatusController.Type.ROOT):
		text = "ROOT"
	var marks: int = _character.status.get_stacks(StatusController.Type.MARK)
	if marks > 0:
		text += "  " + "◆".repeat(marks)
	overhead.text = text


## Telegraph: during startup, a filled shape shows where the jutsu will
## land and fills up as the cast completes (enemy casts are red).
func _update_cast_indicator() -> void:
	_cast_mesh.clear_surfaces()
	var abilities: AbilityController = _character.abilities
	if abilities.phase != AbilityController.Phase.STARTUP or _character.is_dead():
		return
	var a: AbilityData = abilities.current
	if a.startup_time < 0.12 and _role != Role.LOCAL_PLAYER:
		return
	var progress: float = clampf(abilities.phase_elapsed / maxf(a.startup_time, 0.001), 0.0, 1.0)
	var color: Color = Color(1.0, 0.22, 0.18) if _role == Role.ENEMY else a.color.lerp(Color.WHITE, 0.35)
	var origin: Vector3 = HitQuery.flat(_character.global_position) + Vector3.UP * 0.05
	var dir: Vector3 = _character.facing.facing_direction
	match a.kind:
		AbilityData.Kind.MELEE_ARC:
			var reach: float = a.max_range + a.lunge_distance
			_sector(origin, dir, reach, a.arc_degrees, color, 0.12)
			_sector(origin, dir, reach * progress, a.arc_degrees, color, 0.28)
			_sector_edge(origin, dir, reach, a.arc_degrees, color)
		AbilityData.Kind.DASH:
			var length: float = a.dash_distance + a.hit_radius
			_rect(origin, dir, length, a.hit_radius, color, 0.12)
			_rect(origin, dir, length * progress, a.hit_radius, color, 0.28)
		AbilityData.Kind.PROJECTILE:
			_rect(origin, dir, a.max_range, a.hit_radius, color, 0.1)
			_rect(origin, dir, a.max_range * progress, a.hit_radius, color, 0.24)
		AbilityData.Kind.GROUND_AREA:
			var target: Vector3 = origin + HitQuery.flat(_character.facing.aim_point - _character.global_position).limit_length(a.max_range)
			_disk(target, a.hit_radius, color, 0.12)
			_disk(target, a.hit_radius * progress, color, 0.26)


func _begin(color: Color, alpha: float) -> void:
	_cast_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	_cast_mesh.surface_set_color(Color(color, alpha))


func _sector(origin: Vector3, dir: Vector3, radius: float, degrees: float, color: Color, alpha: float) -> void:
	if radius <= 0.05:
		return
	_begin(color, alpha)
	var segments: int = maxi(6, int(degrees / 8.0))
	var half: float = deg_to_rad(degrees) * 0.5
	for i in segments:
		var a0: float = -half + 2.0 * half * i / segments
		var a1: float = -half + 2.0 * half * (i + 1) / segments
		_cast_mesh.surface_add_vertex(origin)
		_cast_mesh.surface_add_vertex(origin + dir.rotated(Vector3.UP, a0) * radius)
		_cast_mesh.surface_add_vertex(origin + dir.rotated(Vector3.UP, a1) * radius)
	_cast_mesh.surface_end()


func _sector_edge(origin: Vector3, dir: Vector3, radius: float, degrees: float, color: Color) -> void:
	_cast_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	_cast_mesh.surface_set_color(Color(color, 0.8))
	var segments: int = maxi(6, int(degrees / 8.0))
	var half: float = deg_to_rad(degrees) * 0.5
	for i in segments + 1:
		_cast_mesh.surface_add_vertex(origin + dir.rotated(Vector3.UP, -half + 2.0 * half * i / segments) * radius)
	_cast_mesh.surface_end()


func _rect(origin: Vector3, dir: Vector3, length: float, half_width: float, color: Color, alpha: float) -> void:
	if length <= 0.05:
		return
	var side: Vector3 = dir.cross(Vector3.UP).normalized() * half_width
	var tip: Vector3 = origin + dir * length
	_begin(color, alpha)
	for v: Vector3 in [origin + side, tip + side, tip - side, origin + side, tip - side, origin - side]:
		_cast_mesh.surface_add_vertex(v)
	_cast_mesh.surface_end()


func _disk(center: Vector3, radius: float, color: Color, alpha: float) -> void:
	if radius <= 0.05:
		return
	_begin(color, alpha)
	for i in 32:
		var a0: float = TAU * i / 32.0
		var a1: float = TAU * (i + 1) / 32.0
		_cast_mesh.surface_add_vertex(center)
		_cast_mesh.surface_add_vertex(center + Vector3(cos(a0), 0.0, sin(a0)) * radius)
		_cast_mesh.surface_add_vertex(center + Vector3(cos(a1), 0.0, sin(a1)) * radius)
	_cast_mesh.surface_end()


## Sounds driven by observed state (works for every fighter, online too).
func _audio_cues() -> void:
	var status: StatusController = _character.status
	var stunned: bool = status.has_status(StatusController.Type.STUN)
	if stunned and not _was_stunned:
		Sfx.play(&"stun", _character.global_position, -4.0)
	_was_stunned = stunned
	var dead: bool = _character.is_dead()
	if dead and not _was_dead:
		Sfx.play(&"ko", _character.global_position)
	_was_dead = dead
	var immaterial: bool = status.has_status(StatusController.Type.IMMATERIAL)
	var a: AbilityData = _character.abilities.current
	if immaterial and not _was_immaterial and a != null and a.kind == AbilityData.Kind.COUNTER:
		Sfx.play(&"counter", _character.global_position)  # counter triggered
		CombatFx.burst(_character, _character.global_position + Vector3.UP * 1.0, a.color, 1.2)
	_was_immaterial = immaterial


func _cast_sound(a: AbilityData, phase: int) -> void:
	if phase == AbilityController.Phase.STARTUP:
		match a.vfx:
			&"chidori", &"raikiri", &"kirin":
				Sfx.play(&"electric", _character.global_position, -3.0)
			&"rasengan", &"rasenshuriken":
				Sfx.play(&"charge", _character.global_position, -4.0)
		return
	var pos: Vector3 = _character.global_position
	match a.kind:
		AbilityData.Kind.MELEE_ARC:
			var heavy: bool = a.arc_degrees <= 60.0 or a.max_range >= 2.3 or a.knockback_speed > 0.0 or a.multi_hits > 1
			Sfx.play(&"swing_heavy" if heavy else &"swing", pos, -3.0)
		AbilityData.Kind.DASH:
			Sfx.play(&"dash", pos, -2.0)
		AbilityData.Kind.TELEPORT:
			Sfx.play(&"blink", pos, -2.0)
		AbilityData.Kind.PROJECTILE:
			Sfx.play(&"fire" if a.vfx == &"katon" or a.vfx == &"black_fire" else &"throw", pos, -2.0)
		AbilityData.Kind.SELF_HEAL:
			Sfx.play(&"heal", pos, -4.0)
		AbilityData.Kind.SUMMON_CLONE:
			Sfx.play(&"blink", pos, -4.0, 0.7)
