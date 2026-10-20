class_name WorldDecor
## Visual set dressing for the open world (houses, lanterns, trees, grass,
## camps, ruins...). Obstacles that block movement get a StaticBody on
## collision layer 1; pure decoration has no collision. Headless builds only
## create the collisions.

var root: Node3D
var rng := RandomNumberGenerator.new()
var visuals: bool = true
## Real Shinobi Striker Konoha meshes (local only, SSProps). They replace the primitive
## visuals only: colliders are always the primitive ones, identical with or without them.
var ss_kit: bool = false
var ss_forest: bool = false
## Game surface -> real SS ground material [mesh, slot, metres per repeat, kit].
const SS_GROUNDS: Dictionary = {
	&"sand": ["SM_ENV_KNVLLG_ground_01", "GroundSoil_A", 6.0, "konoha"],
	&"slabs": ["SM_ENV_KNVLLG_ground_01", "FloorConc_B", 4.0, "konoha"],
	&"forest_ground": ["SM_ENV_KNFRST_Arena_A", "Ground_A", 8.0, "forest"],
}
const SS_TREES: Array[String] = ["SM_ENV_KNVLLG03_Tree_A", "SM_ENV_KNVLLG03_Tree_B", "SM_ENV_KNVLLG03_Tree_D"]
var _ss_house: int = 0
const SS_HOUSES: Array[String] = ["SM_ENV_KNVLLG_AreaG_Building_H", "SM_ENV_KNVLLG_AreaG_Building_F", "SM_ENV_KNVLLG_AreaB_Building_C",
	"SM_ENV_KNVLLG_AreaG_Building_C", "SM_ENV_KNVLLG_AreaG_Building_D", "SM_ENV_KNVLLG_AreaG_Building_B", "SM_ENV_KNVLLG_AreaG_Building_G",
	"SM_ENV_KNVLLG_AreaD_Building_B"]


func _init(parent: Node3D, seed_value: int) -> void:
	root = parent
	rng.seed = seed_value
	visuals = CombatFx.is_enabled()
	ss_kit = visuals and SSProps.available("SM_ENV_KNVLLG_gate_A")
	ss_forest = visuals and SSProps.available("SM_ENV_KNVLLG03_Tree_A", SSProps.FOREST)


# --- Materials & primitives ------------------------------------------------------

## Shinobi Striker toon material (SSGraphics), optionally textured with an SS surface.
func mat(color: Color, emission: float = 0.0, surface: StringName = &"") -> Material:
	return SSGraphics.prop_material(color, surface, emission)


func mesh(m: Mesh, at: Vector3, color: Color, rot: Vector3 = Vector3.ZERO, emission: float = 0.0, surface: StringName = &"") -> MeshInstance3D:
	if not visuals:
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = m
	var ss_ground: Material = _ss_ground(surface)
	mi.material_override = ss_ground if ss_ground != null else mat(color, emission, surface)
	mi.position = at
	mi.rotation_degrees = rot
	var aabb: AABB = m.get_aabb()
	if maxf(aabb.size.x, aabb.size.z) < 12.0:   # primitive props: same distance culling
		mi.visibility_range_end = 70.0
		mi.visibility_range_end_margin = 6.0
	root.add_child(mi)
	return mi


func box(at: Vector3, size: Vector3, color: Color, rot_y: float = 0.0, emission: float = 0.0, surface: StringName = &"") -> void:
	var b := BoxMesh.new()
	b.size = size
	mesh(b, at, color, Vector3(0, rot_y, 0), emission, surface)


func cylinder(at: Vector3, top: float, bottom: float, height: float, color: Color, segments: int = 12, rot_y: float = 0.0, surface: StringName = &"") -> void:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = height
	c.radial_segments = segments
	mesh(c, at, color, Vector3(0, rot_y, 0), 0.0, surface)


func sphere(at: Vector3, radius: float, height: float, color: Color, emission: float = 0.0, surface: StringName = &"") -> void:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = height
	s.radial_segments = 16
	s.rings = 8
	mesh(s, at, color, Vector3.ZERO, emission, surface)


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


func solid_box(base: Vector3, size: Vector3, color: Color, rot_y: float = 0.0, surface: StringName = &"") -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	collider(base, shape, size.y, rot_y)
	box(base + Vector3.UP * size.y / 2.0, size, color, rot_y, 0.0, surface)


