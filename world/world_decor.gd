class_name WorldDecor
## Visual set dressing for the open world (houses, lanterns, trees, grass,
## camps, ruins...). Obstacles that block movement get a StaticBody on
## collision layer 1; pure decoration has no collision. Headless builds only
## create the collisions.

var root: Node3D
var rng := RandomNumberGenerator.new()
var visuals: bool = true
var _materials: Dictionary = {}


func _init(parent: Node3D, seed_value: int) -> void:
	root = parent
	rng.seed = seed_value
	visuals = CombatFx.is_enabled()


# --- Materials & primitives ------------------------------------------------------

func mat(color: Color, emission: float = 0.0) -> StandardMaterial3D:
	var key: String = "%s/%s" % [color.to_html(), emission]
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	_materials[key] = m
	return m


func mesh(m: Mesh, at: Vector3, color: Color, rot: Vector3 = Vector3.ZERO, emission: float = 0.0) -> MeshInstance3D:
	if not visuals:
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat(color, emission)
	mi.position = at
	mi.rotation_degrees = rot
	root.add_child(mi)
	return mi


func box(at: Vector3, size: Vector3, color: Color, rot_y: float = 0.0, emission: float = 0.0) -> void:
	var b := BoxMesh.new()
	b.size = size
	mesh(b, at, color, Vector3(0, rot_y, 0), emission)


func cylinder(at: Vector3, top: float, bottom: float, height: float, color: Color, segments: int = 12, rot_y: float = 0.0) -> void:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = height
	c.radial_segments = segments
	mesh(c, at, color, Vector3(0, rot_y, 0))


func sphere(at: Vector3, radius: float, height: float, color: Color, emission: float = 0.0) -> void:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = height
	s.radial_segments = 16
	s.rings = 8
	mesh(s, at, color, Vector3.ZERO, emission)


func collider(base: Vector3, shape: Shape3D, height: float, rot_y: float = 0.0) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = base
	body.rotation_degrees.y = rot_y
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = height / 2.0
	body.add_child(col)
	root.add_child(body)


func solid_box(base: Vector3, size: Vector3, color: Color, rot_y: float = 0.0) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	collider(base, shape, size.y, rot_y)
	box(base + Vector3.UP * size.y / 2.0, size, color, rot_y)


func solid_round(base: Vector3, radius: float, height: float) -> void:
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	collider(base, shape, height)


func ground(center: Vector3, size: Vector2, color: Color) -> void:
	var p := PlaneMesh.new()
	p.size = size
	mesh(p, center, color)


func disk(center: Vector3, radius: float, color: Color) -> void:
	cylinder(center, radius, radius, 0.02, color, 24)


func label(at: Vector3, text: String, size: int, color: Color) -> void:
	if not visuals:
		return
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.outline_size = 16
	l.modulate = color
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.pixel_size = 0.01
	l.position = at
	root.add_child(l)


## Many copies of one small mesh (grass, flowers, pebbles) in one draw call.
func scatter(m: Mesh, count: int, area_min: Vector2, area_max: Vector2, color: Color, scale_range: Vector2, avoid: Callable = Callable()) -> void:
	if not visuals:
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = m
	var transforms: Array[Transform3D] = []
	var tries: int = 0
	while transforms.size() < count and tries < count * 3:
		tries += 1
		var p := Vector3(rng.randf_range(area_min.x, area_max.x), 0, rng.randf_range(area_min.y, area_max.y))
		if avoid.is_valid() and avoid.call(p):
			continue
		var s: float = rng.randf_range(scale_range.x, scale_range.y)
		transforms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), p))
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		mm.set_instance_color(i, color.lightened(rng.randf_range(-0.12, 0.12)))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


func grass(area_min: Vector2, area_max: Vector2, count: int, color: Color, avoid: Callable = Callable()) -> void:
	var tuft := CylinderMesh.new()
	tuft.top_radius = 0.0
	tuft.bottom_radius = 0.12
	tuft.height = 0.45
	tuft.radial_segments = 4
	scatter(tuft, count, area_min, area_max, color, Vector2(0.7, 1.4), avoid)


func flowers(area_min: Vector2, area_max: Vector2, count: int, avoid: Callable = Callable()) -> void:
	var bloom := SphereMesh.new()
	bloom.radius = 0.09
	bloom.height = 0.18
	bloom.radial_segments = 6
	bloom.rings = 3
	for color: Color in [Color(1.0, 0.85, 0.3), Color(1.0, 0.55, 0.7), Color(0.85, 0.85, 1.0)]:
		scatter(bloom, count / 3, area_min, area_max, color, Vector2(0.8, 1.3), avoid)


