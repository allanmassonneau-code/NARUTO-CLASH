class_name ShinobiModel
extends Node3D
## Builds a stylised shinobi out of primitives from a ShinobiLook and animates
## it procedurally (run cycle, cast poses). Never affects gameplay.

const HEADBAND_CLOTH := Color(0.12, 0.16, 0.3)
const HEADBAND_PLATE := Color(0.78, 0.8, 0.84)

var _parts: Array[GeometryInstance3D] = []
var _overlay := StandardMaterial3D.new()
var _leg_l: Node3D
var _leg_r: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _torso: Node3D
var _cycle: float = 0.0


func build(look: ShinobiLook) -> void:
	for child: Node in get_children():
		child.queue_free()
	_parts.clear()
	_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_overlay.albedo_color = Color(1, 1, 1, 0)

	_leg_l = _pivot(self, Vector3(-0.13, 0.8, 0.0))
	_leg_r = _pivot(self, Vector3(0.13, 0.8, 0.0))
	for leg: Node3D in [_leg_l, _leg_r]:
		_capsule(leg, Vector3(0, -0.38, 0), 0.12, 0.8, look.pants)
		_box(leg, Vector3(0, -0.76, -0.05), Vector3(0.18, 0.08, 0.3), look.accent)

	_torso = _pivot(self, Vector3(0, 0.8, 0))
	var chest := _capsule(_torso, Vector3(0, 0.3, 0), 0.27, 0.78, look.top)
	chest.scale = Vector3(1.0, 1.0, 0.75)
	_box(_torso, Vector3(0, 0.02, 0), Vector3(0.5, 0.08, 0.38), look.accent)  # belt
	if look.flak_vest:
		var vest := _capsule(_torso, Vector3(0, 0.36, 0), 0.3, 0.6, Color(0.36, 0.45, 0.27))
		vest.scale = Vector3(1.0, 1.0, 0.8)
	_arm_l = _pivot(_torso, Vector3(-0.34, 0.54, 0))
	_arm_r = _pivot(_torso, Vector3(0.34, 0.54, 0))
	for arm: Node3D in [_arm_l, _arm_r]:
		_capsule(arm, Vector3(0, -0.27, 0), 0.085, 0.6, look.sleeves)
		_sphere(arm, Vector3(0, -0.58, 0), 0.08, look.skin)

	var head := _pivot(_torso, Vector3(0, 0.84, 0))
	_sphere(head, Vector3.ZERO, 0.23, look.skin)
	for x: float in [-0.08, 0.08]:
		if look.headband and look.hair == ShinobiLook.Hair.SWEPT and x < 0.0:
			continue  # Kakashi: headband covers the left eye
		_box(head, Vector3(x, 0.03, -0.2), Vector3(0.06, 0.07, 0.04), look.eye_color)
	if look.mask:
		_box(head, Vector3(0, -0.1, -0.08), Vector3(0.44, 0.16, 0.34), HEADBAND_CLOTH)
	if look.headband:
		var band := _cylinder(head, Vector3(0, 0.1, 0), 0.24, 0.07, HEADBAND_CLOTH)
		if look.hair == ShinobiLook.Hair.SWEPT:
			band.rotation_degrees.z = -14.0
		_box(head, Vector3(0, 0.1, -0.235), Vector3(0.17, 0.08, 0.025), HEADBAND_PLATE)
	_build_hair(head, look)


## Per-frame visual state from CharacterPresentation.
func animate(delta: float, planar_speed: float, pose: StringName, tint: Color, fade: float) -> void:
	var run: float = clampf(planar_speed / 6.5, 0.0, 1.0)
	_cycle += delta * (4.0 + 8.0 * run)
	var swing: float = sin(_cycle) * 0.75 * run
	_leg_l.rotation.x = swing
	_leg_r.rotation.x = -swing
	_arm_l.rotation.x = -swing * 0.7
	_arm_r.rotation.x = swing * 0.7
	_arm_l.rotation.z = -0.15
	_arm_r.rotation.z = 0.15
	_torso.rotation.x = -0.12 * run
	_torso.position.y = 0.8 + absf(sin(_cycle)) * 0.04 * run
	match pose:
		&"windup":
			_arm_r.rotation.x = 0.9
			_arm_l.rotation.x = -0.5
			_torso.rotation.y = 0.35
		&"strike":
			_arm_r.rotation.x = -1.55
			_arm_l.rotation.x = -1.2
			_torso.rotation.y = -0.2
			_torso.rotation.x = -0.25
		&"guard":
			_arm_r.rotation.x = -1.4
			_arm_l.rotation.x = -1.4
			_arm_r.rotation.z = -0.5
			_arm_l.rotation.z = 0.5
		&"stunned":
			_torso.rotation.z = sin(_cycle * 2.0) * 0.15
			_arm_l.rotation.z = -0.6
			_arm_r.rotation.z = 0.6
		_:
			_torso.rotation.y = 0.0
			_torso.rotation.z = 0.0
	_overlay.albedo_color = tint
	for part: GeometryInstance3D in _parts:
		part.transparency = fade