func solid_round(base: Vector3, radius: float, height: float) -> void:
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	collider(base, shape, height)


func ground(center: Vector3, size: Vector2, color: Color, surface: StringName = &"grass") -> void:
	var p := PlaneMesh.new()
	p.size = size
	mesh(p, center, color, Vector3.ZERO, 0.0, surface)


func disk(center: Vector3, radius: float, color: Color, surface: StringName = &"slabs") -> void:
	cylinder(center, radius, radius, 0.02, color, 24, 0.0, surface)


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
func scatter(m: Mesh, count: int, area_min: Vector2, area_max: Vector2, color: Color, scale_range: Vector2, avoid: Callable = Callable(), own_materials: bool = false) -> void:
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
	if not own_materials:
		mi.material_override = SSGraphics.foliage_material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 200.0   # grass / flowers: never past the far fog
	root.add_child(mi)


func grass(area_min: Vector2, area_max: Vector2, count: int, color: Color, avoid: Callable = Callable()) -> void:
	var tuft := CylinderMesh.new()
	tuft.top_radius = 0.0
	tuft.bottom_radius = 0.12
	tuft.height = 0.45
	tuft.radial_segments = 4
	var ss_grass: Mesh = SSProps.mesh("SM_ENV_FOLIAGE_KNFRST_Grass02", SSProps.FOREST) if ss_forest else null
	if ss_grass != null:   # real SS grass clumps, same draws as the tufts
		scatter(ss_grass, count, area_min, area_max, color, Vector2(1.8, 3.2), avoid, true)
		return
	scatter(tuft, count, area_min, area_max, color, Vector2(0.7, 1.4), avoid)


func flowers(area_min: Vector2, area_max: Vector2, count: int, avoid: Callable = Callable()) -> void:
	var bloom := SphereMesh.new()
	bloom.radius = 0.09
	bloom.height = 0.18
	bloom.radial_segments = 6
	bloom.rings = 3
	var ss_flowers: Array[String] = ["SM_ENV_FOLIAGE_KNFRST_Flower_Yellow01", "SM_ENV_FOLIAGE_KNFRST_Flower_Purple01", "SM_ENV_FOLIAGE_KNFRST_Flower_White01"]
	var i: int = 0
	for color: Color in [Color(1.0, 0.85, 0.3), Color(1.0, 0.55, 0.7), Color(0.85, 0.85, 1.0)]:
		var ss_flower: Mesh = SSProps.mesh(ss_flowers[i], SSProps.FOREST) if ss_forest else null
		i += 1
		if ss_flower != null:
			scatter(ss_flower, count / 3, area_min, area_max, color, Vector2(1.6, 2.4), avoid, true)
		else:
			scatter(bloom, count / 3, area_min, area_max, color, Vector2(0.8, 1.3), avoid)


# --- Props ----------------------------------------------------------------------------
# Surfaces are Shinobi Striker Konoha / Konoha-forest textures (see SSGraphics.TEXTURES).

func _ss_ground(surface: StringName) -> Material:
	if not ss_kit or not SS_GROUNDS.has(surface):
		return null
	var g: Array = SS_GROUNDS[surface]
	return SSProps.ground_material(g[0], g[1], g[2], g[3])


## Real SS mesh scaled uniformly to fit a footprint (x, z in the rotated frame). Visual only:
## never touches colliders or rng, so layouts stay identical with or without local assets.
func ss_visual(name: String, base: Vector3, rot_y: float, fit: Vector2, max_scale: float = 1.0, stretch: Vector3 = Vector3.ONE, set_name: String = SSProps.KONOHA) -> bool:
	if not (ss_forest if set_name == SSProps.FOREST else ss_kit):
		return false
	var size: Vector3 = SSProps.size_of(name, set_name)
	var inst: Node3D = SSProps.instance(name, set_name)
	if inst == null or size.x <= 0.0 or size.z <= 0.0:
		return false
	var s: float = minf(max_scale, minf(fit.x / size.x, fit.y / size.z)) if fit != Vector2.ZERO else max_scale
	inst.position = base
	inst.rotation_degrees.y = rot_y
	inst.scale = Vector3.ONE * s * stretch
	_cull(inst, size * s * stretch)
	root.add_child(inst)
	return true