# --- Props ----------------------------------------------------------------------------

## Japanese-style house: walls, door, windows, overhanging tiled roof.
func house(base: Vector3, size: Vector3, wall: Color, roof: Color, rot_y: float = 0.0) -> void:
	solid_box(base, size, wall, rot_y)
	if not visuals:
		return
	var basis := Basis(Vector3.UP, deg_to_rad(rot_y))
	var front: Vector3 = basis * Vector3(0, 0, size.z / 2.0 + 0.03)
	box(base + front + Vector3.UP * 1.0, Vector3(1.1, 2.0, 0.08), Color(0.3, 0.2, 0.12), rot_y)
	for side: float in [-1.0, 1.0]:
		var w: Vector3 = basis * Vector3(side * size.x * 0.3, 0, size.z / 2.0 + 0.03)
		box(base + w + Vector3.UP * (size.y * 0.6), Vector3(0.9, 0.8, 0.06), Color(1.0, 0.9, 0.6), rot_y, 0.4)
	box(base + Vector3.UP * (size.y + 0.15), Vector3(size.x + 1.4, 0.3, size.z + 1.4), roof.darkened(0.2), rot_y)
	var r := CylinderMesh.new()
	r.top_radius = 0.0
	r.bottom_radius = maxf(size.x, size.z) * 0.78
	r.height = maxf(size.x, size.z) * 0.38
	r.radial_segments = 4
	mesh(r, base + Vector3.UP * (size.y + 0.3 + r.height / 2.0), roof, Vector3(0, rot_y + 45.0, 0))


func lantern(at: Vector3) -> void:
	solid_round(at, 0.12, 2.0)
	cylinder(at + Vector3.UP * 1.0, 0.06, 0.08, 2.0, Color(0.25, 0.18, 0.12), 6)
	box(at + Vector3(0.25, 2.0, 0), Vector3(0.6, 0.06, 0.06), Color(0.25, 0.18, 0.12))
	sphere(at + Vector3(0.45, 1.75, 0), 0.22, 0.5, Color(1.0, 0.35, 0.2), 1.6)


func round_tree(at: Vector3, foliage: Color, size: float = 1.0, collide: bool = true) -> void:
	if collide:
		solid_round(at, 0.4 * size, 2.0)
	cylinder(at + Vector3.UP * 1.3 * size, 0.25 * size, 0.38 * size, 2.6 * size, Color(0.4, 0.27, 0.16), 8)
	for i in 3:
		var off := Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6)) * size
		sphere(at + off + Vector3.UP * (3.0 + i * 0.7) * size, (1.7 - i * 0.35) * size, (2.6 - i * 0.5) * size, foliage.lightened(i * 0.08))


func pine(at: Vector3, size: float = 1.0) -> void:
	solid_round(at, 0.35 * size, 2.0)
	cylinder(at + Vector3.UP * 0.8 * size, 0.2 * size, 0.3 * size, 1.6 * size, Color(0.38, 0.25, 0.15), 6)
	for i in 3:
		cylinder(at + Vector3.UP * (2.0 + i * 1.1) * size, 0.0, (1.7 - i * 0.45) * size, 2.0 * size, Color(0.16, 0.38, 0.22).lightened(i * 0.05), 8)


func bush(at: Vector3, color: Color) -> void:
	for i in 3:
		var off := Vector3(rng.randf_range(-0.5, 0.5), 0, rng.randf_range(-0.5, 0.5))
		sphere(at + off + Vector3.UP * 0.35, rng.randf_range(0.45, 0.7), rng.randf_range(0.6, 0.9), color.lightened(rng.randf_range(-0.05, 0.1)))


func rock(at: Vector3, radius: float, color: Color = Color(0.52, 0.5, 0.5)) -> void:
	solid_round(at, radius * 0.9, 2.0)
	sphere(at + Vector3.UP * radius * 0.3, radius, radius * 1.2, color)
	sphere(at + Vector3(radius * 0.5, radius * 0.2, radius * 0.3), radius * 0.55, radius * 0.7, color.darkened(0.1))


func campfire(at: Vector3) -> void:
	for i in 4:
		box(at + Vector3.UP * 0.12, Vector3(1.0, 0.16, 0.16), Color(0.35, 0.22, 0.12), i * 45.0)
	if visuals:
		var flame := CylinderMesh.new()
		flame.top_radius = 0.0
		flame.bottom_radius = 0.35
		flame.height = 0.9
		flame.radial_segments = 6
		mesh(flame, at + Vector3.UP * 0.55, Color(1.0, 0.55, 0.15), Vector3.ZERO, 3.0)
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.6, 0.3)
		light.light_energy = 1.6
		light.omni_range = 7.0
		light.position = at + Vector3.UP * 1.2
		root.add_child(light)


