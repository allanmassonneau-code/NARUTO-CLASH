class_name CombatFx
extends MeshInstance3D
## Short-lived readability shapes (rings, arcs, decoy logs). Presentation only.

var _life: float = 0.2
var _age: float = 0.0
var _material: StandardMaterial3D
var _base_alpha: float = 0.8


## False on headless servers: no visuals are created there.
static func is_enabled() -> bool:
	return DisplayServer.get_name() != "headless"


static func ring(anchor: Node, center: Vector3, radius: float, color: Color, life: float) -> void:
	Net.broadcast_fx(Net.Fx.RING, center, Vector3.ZERO, radius, life, color)
	if not is_enabled():
		return
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in 33:
		var a: float = TAU * i / 32.0
		im.surface_add_vertex(Vector3(cos(a) * radius, 0.05, sin(a) * radius))
	im.surface_end()
	_spawn(anchor, im, Transform3D(Basis.IDENTITY, HitQuery.flat(center)), color, life)


static func arc(anchor: Node, origin: Vector3, direction: Vector3, radius: float, degrees: float, color: Color, life: float) -> void:
	Net.broadcast_fx(Net.Fx.ARC, origin, direction, radius, degrees, color)
	if not is_enabled():
		return
	# Narrow or long swings are the heavy finishers.
	SpellVfx.swipe(anchor, origin, direction, radius, degrees, color, degrees <= 60.0 or radius >= 2.3)


## Kawarimi placeholder: a brown log left where the character was.
static func log_decoy(anchor: Node, at: Vector3) -> void:
	Net.broadcast_fx(Net.Fx.LOG, at, Vector3.ZERO, 0.0, 0.0, Color.WHITE)
	if not is_enabled():
		return
	SpellVfx.smoke(anchor, at, 0.9)
	var box := BoxMesh.new()
	box.size = Vector3(0.5, 1.4, 0.5)
	_spawn(anchor, box, Transform3D(Basis.IDENTITY, HitQuery.flat(at) + Vector3.UP * 0.7), Color(0.55, 0.35, 0.18), 1.2)


## Persistent ground zone (substitution area). The caller frees it; null
## on headless servers.
static func zone_marker(anchor: Node, center: Vector3, radius: float, color: Color) -> Node3D:
	if not is_enabled():
		return null
	var root: Node = anchor.get_parent() if anchor.get_parent() != null else anchor
	var zone := Node3D.new()
	zone.add_to_group(&"round_entities")
	root.add_child(zone)
	zone.global_position = HitQuery.flat(center) + Vector3.UP * 0.04
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.02
	cyl.radial_segments = 48
	disc.mesh = cyl
	disc.material_override = _zone_material(Color(color, 0.12))
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	zone.add_child(disc)
	var edge := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius - 0.1
	torus.outer_radius = radius
	torus.rings = 48
	edge.mesh = torus
	edge.material_override = _zone_material(color)
	edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	zone.add_child(edge)
	return zone


static func _zone_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Rising, fading damage number (client-side feedback only).
static func damage_number(anchor: Node, at: Vector3, amount: float, color: Color, text: String = "") -> void:
	if not is_enabled():
		return
	var label := Label3D.new()
	label.text = text if text != "" else str(roundi(amount))
	label.font_size = 38 if text != "" else (64 if amount >= 15.0 else 48)
	label.outline_size = 14
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.01
	label.add_to_group(&"round_entities")
	var root: Node = anchor.get_parent() if anchor.get_parent() != null else anchor
	root.add_child(label)
	label.global_position = at + Vector3(randf_range(-0.3, 0.3), 0.0, 0.0)
	var tween := label.create_tween().set_parallel(true)
	tween.tween_property(label, "global_position", label.global_position + Vector3.UP * 0.9, 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(label, "scale", Vector3.ONE * 1.35, 0.08)
	tween.tween_property(label, "modulate:a", 0.0, 0.35).set_delay(0.4)
	tween.chain().tween_callback(label.queue_free)


## Gerbe of physical sparks (one-shot particles) flying off a hit.
static func sparks(anchor: Node, center: Vector3, color: Color, amount: int) -> void:
	if not is_enabled():
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = 0.45
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 10.0
	p.gravity = Vector3(0, -18, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.05, 0.05, 0.22)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color.lightened(0.3)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.0
	mesh.material = mat
	p.mesh = mesh
	p.particle_flag_align_y = true
	p.add_to_group(&"round_entities")
	var root: Node = anchor.get_parent() if anchor.get_parent() != null else anchor
	root.add_child(p)
	p.global_position = center
	p.emitting = true
	p.finished.connect(p.queue_free)


## Star burst of short lines: impact spark.
static func burst(anchor: Node, center: Vector3, color: Color, size: float) -> void:
	if not is_enabled():
		return
	SSVfx.sprite(anchor, &"shock", center, size * 1.3, color, 0.22, false, 0.0, 1.8)
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in 10:
		var dir := Vector3(randf_range(-1, 1), randf_range(-0.6, 1), randf_range(-1, 1)).normalized()
		im.surface_add_vertex(dir * size * 0.25)
		im.surface_add_vertex(dir * size * randf_range(0.7, 1.1))
	im.surface_end()
	_spawn(anchor, im, Transform3D(Basis.IDENTITY, center), color, 0.18)
	var flash := SphereMesh.new()
	flash.radius = size * 0.35
	flash.height = size * 0.7
	_spawn(anchor, flash, Transform3D(Basis.IDENTITY, center), Color(1, 1, 1, 0.7), 0.1)


static func _spawn(anchor: Node, mesh: Mesh, xform: Transform3D, color: Color, life: float) -> void:
	if not is_enabled():
		return
	var root: Node = anchor.get_parent() if anchor.get_parent() != null else anchor
	var fx := CombatFx.new()
	fx.mesh = mesh
	fx._life = life
	fx._base_alpha = color.a
	fx._material = StandardMaterial3D.new()
	fx._material.albedo_color = color
	fx._material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fx._material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fx._material.cull_mode = BaseMaterial3D.CULL_DISABLED
	fx.material_override = fx._material
	fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx.add_to_group(&"round_entities")
	root.add_child(fx)
	fx.global_transform = xform


func _process(delta: float) -> void:
	_age += delta
	if _age >= _life:
		queue_free()
		return
	_material.albedo_color.a = _base_alpha * (1.0 - _age / _life)