## Optimisation: SS meshes are dense. Hide them beyond the top-down view (with a fade), and
## small props do not cast shadows. Big landmarks (walls, gate, Hokage tower) stay visible.
func _cull(inst: Node3D, size: Vector3) -> void:
	var extent: float = maxf(size.x, size.z)
	var small: bool = maxf(extent, size.y) < 2.5
	for node: Node in inst.find_children("*", "GeometryInstance3D", true, false):
		var gi := node as GeometryInstance3D
		if small:
			gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if extent < 25.0:
			gi.visibility_range_end = 62.0 + extent
			gi.visibility_range_end_margin = 6.0
			gi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


## Japanese-style house: plaster walls, wooden door, lit paper windows, metal roof.
## With the SS kit: a real Konoha building on the same footprint.
func house(base: Vector3, size: Vector3, wall: Color, roof: Color, rot_y: float = 0.0) -> void:
	if ss_kit:
		var shape := BoxShape3D.new()
		shape.size = size
		collider(base, shape, size.y, rot_y)
		var name: String = SS_HOUSES[_ss_house % SS_HOUSES.size()]
		_ss_house += 1
		if ss_visual(name, base, rot_y, Vector2(size.x, size.z) * 1.15):
			return
	solid_box(base, size, wall, rot_y, &"plaster")
	if not visuals:
		return
	var basis := Basis(Vector3.UP, deg_to_rad(rot_y))
	var front: Vector3 = basis * Vector3(0, 0, size.z / 2.0 + 0.03)
	box(base + front + Vector3.UP * 1.0, Vector3(1.1, 2.0, 0.08), Color(0.3, 0.2, 0.12), rot_y, 0.0, &"wood")
	for side: float in [-1.0, 1.0]:
		var w: Vector3 = basis * Vector3(side * size.x * 0.3, 0, size.z / 2.0 + 0.03)
		box(base + w + Vector3.UP * (size.y * 0.6), Vector3(0.9, 0.8, 0.06), Color(1.0, 0.9, 0.6), rot_y, 0.4)
	box(base + Vector3.UP * (size.y + 0.15), Vector3(size.x + 1.4, 0.3, size.z + 1.4), roof.darkened(0.2), rot_y, 0.0, &"wood")
	var r := CylinderMesh.new()
	r.top_radius = 0.0
	r.bottom_radius = maxf(size.x, size.z) * 0.78
	r.height = maxf(size.x, size.z) * 0.38
	r.radial_segments = 4
	mesh(r, base + Vector3.UP * (size.y + 0.3 + r.height / 2.0), roof, Vector3(0, rot_y + 45.0, 0), 0.0, &"roof")


func lantern(at: Vector3) -> void:
	solid_round(at, 0.12, 2.0)
	if ss_visual("SM_ENV_Props_Standing_Lantern_01", at, 90.0, Vector2.ZERO):
		return
	cylinder(at + Vector3.UP * 1.0, 0.06, 0.08, 2.0, Color(0.25, 0.18, 0.12), 6, 0.0, &"wood")
	box(at + Vector3(0.25, 2.0, 0), Vector3(0.6, 0.06, 0.06), Color(0.25, 0.18, 0.12), 0.0, 0.0, &"wood")
	sphere(at + Vector3(0.45, 1.75, 0), 0.22, 0.5, Color(1.0, 0.35, 0.2), 1.6)


func round_tree(at: Vector3, foliage: Color, size: float = 1.0, collide: bool = true) -> void:
	if collide:
		solid_round(at, 0.4 * size, 2.0)
	var ss: bool = ss_visual(SS_TREES[_pick(at, 3)], at, _yaw(at), Vector2.ZERO, 0.42 * size, Vector3.ONE, SSProps.FOREST)
	var keep: bool = visuals
	visuals = visuals and not ss   # primitive pass still runs: same rng draws
	cylinder(at + Vector3.UP * 1.3 * size, 0.25 * size, 0.38 * size, 2.6 * size, Color(0.4, 0.27, 0.16), 8, 0.0, &"wood")
	for i in 3:
		var off := Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6)) * size
		sphere(at + off + Vector3.UP * (3.0 + i * 0.7) * size, (1.7 - i * 0.35) * size, (2.6 - i * 0.5) * size, foliage.lightened(i * 0.08), 0.0, &"leaf")
	visuals = keep


