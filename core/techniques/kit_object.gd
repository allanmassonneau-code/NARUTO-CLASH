class_name KitObject
extends Node3D
## Persistent gameplay object created by a technique (design bible §1, §7):
## zone, wall, mirror, glyph, node, anchor, decoy... It has an owner, a team,
## a lifetime, optional health, and callbacks. Fighters inside its radius
## are tracked (enter / exit). Walls can block movement and projectiles.

signal destroyed(reason: String)

enum Look { DISC, RING, WALL, PILLAR, ORB, DECOY, GLYPH, NONE }

var owner_character: CombatCharacter
var team: int = 0
## Technique that created it (recasts look it up).
var technique_id: StringName = &""
var kind: String = ""
var radius: float = 2.0
## WALL: half length along `facing` x half thickness.
var half_extents: Vector2 = Vector2(2.0, 0.3)
var facing: Vector3 = Vector3.FORWARD
var lifetime: float = 5.0
var age: float = 0.0
## < 0 = indestructible.
var health: float = -1.0
var max_health: float = -1.0
var blocks_projectiles: bool = false
var blocks_movement: bool = false
## Enemy hits (techniques, basic attacks, projectiles) damage it.
var targetable: bool = true
var color: Color = Color.WHITE
var look: Look = Look.DISC
var tick_interval: float = 0.0
## Free storage for the technique (charges, state...).
var data: Dictionary = {}

## Callbacks (all optional): on_enter(fighter, obj), on_exit(fighter, obj),
## on_tick(obj) every tick_interval (or every frame if 0), on_expire(obj),
## on_destroy(obj, reason), on_projectile(team, point) -> bool (true = absorbed).
var on_enter: Callable
var on_exit: Callable
var on_tick: Callable
var on_expire: Callable
var on_destroy: Callable
var on_projectile: Callable

var inside: Array[CombatCharacter] = []
var _tick_timer: float = 0.0
var _gone: bool = false
var _visual: Node3D
var _body: StaticBody3D


func _ready() -> void:
	add_to_group(&"kit_objects")
	add_to_group(&"round_entities")
	global_position.y = 0.0
	if blocks_movement:
		_build_body()
	if CombatFx.is_enabled() and look != Look.NONE:
		_visual = KitVisuals.object_visual(self)
		if _visual != null:
			add_child(_visual)


func _physics_process(delta: float) -> void:
	if _gone:
		return
	age += delta
	_track_inside()
	if on_tick.is_valid():
		_tick_timer -= delta
		if _tick_timer <= 0.0:
			_tick_timer = tick_interval
			on_tick.call(self)
	if lifetime > 0.0 and age >= lifetime and not _gone:
		if on_expire.is_valid():
			on_expire.call(self)
		destroy("expired")


func _process(delta: float) -> void:
	if _visual != null:
		KitVisuals.object_tick(self, _visual, delta)


func _track_inside() -> void:
	var now: Array[CombatCharacter] = []
	for node: Node in get_tree().get_nodes_in_group(&"fighters"):
		var f := node as CombatCharacter
		if f != null and not f.is_dead() and contains(f.global_position):
			now.append(f)
	for f: CombatCharacter in now:
		if not inside.has(f) and on_enter.is_valid():
			on_enter.call(f, self)
	for f: CombatCharacter in inside:
		if is_instance_valid(f) and not now.has(f) and on_exit.is_valid():
			on_exit.call(f, self)
	inside = now


func contains(point: Vector3) -> bool:
	var to: Vector3 = HitQuery.flat(point - global_position)
	if look == Look.WALL:
		var along: float = absf(to.dot(facing))
		var across: float = absf(to.dot(facing.cross(Vector3.UP)))
		return along <= half_extents.y + HitQuery.HURTBOX_RADIUS and across <= half_extents.x + HitQuery.HURTBOX_RADIUS
	return to.length() <= radius


func enemies_inside() -> Array[CombatCharacter]:
	return inside.filter(func(f: CombatCharacter) -> bool: return is_instance_valid(f) and f.team != team)


func allies_inside() -> Array[CombatCharacter]:
	return inside.filter(func(f: CombatCharacter) -> bool: return is_instance_valid(f) and f.team == team)


func is_alive() -> bool:
	return not _gone and is_inside_tree()


func damage(amount: float) -> void:
	if health < 0.0 or _gone:
		return
	health -= amount
	CombatFx.ring(self, global_position, maxf(0.5, minf(radius, 1.5)), color, 0.2)
	if health <= 0.0:
		destroy("destroyed")


func destroy(reason: String = "destroyed") -> void:
	if _gone:
		return
	_gone = true
	if on_destroy.is_valid():
		on_destroy.call(self, reason)
	destroyed.emit(reason)
	queue_free()


## Projectile of `from_team` reaches `point`: true if this object stops it.
func stops_projectile(from_team: int, point: Vector3) -> bool:
	if _gone or from_team == team or not contains(point):
		return false
	if on_projectile.is_valid():
		return bool(on_projectile.call(from_team, point))
	if blocks_projectiles:
		damage(5.0)
		return true
	return false


func _build_body() -> void:
	_body = StaticBody3D.new()
	_body.collision_layer = 1
	_body.collision_mask = 0
	var shape := CollisionShape3D.new()
	if look == Look.WALL:
		var box := BoxShape3D.new()
		box.size = Vector3(half_extents.x * 2.0, 2.0, half_extents.y * 2.0)
		shape.shape = box
		shape.position.y = 1.0
		_body.basis = Basis.looking_at(facing, Vector3.UP)
	else:
		var cyl := CylinderShape3D.new()
		cyl.radius = radius
		cyl.height = 2.0
		shape.shape = cyl
		shape.position.y = 1.0
	_body.add_child(shape)
	add_child(_body)


# --- Static helpers -----------------------------------------------------------------

## Enemy objects of `team` hit at `center` within `reach` take `amount`.
static func damage_objects_in(tree: SceneTree, center: Vector3, reach: float, team: int, amount: float) -> void:
	for node: Node in tree.get_nodes_in_group(&"kit_objects"):
		var o := node as KitObject
		if o == null or o.team == team or not o.targetable or o.health < 0.0:
			continue
		if HitQuery.flat(o.global_position - center).length() <= reach + o.radius:
			o.damage(amount)


## First enemy object stopping a projectile of `team` at `point`, or null.
static func blocker_at(tree: SceneTree, point: Vector3, team: int) -> KitObject:
	for node: Node in tree.get_nodes_in_group(&"kit_objects"):
		var o := node as KitObject
		if o != null and o.stops_projectile(team, point):
			return o
	return null


static func find(tree: SceneTree, owner_char: CombatCharacter, technique: StringName, kind_filter: String = "") -> Array[KitObject]:
	var out: Array[KitObject] = []
	for node: Node in tree.get_nodes_in_group(&"kit_objects"):
		var o := node as KitObject
		if o != null and o.is_alive() and o.owner_character == owner_char and (technique == &"" or o.technique_id == technique) \
				and (kind_filter == "" or o.kind == kind_filter):
			out.append(o)
	return out
