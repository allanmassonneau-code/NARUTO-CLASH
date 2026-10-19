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
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var half: float = deg_to_rad(degrees) * 0.5
	var steps: int = 12
	for i in steps:
		var a0: float = -half + (2.0 * half) * i / steps
		var a1: float = -half + (2.0 * half) * (i + 1) / steps
		im.surface_add_vertex(Vector3(0.0, 0.05, 0.0))
		im.surface_add_vertex(direction.rotated(Vector3.UP, a0) * radius + Vector3.UP * 0.05)
		im.surface_add_vertex(direction.rotated(Vector3.UP, a1) * radius + Vector3.UP * 0.05)
	im.surface_end()
	_spawn(anchor, im, Transform3D(Basis.IDENTITY, HitQuery.flat(origin)), Color(color, 0.45), life)


## Kawarimi placeholder: a brown log left where the character was.
static func log_decoy(anchor: Node, at: Vector3) -> void:
	Net.broadcast_fx(Net.Fx.LOG, at, Vector3.ZERO, 0.0, 0.0, Color.WHITE)
	if not is_enabled():
		return
	var box := BoxMesh.new()
	box.size = Vector3(0.5, 1.4, 0.5)
	_spawn(anchor, box, Transform3D(Basis.IDENTITY, HitQuery.flat(at) + Vector3.UP * 0.7), Color(0.55, 0.35, 0.18), 1.2)


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
