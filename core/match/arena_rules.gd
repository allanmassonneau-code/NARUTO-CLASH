class_name ArenaRules
extends Node3D
## Round dynamics on top of the duel (Battlerite-style):
## - Chakra orb: spawns at the arena centre, the fighter landing the last hit
##   on it gets a heal and chakra energy. Contesting it forces engagements.
## - Sudden death: after a while a ring closes in on the centre, fighters
##   outside it take damage, so rounds can't be stalled forever.
## Authoritative offline / on the server; clients mirror (fight_time, orb_hp).

signal orb_taken(by: CombatCharacter)

const ORB_MAX_HP: float = 30.0
const ORB_RADIUS: float = 0.75
const ORB_FIRST_SPAWN: float = 10.0
const ORB_RESPAWN: float = 22.0
const ORB_HEAL: float = 20.0
const ORB_ENERGY: float = 25.0
const ORB_HEIGHT: float = 1.0

const SUDDEN_DEATH_AT: float = 60.0
const SUDDEN_DEATH_WARNING: float = 5.0
const RING_START_RADIUS: float = 19.5
const RING_END_RADIUS: float = 3.5
const RING_CLOSE_TIME: float = 35.0
const RING_TICK: float = 0.5
const RING_TICK_DAMAGE: float = 6.0

## The rules of the running match (orb hits are routed here).
static var active: ArenaRules

## Seconds of FIGHTING elapsed this round.
var fight_time: float = 0.0
var orb_hp: float = 0.0
var authoritative: bool = true

var _orb_timer: float = ORB_FIRST_SPAWN
var _ring_tick: float = RING_TICK
var _orb_view: Node3D
var _orb_core: MeshInstance3D
var _ring_view: MeshInstance3D
var _ring_floor: MeshInstance3D
var _visual_hp: float = 0.0


func _ready() -> void:
	active = self
	if CombatFx.is_enabled():
		_build_visuals()


func _exit_tree() -> void:
	if active == self:
		active = null


func reset_round() -> void:
	fight_time = 0.0
	orb_hp = 0.0
	_orb_timer = ORB_FIRST_SPAWN
	_ring_tick = RING_TICK


func ring_radius() -> float:
	if fight_time < SUDDEN_DEATH_AT:
		return RING_START_RADIUS
	var t: float = clampf((fight_time - SUDDEN_DEATH_AT) / RING_CLOSE_TIME, 0.0, 1.0)
	return lerpf(RING_START_RADIUS, RING_END_RADIUS, t)


func is_sudden_death() -> bool:
	return fight_time >= SUDDEN_DEATH_AT


func orb_alive() -> bool:
	return orb_hp > 0.0


func orb_position() -> Vector3:
	return global_position


## Authoritative tick while the round is being fought.
func tick(delta: float, fighters: Array[CombatCharacter]) -> void:
	fight_time += delta
	if not orb_alive():
		_orb_timer -= delta
		if _orb_timer <= 0.0:
			orb_hp = ORB_MAX_HP
	if is_sudden_death():
		_ring_tick -= delta
		if _ring_tick <= 0.0:
			_ring_tick = RING_TICK
			var radius: float = ring_radius()
			for fighter: CombatCharacter in fighters:
				if not fighter.is_dead() and HitQuery.flat(fighter.global_position - global_position).length() > radius:
					fighter.health.apply_damage(RING_TICK_DAMAGE)


## Any damaging hit can strike the orb. Returns true if it was hit.
static func hit_orb(source: CombatCharacter, center: Vector3, radius: float, damage: float) -> bool:
	if active == null or not active.authoritative or not active.orb_alive() or damage <= 0.0:
		return false
	if not is_instance_valid(source) or source.is_dead():
		return false
	if HitQuery.flat(center - active.global_position).length() > radius + ORB_RADIUS:
		return false
	active._damage_orb(source, damage)
	return true


## Melee swing (arc) against the orb.
static func hit_orb_arc(source: CombatCharacter, origin: Vector3, direction: Vector3, a: AbilityData, damage: float) -> void:
	if active == null or not active.orb_alive():
		return
	var to_orb: Vector3 = HitQuery.flat(active.global_position - origin)
	if to_orb.length() > a.max_range + ORB_RADIUS:
		return
	if to_orb.length() > ORB_RADIUS * 1.5 and direction.angle_to(to_orb) > deg_to_rad(a.arc_degrees) * 0.5:
		return
	hit_orb(source, active.global_position, 0.0, damage)


func _damage_orb(source: CombatCharacter, damage: float) -> void:
	orb_hp = maxf(0.0, orb_hp - damage)
	if orb_hp > 0.0:
		return
	_orb_timer = ORB_RESPAWN
	source.health.heal(ORB_HEAL, true)
	source.energy.gain(ORB_ENERGY)
	CombatFx.ring(source, source.global_position, 1.6, Color(0.4, 1.0, 0.6), 0.5)
	orb_taken.emit(source)