func tent(at: Vector3, color: Color, rot_y: float) -> void:
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.4, 2.0, 2.8)
	collider(at, shape, 2.0, rot_y)
	var t := CylinderMesh.new()
	t.top_radius = 0.0
	t.bottom_radius = 1.6
	t.height = 2.2
	t.radial_segments = 3
	mesh(t, at + Vector3.UP * 1.1, color, Vector3(0, rot_y, 0))


func fence(from: Vector3, to: Vector3, color: Color = Color(0.45, 0.32, 0.2)) -> void:
	var dir: Vector3 = to - from
	var steps: int = maxi(1, int(dir.length() / 2.0))
	for i in steps + 1:
		cylinder(from + dir * float(i) / steps + Vector3.UP * 0.5, 0.08, 0.08, 1.0, color, 6)
	var mid: Vector3 = (from + to) / 2.0
	var yaw: float = rad_to_deg(atan2(dir.x, dir.z))
	box(mid + Vector3.UP * 0.75, Vector3(0.08, 0.1, dir.length()), color, yaw)
	box(mid + Vector3.UP * 0.4, Vector3(0.08, 0.1, dir.length()), color, yaw)


func ruin_pillar(at: Vector3) -> void:
	var h: float = rng.randf_range(1.2, 3.5)
	solid_round(at, 0.6, 2.0)
	cylinder(at + Vector3.UP * h / 2.0, 0.5, 0.6, h, Color(0.62, 0.6, 0.56), 8)
	if rng.randf() < 0.5:
		box(at + Vector3(0.8, 0.2, 0.3), Vector3(1.2, 0.4, 0.6), Color(0.58, 0.56, 0.52), rng.randf() * 90.0)


func mountain(at: Vector3, radius: float, height: float, color: Color) -> void:
	cylinder(at + Vector3.UP * height / 2.0, radius * 0.08, radius, height, color, 7, rng.randf() * 60.0)
	cylinder(at + Vector3.UP * (height - height * 0.12), 0.0, radius * 0.22, height * 0.24, Color(0.95, 0.95, 0.97), 7)


## Kage building: round tower with a red roof and the village kanji-like sign.
func kage_tower(at: Vector3, wall: Color, roof: Color, text: String) -> void:
	var shape := CylinderShape3D.new()
	shape.radius = 5.0
	shape.height = 9.0
	collider(at, shape, 9.0)
	cylinder(at + Vector3.UP * 4.5, 4.6, 5.0, 9.0, wall, 20)
	cylinder(at + Vector3.UP * 9.3, 5.8, 5.8, 0.4, roof.darkened(0.2), 20)
	cylinder(at + Vector3.UP * 10.6, 1.0, 5.4, 2.4, roof, 20)
	box(at + Vector3(0, 6.5, 4.75), Vector3(2.4, 1.6, 0.2), Color(1, 1, 1))
	label(at + Vector3(0, 6.5, 5.0), text, 120, Color(0.75, 0.1, 0.1))
	box(at + Vector3(0, 1.1, 4.95), Vector3(1.6, 2.2, 0.15), Color(0.3, 0.2, 0.12))


func statue(at: Vector3, color: Color) -> void:
	solid_round(at, 1.6, 2.0)
	cylinder(at + Vector3.UP * 0.4, 1.6, 1.8, 0.8, Color(0.6, 0.58, 0.55), 16)
	cylinder(at + Vector3.UP * 1.6, 0.45, 0.6, 1.6, color, 10)
	sphere(at + Vector3.UP * 2.7, 0.45, 0.9, color)


func torii(at: Vector3, width: float, color: Color) -> void:
	for side: float in [-1.0, 1.0]:
		var p: Vector3 = at + Vector3(0, 0, side * width / 2.0)
		solid_round(p, 0.5, 6.0)
		cylinder(p + Vector3.UP * 3.0, 0.4, 0.45, 6.0, color, 10)
	box(at + Vector3.UP * 6.2, Vector3(1.2, 0.5, width + 3.0), color)
	box(at + Vector3.UP * 6.7, Vector3(1.4, 0.3, width + 4.0), color.darkened(0.4))
	box(at + Vector3.UP * 5.2, Vector3(0.6, 0.35, width), color)
