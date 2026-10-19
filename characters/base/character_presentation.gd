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
		_on_damaged(_last_health - hp)
	_last_health = hp
	_update_health_bar()
	_flash = maxf(0.0, _flash - delta)

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
		AbilityData.Kind.GROUND_AREA:
			return "seal"
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
	if a == null:
		_spell_phase = phase
		return
	if phase != _spell_phase:
		if _spell_phase == AbilityController.Phase.IDLE and phase != AbilityController.Phase.STARTUP and _spell_held == null:
			_spell_held = SpellVfx.on_startup(_character, a, model)  # startup was too short to observe
		if phase == AbilityController.Phase.ACTIVE:
			SpellVfx.on_active(_character, a, _spell_held)
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
	var text: String = _character.data.display_name.get_slice(" ", 0)
	if _character.status.has_status(StatusController.Type.STUN):
		text = "STUN"
	elif _character.status.has_status(StatusController.Type.ROOT):
		text = "ROOT"
	overhead.text = text


## Telegraph: during startup, show where the jutsu is aimed and how far it reaches.
func _update_cast_indicator() -> void:
	_cast_mesh.clear_surfaces()
	var abilities: AbilityController = _character.abilities
	if abilities.phase != AbilityController.Phase.STARTUP:
		return
	var a: AbilityData = abilities.current
	if a.kind != AbilityData.Kind.GROUND_AREA and a.get_reach() <= 0.0:
		return
	var origin: Vector3 = _character.global_position + Vector3.UP * 0.06
	var dir: Vector3 = _character.facing.facing_direction
	_cast_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	_cast_mesh.surface_set_color(Color(a.color, 0.9))
	if a.kind == AbilityData.Kind.GROUND_AREA:
		var target: Vector3 = _character.global_position + HitQuery.flat(_character.facing.aim_point - _character.global_position).limit_length(a.max_range)
		target.y = 0.06
		for i in 32:
			var a0: float = TAU * i / 32.0
			var a1: float = TAU * (i + 1) / 32.0
			_cast_mesh.surface_add_vertex(target + Vector3(cos(a0), 0.0, sin(a0)) * a.hit_radius)
			_cast_mesh.surface_add_vertex(target + Vector3(cos(a1), 0.0, sin(a1)) * a.hit_radius)
	else:
		var side: Vector3 = dir.cross(Vector3.UP) * a.hit_radius * 0.5
		var tip: Vector3 = origin + dir * a.get_reach()
		for offset: Vector3 in [side, -side]:
			_cast_mesh.surface_add_vertex(origin + offset)
			_cast_mesh.surface_add_vertex(tip + offset)
	_cast_mesh.surface_end()