# --- Network mirror -------------------------------------------------------

func write_header(out: PackedFloat32Array) -> void:
	out.append_array([fight_time, orb_hp])


func apply_header(data: PackedFloat32Array) -> void:
	fight_time = data[0]
	orb_hp = data[1]


const HEADER_SIZE: int = 2


# --- Presentation ---------------------------------------------------------

func _process(delta: float) -> void:
	if _orb_view == null:
		return
	var alive: bool = orb_alive()
	if _visual_hp > 0.0 and not alive:
		CombatFx.burst(self, global_position + Vector3.UP * ORB_HEIGHT, Color(0.4, 1.0, 0.6), 1.6)
		Sfx.play(&"orb", global_position)
	elif alive and orb_hp < _visual_hp - 0.01:
		_orb_core.scale = Vector3.ONE * 1.35  # hit flash
		Sfx.play(&"orb_hit", global_position, -6.0)
	elif alive and _visual_hp <= 0.0:
		CombatFx.burst(self, global_position + Vector3.UP * ORB_HEIGHT, Color(0.6, 1.0, 0.8), 0.8)
	_visual_hp = orb_hp
	_orb_view.visible = alive
	if alive:
		var t: float = Time.get_ticks_msec() * 0.001
		_orb_view.position.y = ORB_HEIGHT + sin(t * 2.2) * 0.12
		_orb_view.rotation.y += delta * 1.5
		var ratio: float = orb_hp / ORB_MAX_HP
		_orb_core.scale = _orb_core.scale.lerp(Vector3.ONE * (0.55 + 0.45 * ratio), 1.0 - exp(-12.0 * delta))
	var radius: float = ring_radius()
	var warn: bool = fight_time >= SUDDEN_DEATH_AT - SUDDEN_DEATH_WARNING
	_ring_view.visible = warn
	_ring_floor.visible = warn
	if warn:
		_ring_view.scale = Vector3(radius, 1.0, radius)
		_ring_floor.scale = Vector3(radius, 1.0, radius)
		var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
		var mat := _ring_view.material_override as StandardMaterial3D
		mat.albedo_color.a = (0.16 if is_sudden_death() else 0.06) + pulse * 0.08


func _build_visuals() -> void:
	_orb_view = Node3D.new()
	add_child(_orb_view)
	var core := SphereMesh.new()
	core.radius = 0.42
	core.height = 0.84
	_orb_core = MeshInstance3D.new()
	_orb_core.mesh = core
	_orb_core.material_override = _glow(Color(0.35, 1.0, 0.6), 2.5, 1.0)
	_orb_view.add_child(_orb_core)
	var shell := SphereMesh.new()
	shell.radius = ORB_RADIUS
	shell.height = ORB_RADIUS * 2.0
	var shell_view := MeshInstance3D.new()
	shell_view.mesh = shell
	shell_view.material_override = _glow(Color(0.5, 1.0, 0.8, 0.22), 0.8, 0.22)
	_orb_view.add_child(shell_view)
	for i in 3:
		var torus := TorusMesh.new()
		torus.inner_radius = 0.82 + i * 0.12
		torus.outer_radius = 0.88 + i * 0.12
		var ring := MeshInstance3D.new()
		ring.mesh = torus
		ring.material_override = _glow(Color(0.6, 1.0, 0.75, 0.7), 1.5, 0.7)
		ring.rotation = Vector3(0.9 * i, 0.6 * i, 0.4 * i)
		_orb_view.add_child(ring)
	var light := OmniLight3D.new()
	light.light_color = Color(0.4, 1.0, 0.6)
	light.light_energy = 1.4
	light.omni_range = 4.0
	_orb_view.add_child(light)
	_orb_view.visible = false

	var wall := CylinderMesh.new()
	wall.top_radius = 1.0
	wall.bottom_radius = 1.0
	wall.height = 3.0
	wall.radial_segments = 96
	wall.cap_top = false
	wall.cap_bottom = false
	_ring_view = MeshInstance3D.new()
	_ring_view.mesh = wall
	_ring_view.position.y = 1.5
	var wall_mat := _glow(Color(0.85, 0.15, 0.45, 0.2), 1.2, 0.2)
	wall_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ring_view.material_override = wall_mat
	_ring_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring_view)
	var edge := TorusMesh.new()
	edge.inner_radius = 0.985
	edge.outer_radius = 1.0
	edge.rings = 96
	_ring_floor = MeshInstance3D.new()
	_ring_floor.mesh = edge
	_ring_floor.position.y = 0.04
	_ring_floor.scale = Vector3.ONE
	_ring_floor.material_override = _glow(Color(1.0, 0.25, 0.5), 3.0, 1.0)
	add_child(_ring_floor)
	_ring_view.visible = false
	_ring_floor.visible = false


func _glow(color: Color, energy: float, alpha: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(color, alpha)
	if alpha < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	return mat
