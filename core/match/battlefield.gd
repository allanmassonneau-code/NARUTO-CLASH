class_name Battlefield
## Builds the large 20v20 battle map in code: walled field, rock / pillar
## cover (deterministic layout), dirt lanes and two team bases.

const HALF_SIZE := Vector2(52.0, 32.0)
const BASE_X: float = 45.0
const WALL_THICKNESS: float = 1.2


## Replaces the duel arena under `root` with the battlefield.
static func build(root: Node3D) -> void:
	var old: Node = root.get_node_or_null("Arena")
	if old != null:
		old.queue_free()
	var field := Node3D.new()
	field.name = "Battlefield"
	# Called while the arena scene is still being set up.
	root.add_child.call_deferred(field)
	var visuals: bool = CombatFx.is_enabled()
	if visuals:
		_floor(field)
	var h := HALF_SIZE
	_wall(field, Vector3(0, 1, -h.y), Vector3(h.x * 2.0 + WALL_THICKNESS * 2.0, 2.0, WALL_THICKNESS), visuals)
	_wall(field, Vector3(0, 1, h.y), Vector3(h.x * 2.0 + WALL_THICKNESS * 2.0, 2.0, WALL_THICKNESS), visuals)
	_wall(field, Vector3(-h.x, 1, 0), Vector3(WALL_THICKNESS, 2.0, h.y * 2.0), visuals)
	_wall(field, Vector3(h.x, 1, 0), Vector3(WALL_THICKNESS, 2.0, h.y * 2.0), visuals)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var placed: Array[Vector3] = []
	var attempts: int = 0
	while placed.size() < 34 and attempts < 600:
		attempts += 1
		var p := Vector3(rng.randf_range(-h.x + 8.0, h.x - 8.0), 0.0, rng.randf_range(-h.y + 4.0, h.y - 4.0))
		if absf(p.x) > BASE_X - 7.0:
			continue  # keep the bases open
		var ok: bool = true
		for q: Vector3 in placed:
			if q.distance_to(p) < 7.5:
				ok = false
				break
		if not ok:
			continue
		placed.append(p)
		# Mirror for a fair map.
		var radius: float = rng.randf_range(1.0, 2.3)
		var tall: bool = rng.randf() < 0.4
		_obstacle(field, p, radius, tall, visuals)
		_obstacle(field, Vector3(-p.x, 0, -p.z), radius, tall, visuals)
		placed.append(Vector3(-p.x, 0, -p.z))


## Spawn point inside a team's base.
static func base_spawn(team: int, rng: RandomNumberGenerator) -> Transform3D:
	var x: float = (-BASE_X if team == 0 else BASE_X) + rng.randf_range(-3.0, 3.0)
	var z: float = rng.randf_range(-HALF_SIZE.y + 6.0, HALF_SIZE.y - 6.0)
	var facing := Vector3(1 if team == 0 else -1, 0, 0)
	return Transform3D(Basis.looking_at(facing, Vector3.UP), Vector3(x, 0, z))


static func _floor(field: Node3D) -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = HALF_SIZE * 2.0 + Vector2(60, 60)
	ground.mesh = plane
	ground.material_override = _mat(Color(0.38, 0.55, 0.3))
	ground.position.y = -0.01
	field.add_child(ground)
	var lane := MeshInstance3D.new()
	var lane_mesh := PlaneMesh.new()
	lane_mesh.size = Vector2(HALF_SIZE.x * 2.0, 10.0)
	lane.mesh = lane_mesh
	lane.material_override = _mat(Color(0.62, 0.52, 0.38))
	field.add_child(lane)
	for team in 2:
		var base := MeshInstance3D.new()
		var disk := CylinderMesh.new()
		disk.top_radius = 8.0
		disk.bottom_radius = 8.0
		disk.height = 0.02
		base.mesh = disk
		base.material_override = _mat(Color(UiStyle.TEAM_COLORS[team].darkened(0.3), 1.0))
		base.position = Vector3(-BASE_X if team == 0 else BASE_X, 0.01, 0)
		field.add_child(base)


static func _wall(field: Node3D, at: Vector3, size: Vector3, visuals: bool) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = at
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	if visuals:
		var mesh := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(size.x, 1.2, size.z)
		mesh.mesh = bm
		mesh.position.y = -0.4
		mesh.material_override = _mat(Color(0.55, 0.5, 0.45))
		body.add_child(mesh)
	field.add_child(body)


static func _obstacle(field: Node3D, at: Vector3, radius: float, tall: bool, visuals: bool) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = at
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = 2.0
	shape.shape = cyl
	shape.position.y = 1.0
	body.add_child(shape)
	if visuals:
		var mesh := MeshInstance3D.new()
		if tall:
			var pillar := CylinderMesh.new()
			pillar.top_radius = radius * 0.85
			pillar.bottom_radius = radius
			pillar.height = 2.6
			mesh.mesh = pillar
			mesh.position.y = 1.3
			mesh.material_override = _mat(Color(0.55, 0.38, 0.26))
		else:
			var rock := SphereMesh.new()
			rock.radius = radius
			rock.height = radius * 1.3
			mesh.mesh = rock
			mesh.position.y = radius * 0.35
			mesh.material_override = _mat(Color(0.5, 0.5, 0.53))
		body.add_child(mesh)
	field.add_child(body)


static func _mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	return mat