func _build_hair(head: Node3D, look: ShinobiLook) -> void:
	var c: Color = look.hair_color
	match look.hair:
		ShinobiLook.Hair.SPIKY:
			_sphere(head, Vector3(0, 0.08, 0.03), 0.235, c).scale = Vector3(1, 0.8, 1)
			for i in 9:
				var a: float = TAU * i / 9.0
				var dir := Vector3(sin(a) * 0.6, 1.0, cos(a) * 0.6 + 0.2).normalized()
				_spike(head, dir * 0.2 + Vector3(0, 0.06, 0), dir, 0.09, 0.3, c)
		ShinobiLook.Hair.DUCK_TAIL:
			_sphere(head, Vector3(0, 0.07, 0.04), 0.24, c).scale = Vector3(1, 0.85, 1)
			for i in 6:
				var a: float = lerpf(-0.9, 0.9, i / 5.0)
				var dir := Vector3(sin(a) * 0.7, 0.55, 1.0).normalized()
				_spike(head, Vector3(0, 0.1, 0.15), dir, 0.09, 0.36, c)
			for x: float in [-0.19, 0.19]:
				_spike(head, Vector3(x, 0.05, -0.12), Vector3(x * 0.5, -1.0, -0.2).normalized(), 0.06, 0.26, c)
		ShinobiLook.Hair.LONG:
			_sphere(head, Vector3(0, 0.06, 0.03), 0.25, c).scale = Vector3(1, 0.9, 1)
			_box(head, Vector3(0, -0.2, 0.12), Vector3(0.42, 0.5, 0.16), c)
			for x: float in [-0.17, 0.17]:
				_box(head, Vector3(x, -0.12, -0.08), Vector3(0.08, 0.34, 0.12), c)
		ShinobiLook.Hair.SWEPT:
			_sphere(head, Vector3(0, 0.07, 0.03), 0.235, c).scale = Vector3(1, 0.8, 1)
			for i in 7:
				var a: float = lerpf(-0.8, 0.8, i / 6.0)
				var dir := Vector3(0.75 + sin(a) * 0.3, 0.9, cos(a) * 0.4).normalized()
				_spike(head, Vector3(-0.05, 0.15, 0.0), dir, 0.08, 0.34, c)


func _pivot(parent: Node3D, at: Vector3) -> Node3D:
	var node := Node3D.new()
	node.position = at
	parent.add_child(node)
	return node


func _add(parent: Node3D, mesh: Mesh, at: Vector3, color: Color) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	(mesh as PrimitiveMesh).material = mat
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = at
	inst.material_overlay = _overlay
	parent.add_child(inst)
	_parts.append(inst)
	return inst


func _capsule(parent: Node3D, at: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	mesh.rings = 6
	return _add(parent, mesh, at, color)


func _sphere(parent: Node3D, at: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 18
	mesh.rings = 10
	return _add(parent, mesh, at, color)


func _box(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _add(parent, mesh, at, color)


func _cylinder(parent: Node3D, at: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 18
	return _add(parent, mesh, at, color)


## Cone pointing along `dir`, base centred at `at`.
func _spike(parent: Node3D, at: Vector3, dir: Vector3, radius: float, length: float, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 8
	var inst := _add(parent, mesh, at + dir * length * 0.5, color)
	var up: Vector3 = dir.normalized()
	var side: Vector3 = up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	inst.basis = Basis(side, up, side.cross(up)).orthonormalized()
	return inst