func pine(at: Vector3, size: float = 1.0) -> void:
	solid_round(at, 0.35 * size, 2.0)
	if ss_visual(SS_TREES[1 + _pick(at, 2)], at, _yaw(at), Vector2.ZERO, 0.62 * size, Vector3.ONE, SSProps.FOREST):
		return
	cylinder(at + Vector3.UP * 0.8 * size, 0.2 * size, 0.3 * size, 1.6 * size, Color(0.38, 0.25, 0.15), 6, 0.0, &"wood")
	for i in 3:
		cylinder(at + Vector3.UP * (2.0 + i * 1.1) * size, 0.0, (1.7 - i * 0.45) * size, 2.0 * size, Color(0.16, 0.38, 0.22).lightened(i * 0.05), 8, 0.0, &"leaf")


func bush(at: Vector3, color: Color) -> void:
	for i in 3:
		var off := Vector3(rng.randf_range(-0.5, 0.5), 0, rng.randf_range(-0.5, 0.5))
		if ss_visual("SM_ENV_FOLIAGE_KNFRST_Bush01", at + off * 1.6, _yaw(at + off), Vector2.ZERO, 2.1, Vector3.ONE, SSProps.FOREST):
			rng.randf_range(0.45, 0.7)   # keep the primitive draws
			rng.randf_range(0.6, 0.9)
			rng.randf_range(-0.05, 0.1)
			continue
		sphere(at + off + Vector3.UP * 0.35, rng.randf_range(0.45, 0.7), rng.randf_range(0.6, 0.9), color.lightened(rng.randf_range(-0.05, 0.1)), 0.0, &"leaf")


func rock(at: Vector3, radius: float, color: Color = Color(0.52, 0.5, 0.5)) -> void:
	solid_round(at, radius * 0.9, 2.0)
	if ss_visual("SM_ENV_KNFRST_RockMiddle_A", at, _yaw(at), Vector2.ZERO, radius * 2.1 / 4.5, Vector3.ONE, SSProps.FOREST):
		return
	sphere(at + Vector3.UP * radius * 0.3, radius, radius * 1.2, color, 0.0, &"stone")
	sphere(at + Vector3(radius * 0.5, radius * 0.2, radius * 0.3), radius * 0.55, radius * 0.7, color.darkened(0.1), 0.0, &"stone")


func campfire(at: Vector3) -> void:
	if ss_kit:
		ss_visual("SM_ENV_Props_Barrel_01", at + Vector3(1.6, 0, 0.8), 0.0, Vector2.ZERO)
		ss_visual("SM_ENV_Props_Crate_01", at + Vector3(-1.7, 0, -0.9), 20.0, Vector2.ZERO)
	for i in 4:
		box(at + Vector3.UP * 0.12, Vector3(1.0, 0.16, 0.16), Color(0.35, 0.22, 0.12), i * 45.0, 0.0, &"wood")
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
	mesh(t, at + Vector3.UP * 1.1, color, Vector3(0, rot_y, 0), 0.0, &"plaster")


func fence(from: Vector3, to: Vector3, color: Color = Color(0.45, 0.32, 0.2)) -> void:
	var dir: Vector3 = to - from
	if ss_kit:   # SS fence sections (4.3 m) along the line
		var yaw_ss: float = rad_to_deg(atan2(dir.x, dir.z)) + 90.0
		var n_ss: int = maxi(1, roundi(dir.length() / 4.3))
		for i in n_ss:
			ss_visual("SM_ENV_KNVLLG_Fence_Large", from + dir * (i + 0.5) / n_ss, yaw_ss, Vector2.ZERO, 1.0, Vector3(dir.length() / n_ss / 4.33, 1.0, 1.0))
		return
	var steps: int = maxi(1, int(dir.length() / 2.0))
	for i in steps + 1:
		cylinder(from + dir * float(i) / steps + Vector3.UP * 0.5, 0.08, 0.08, 1.0, color, 6, 0.0, &"wood")
	var mid: Vector3 = (from + to) / 2.0
	var yaw: float = rad_to_deg(atan2(dir.x, dir.z))
	box(mid + Vector3.UP * 0.75, Vector3(0.08, 0.1, dir.length()), color, yaw, 0.0, &"wood")
	box(mid + Vector3.UP * 0.4, Vector3(0.08, 0.1, dir.length()), color, yaw, 0.0, &"wood")


