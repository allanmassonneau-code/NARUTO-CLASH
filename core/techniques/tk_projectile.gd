class_name TkProjectile
extends Node3D
## Projectile driven by a technique script: straight, homing or lobbed,
## piercing or not, with on_hit / on_end callbacks. Walls and enemy
## KitObjects that block projectiles stop it.

var caster: CombatCharacter
var team: int = 0
var technique_id: StringName = &""
var direction: Vector3 = Vector3.FORWARD
var speed: float = 20.0
var max_range: float = 12.0
var hit_radius: float = 0.6
var pierce: bool = false
## Turn rate (radians / s) toward `homing_target` (0 = straight).
var homing: float = 0.0
var homing_target: CombatCharacter
## Lob: flies in an arc to this point and calls on_end there (no hits in
## flight unless hit_in_flight).
var lob: bool = false
var lob_to: Vector3 = Vector3.ZERO
var hit_in_flight: bool = true
var hits_allies: bool = false
var color: Color = Color.WHITE
var size: float = 0.3
## Free storage for the technique.
var data: Dictionary = {}
## on_hit(target, proj) -> bool (true = keep flying even if not piercing)
var on_hit: Callable
## on_tick(proj, delta) every physics frame (steering, absorbing...)
var on_tick: Callable
## on_end(point, proj, reason) — reason: "range", "wall", "hit", "landed", "blocked", "recast"
var on_end: Callable

var travelled: float = 0.0
var age: float = 0.0
var _start: Vector3
var _flight_time: float = 0.0
var _started: bool = false
var _already: Array[CombatCharacter] = []
var _done: bool = false
var _visual: Node3D


func _ready() -> void:
	add_to_group(&"tk_projectiles")
	add_to_group(&"round_entities")
	if CombatFx.is_enabled():
		_visual = KitVisuals.projectile_visual(self)
		add_child(_visual)


func _physics_process(delta: float) -> void:
	if _done:
		return
	if not _started:
		# The spawner places us after add_child (_ready runs before that).
		_started = true
		_start = global_position
		if lob:
			_flight_time = maxf(0.15, HitQuery.flat(lob_to - _start).length() / maxf(speed, 0.1))
	age += delta
	if on_tick.is_valid():
		on_tick.call(self, delta)
		if _done:
			return
	if lob:
		_lob_step()
		return
	if homing > 0.0 and is_instance_valid(homing_target) and not homing_target.is_dead():
		var want: Vector3 = HitQuery.flat(homing_target.global_position - global_position).normalized()
		var angle: float = direction.signed_angle_to(want, Vector3.UP)
		direction = direction.rotated(Vector3.UP, clampf(angle, -homing * delta, homing * delta)).normalized()
	var from: Vector3 = global_position
	var step: Vector3 = direction * speed * delta
	var wall: Dictionary = HitQuery.raycast_world(get_world_3d(), from, from + step)
	if not wall.is_empty():
		end("wall", wall.position)
		return
	global_position = from + step
	travelled += step.length()
	if KitObject.blocker_at(get_tree(), global_position, team) != null:
		end("blocked", global_position)
		return
	if hit_in_flight and _hit_check():
		return
	if travelled >= max_range:
		end("range", global_position)


func _lob_step() -> void:
	var t: float = clampf(age / _flight_time, 0.0, 1.0)
	var flat: Vector3 = _start.lerp(lob_to, t)
	global_position = Vector3(flat.x, HitQuery.BODY_HEIGHT + 3.0 * 4.0 * t * (1.0 - t), flat.z)
	if hit_in_flight and _hit_check():
		return
	if t >= 1.0:
		end("landed", Vector3(lob_to.x, 0.0, lob_to.z))


func _hit_check() -> bool:
	for target: CombatCharacter in HitQuery.characters_in_sphere(get_world_3d(), global_position, hit_radius):
		if _already.has(target) or target == caster:
			continue
		if (target.team == team) != hits_allies:
			continue
		_already.append(target)
		var keep: bool = false
		if on_hit.is_valid():
			keep = bool(on_hit.call(target, self))
		if _done:
			return true
		if not pierce and not keep:
			end("hit", global_position)
			return true
	return false


## Ends the projectile (calls on_end once).
func end(reason: String, point: Vector3 = Vector3.INF) -> void:
	if _done:
		return
	_done = true
	var at: Vector3 = global_position if point == Vector3.INF else point
	at.y = 0.0
	if on_end.is_valid():
		on_end.call(at, self, reason)
	if CombatFx.is_enabled():
		KitVisuals.fx(self, "burst", at, size * 3.0, color, technique_id)
	queue_free()


func is_alive() -> bool:
	return not _done and is_inside_tree()


func ground_point() -> Vector3:
	return Vector3(global_position.x, 0.0, global_position.z)