func ruin_pillar(at: Vector3) -> void:
	var h: float = rng.randf_range(1.2, 3.5)
	solid_round(at, 0.6, 2.0)
	cylinder(at + Vector3.UP * h / 2.0, 0.5, 0.6, h, Color(0.62, 0.6, 0.56), 8, 0.0, &"stone")
	if rng.randf() < 0.5:
		box(at + Vector3(0.8, 0.2, 0.3), Vector3(1.2, 0.4, 0.6), Color(0.58, 0.56, 0.52), rng.randf() * 90.0, 0.0, &"stone")


func mountain(at: Vector3, radius: float, height: float, color: Color) -> void:
	cylinder(at + Vector3.UP * height / 2.0, radius * 0.08, radius, height, color, 7, rng.randf() * 60.0, &"stone")
	cylinder(at + Vector3.UP * (height - height * 0.12), 0.0, radius * 0.22, height * 0.24, Color(0.95, 0.95, 0.97), 7)


## Kage building: round tower with a red roof and the village kanji-like sign.
func kage_tower(at: Vector3, wall: Color, roof: Color, text: String) -> void:
	var shape := CylinderShape3D.new()
	shape.radius = 5.0
	shape.height = 9.0
	collider(at, shape, 9.0)
	if ss_visual("SM_ENV_KNVLLG_AreaK_Building_A2", at, 180.0, Vector2(12.0, 12.0)):
		return
	cylinder(at + Vector3.UP * 4.5, 4.6, 5.0, 9.0, wall, 20, 0.0, &"plaster")
	cylinder(at + Vector3.UP * 9.3, 5.8, 5.8, 0.4, roof.darkened(0.2), 20, 0.0, &"wood")
	cylinder(at + Vector3.UP * 10.6, 1.0, 5.4, 2.4, roof, 20, 0.0, &"roof")
	box(at + Vector3(0, 6.5, 4.75), Vector3(2.4, 1.6, 0.2), Color(1, 1, 1))
	label(at + Vector3(0, 6.5, 5.0), text, 120, Color(0.75, 0.1, 0.1))
	box(at + Vector3(0, 1.1, 4.95), Vector3(1.6, 2.2, 0.15), Color(0.3, 0.2, 0.12), 0.0, 0.0, &"wood")


func statue(at: Vector3, color: Color) -> void:
	solid_round(at, 1.6, 2.0)
	cylinder(at + Vector3.UP * 0.4, 1.6, 1.8, 0.8, Color(0.6, 0.58, 0.55), 16, 0.0, &"stone")
	cylinder(at + Vector3.UP * 1.6, 0.45, 0.6, 1.6, color, 10, 0.0, &"stone")
	sphere(at + Vector3.UP * 2.7, 0.45, 0.9, color, 0.0, &"stone")


## `konoha_gate`: with the SS kit, the real Konoha village gate replaces the torii visual.
func torii(at: Vector3, width: float, color: Color, konoha_gate: bool = true) -> void:
	for side: float in [-1.0, 1.0]:
		solid_round(at + Vector3(0, 0, side * width / 2.0), 0.5, 6.0)
	# SS: the real Konoha gate, its two pillars on the gate posts.
	if konoha_gate and ss_visual("SM_ENV_KNVLLG_gate_A", at, 90.0, Vector2.ZERO, width / 20.0):
		return
	for side: float in [-1.0, 1.0]:
		var p: Vector3 = at + Vector3(0, 0, side * width / 2.0)
		cylinder(p + Vector3.UP * 3.0, 0.4, 0.45, 6.0, color, 10, 0.0, &"wood")
	box(at + Vector3.UP * 6.2, Vector3(1.2, 0.5, width + 3.0), color, 0.0, 0.0, &"wood")
	box(at + Vector3.UP * 6.7, Vector3(1.4, 0.3, width + 4.0), color.darkened(0.4), 0.0, 0.0, &"wood")
	box(at + Vector3.UP * 5.2, Vector3(0.6, 0.35, width), color, 0.0, 0.0, &"wood")

## Deterministic variant / yaw from a position (no rng: draws must not depend on assets).
func _pick(at: Vector3, n: int) -> int:
	return absi(int(at.x * 7.0) * 31 + int(at.z * 13.0)) % n


func _yaw(at: Vector3) -> float:
	return fposmod(at.x * 47.0 + at.z * 91.0, 360.0)