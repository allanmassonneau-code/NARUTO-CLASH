class_name SpellVfx
## Jutsu visual effects, keyed by AbilityData.vfx. Presentation only:
## never created on headless servers, never affects the simulation.
## Effects are procedural (primitive meshes, jagged lines, tweens).

const SMOKE := Color(0.92, 0.92, 0.95, 0.75)


# --- Entry points (called by CharacterPresentation / Projectile / GroundArea)

## Startup (charging) effect. Returns a node to keep while the jutsu is held.
static func on_startup(c: CombatCharacter, a: AbilityData, model: ShinobiModel) -> Node3D:
	if not CombatFx.is_enabled():
		return null
	var hand: Node3D = model.hand_r() if model != null else null
	SSVfx.for_spell(c, a.vfx, hand.global_position if hand != null and hand.is_inside_tree() else c.global_position + Vector3.UP * 1.1, a.color, false)
	match a.vfx:
		&"rasengan":
			return _orb(model.hand_r(), Color(0.35, 0.65, 1.0), 0.3, a.startup_time)
		&"chidori", &"raikiri":
			return _lightning_hand(model.hand_r(), Color(0.55, 0.9, 1.0) if a.vfx == &"chidori" else Color(0.85, 0.95, 1.0))
		&"rasenshuriken":
			return _shuriken_held(model.hand_r(), a.startup_time)
		&"katon":
			return _orb(model.hand_r(), Color(1.0, 0.45, 0.1), 0.14, a.startup_time)
		&"clone":
			smoke(c, c.global_position + c.facing.facing_direction * 0.8, 0.8)
		&"heal", &"byakugou":
			return _heal_aura(c, Color(0.35, 1.0, 0.5) if a.vfx == &"heal" else Color(0.7, 0.4, 1.0), a.startup_time + 0.2)
		&"sharingan":
			return _tomoe_ring(c)
		&"shunshin", &"leap":
			smoke(c, c.global_position, 0.7)
		&"stomp":
			return _orb(model.hand_r(), Color(1.0, 0.5, 0.7), 0.12, a.startup_time)
		&"gates":
			return _heal_aura(c, Color(0.3, 1.0, 0.4), a.startup_time + 0.4)
		&"kaiten":
			return _dome(c, Color(0.55, 0.75, 1.0), 1.5)
		&"crow":
			return _dome(c, Color(0.15, 0.1, 0.15), 1.0)
		&"gentle_fist", &"palms":
			return _orb(model.hand_r(), Color(0.5, 0.75, 1.0), 0.1, a.startup_time)
		&"tsukuyomi":
			return _orb(model.hand_r(), Color(0.9, 0.05, 0.1), 0.12, a.startup_time)
		&"susanoo":
			return _dome(c, Color(0.6, 0.3, 0.95), 1.6)
		&"flash":
			return _lightning_hand(model.hand_r(), Color(1.0, 0.9, 0.35))
	return null


## Called when the jutsu goes active (the hit comes out).
static func on_active(c: CombatCharacter, a: AbilityData, held: Node3D) -> void:
	if not CombatFx.is_enabled():
		return
	SSVfx.for_spell(c, a.vfx, c.global_position + Vector3.UP * 1.0 + c.facing.facing_direction * 1.2, a.color, true)
	match a.vfx:
		&"leap":
			dust_ring(c, c.global_position, 1.4)
		&"heal":
			_column(c, c.global_position, Color(0.35, 1.0, 0.5), 1.0)
		&"byakugou":
			_column(c, c.global_position, Color(0.7, 0.4, 1.0), 1.4)
			_diamond(c, c.global_position + Vector3.UP * 2.3)
		&"gates":
			_column(c, c.global_position, Color(0.35, 1.0, 0.45), 1.1)
			dust_ring(c, c.global_position, 2.0)
		&"flash":
			_column(c, c.global_position, Color(1.0, 0.9, 0.35), 0.8)
		&"peacock":
			_explosion(c, c.global_position + c.facing.facing_direction * 1.6 + Vector3.UP, Color(1.0, 0.55, 0.15), 1.4)
		&"susanoo":
			_explosion(c, c.global_position + c.facing.facing_direction * 2.4 + Vector3.UP, Color(0.6, 0.3, 0.95), 2.0)
	if a.kind == AbilityData.Kind.MELEE_ARC and a.knockback_speed > 0.0:
		dust_ring(c, c.global_position, 1.0)


## Called when the active window ends (or the cast is interrupted).
static func on_end(c: CombatCharacter, a: AbilityData, held: Node3D, interrupted: bool) -> void:
	if held != null and is_instance_valid(held):
		var at: Vector3 = held.global_position
		held.queue_free()
		if not interrupted and a.vfx in [&"rasengan", &"chidori", &"raikiri"]:
			CombatFx.burst(c, at, Color(0.7, 0.9, 1.0), 1.0)
	if interrupted or not CombatFx.is_enabled():
		return
	match a.vfx:
		&"shunshin":
			smoke(c, c.global_position, 0.7)
		&"leap":
			dust_ring(c, c.global_position, 1.8)


## Afterimage of the body during dashes.
static func afterimage(c: CombatCharacter, color: Color) -> void:
	if not CombatFx.is_enabled():
		return
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.32
	mesh.height = 1.7
	var node := _world_node(c, mesh, Color(color, 0.35), true)
	node.global_position = c.global_position + Vector3.UP * 0.95
	_animate(node, 0.22, func(n: Node3D, t: float) -> void:
		(n as MeshInstance3D).transparency = t
		n.scale = Vector3.ONE * (1.0 - 0.3 * t))


## Projectile body by vfx (falls back to a glowing sphere).
static func projectile_visual(p: Projectile) -> void:
	if not CombatFx.is_enabled():
		return
	var a: AbilityData = p.ability
	match a.vfx:
		&"clone":
			var clone := ShinobiModel.new()
			p.add_child(clone)
			clone.build(p.source.data.look if p.source != null else ShinobiLook.new())
			clone.position = Vector3.DOWN * HitQuery.BODY_HEIGHT
			clone.basis = Basis.looking_at(p.direction, Vector3.UP)
			clone.scale = Vector3.ONE * 0.95
			p.set_meta(&"clone", clone)
		&"katon":
			for i in 3:
				var flame := _mesh_node(p, _sphere_mesh(a.hit_radius * (1.0 - i * 0.25)), Color([Color(1, 0.35, 0.05), Color(1, 0.6, 0.15), Color(1, 0.9, 0.5)][i], 0.75 - i * 0.1), true)
				flame.set_meta(&"flicker", i)
		&"rasenshuriken":
			p.add_child(_shuriken(a.hit_radius))
		&"shadow":
			var blot := _mesh_node(p, _disk_mesh(a.hit_radius * 1.4), Color(0.02, 0.02, 0.05, 0.85), false)
			blot.position = Vector3.DOWN * (HitQuery.BODY_HEIGHT - 0.04)
			blot.scale = Vector3(1.0, 1.0, 1.8)
		_:
			_mesh_node(p, _sphere_mesh(a.hit_radius), Color(a.color, 0.9), true)


## Per-frame projectile visual update (spin, flicker, clone run cycle).
static func projectile_tick(p: Projectile, delta: float) -> void:
	if not CombatFx.is_enabled():
		return
	if p.has_meta(&"clone"):
		(p.get_meta(&"clone") as ShinobiModel).animate(delta, 9.0, &"", Color(1, 1, 1, 0), 0.0)
	for child: Node in p.get_children():
		if child.has_meta(&"spin"):
			(child as Node3D).rotate_y(delta * 22.0)
		if child.has_meta(&"flicker"):
			var i: int = child.get_meta(&"flicker")
			(child as Node3D).scale = Vector3.ONE * (1.0 + 0.15 * sin(p.age * 40.0 + i * 2.0))
	if p.ability.vfx == &"katon" and randf() < 0.5:
		_ember(p, p.global_position, Color(1.0, 0.5, 0.1))


static func projectile_impact(anchor: Node, at: Vector3, a: AbilityData) -> void:
	if not CombatFx.is_enabled():
		return
	if a.vfx == &"katon" or a.vfx == &"rasenshuriken":
		Sfx.play(&"boom", at, -2.0)
	match a.vfx:
		&"clone":
			smoke(anchor, HitQuery.flat(at), 0.9)
		&"katon":
			_explosion(anchor, at, Color(1.0, 0.45, 0.1), a.hit_radius * 2.2)
		&"rasenshuriken":
			_explosion(anchor, at, Color(0.7, 0.92, 1.0), a.hit_radius * 3.0)
			CombatFx.ring(anchor, at, a.hit_radius * 3.0, Color(0.8, 0.95, 1.0), 0.35)
		_:
			CombatFx.burst(anchor, at, a.color, 0.7)


## Extra telegraph decoration on ground areas (cloud for Kirin, spiral for Kamui).
static func area_decor(area: GroundArea) -> void:
	if not CombatFx.is_enabled():
		return
	match area.ability.vfx:
		&"kirin":
			for i in 5:
				var cloud := _mesh_node(area, _sphere_mesh(1.2 + randf() * 0.6), Color(0.25, 0.27, 0.35, 0.55), false)
				cloud.position = Vector3(randf_range(-1.5, 1.5), 7.0 + randf(), randf_range(-1.5, 1.5))
		&"kamui":
			var spiral := _spiral_disk(area.ability.hit_radius, Color(0.45, 0.2, 0.7, 0.55))
			spiral.set_meta(&"spin", true)
			area.add_child(spiral)


## Lingering zone look (after detonation): burning ground, crater...
static func zone_visual(area: GroundArea) -> void:
	var r: float = area.ability.hit_radius
	match area.ability.vfx:
		&"fire_zone":
			for i in 9:
				var flame := _mesh_node(area, _sphere_mesh(randf_range(0.25, 0.45)), Color(1.0, randf_range(0.35, 0.6), 0.1, 0.7), true)
				var at := Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU) * randf() * r * 0.85
				flame.position = at + Vector3.UP * 0.2
				flame.set_meta(&"flame", randf() * TAU)
			_mesh_node(area, _disk_mesh(r), Color(1.0, 0.35, 0.05, 0.25), true).position.y = 0.03
		&"black_fire":
			for i in 8:
				var flame := _mesh_node(area, _sphere_mesh(randf_range(0.25, 0.4)), Color(0.05, 0.02, 0.08, 0.9), false)
				flame.position = Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU) * randf() * r * 0.85 + Vector3.UP * 0.2
				flame.set_meta(&"flame", randf() * TAU)
			_mesh_node(area, _disk_mesh(r), Color(0.4, 0.05, 0.4, 0.3), false).position.y = 0.03
		&"kunai_marker":
			var kunai := Node3D.new()
			area.add_child(kunai)
			var blade := CylinderMesh.new()
			blade.top_radius = 0.0
			blade.bottom_radius = 0.07
			blade.height = 0.35
			_mesh_node(kunai, blade, Color(0.8, 0.82, 0.9, 1.0), false).position.y = 0.15
			var grip := CylinderMesh.new()
			grip.top_radius = 0.03
			grip.bottom_radius = 0.03
			grip.height = 0.25
			_mesh_node(kunai, grip, Color(0.2, 0.15, 0.25, 1.0), false).position.y = 0.45
			var glow := _mesh_node(area, _torus_mesh(0.45, 0.55), Color(1.0, 0.85, 0.3, 0.8), true)
			glow.scale = Vector3(1, 0.2, 1)
			glow.set_meta(&"spin", true)
		&"paper_tag":
			var tag := BoxMesh.new()
			tag.size = Vector3(0.35, 0.02, 0.6)
			_mesh_node(area, tag, Color(0.95, 0.9, 0.75, 1.0), false).position.y = 0.03
			var seal := BoxMesh.new()
			seal.size = Vector3(0.12, 0.025, 0.4)
			_mesh_node(area, seal, Color(0.75, 0.1, 0.1, 1.0), false).position.y = 0.04
		&"crater":
			var crater := _mesh_node(area, _disk_mesh(r), Color(0.25, 0.18, 0.15, 0.55), false)
			crater.position.y = 0.025
			var im := ImmediateMesh.new()
			im.surface_begin(Mesh.PRIMITIVE_LINES)
			for i in 10:
				var dir := Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 10.0)
				_jagged(im, Vector3.UP * 0.05, dir * r + Vector3.UP * 0.05, 4, 0.2)
			im.surface_end()
			_mesh_node(area, im, Color(0.15, 0.1, 0.08, 1.0), false)
		_:
			_mesh_node(area, _disk_mesh(r), Color(area.ability.color, 0.3), true).position.y = 0.03


## Sand wall rising out of the ground.
static func sand_wall(area: GroundArea, body: Node3D, length: float) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(length, 2.0, 0.8)
	var wall := MeshInstance3D.new()
	wall.mesh = mesh
	wall.material_override = SSGraphics.prop_material(Color(0.82, 0.68, 0.42), &"sand")
	body.add_child(wall)
	wall.position.y = -1.0
	var tween := wall.create_tween()
	tween.tween_property(wall, "position:y", 1.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	dust_ring(area, area.global_position, length * 0.6)


static func _disk_mesh(radius: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = 0.01
	m.radial_segments = 32
	return m


static func area_tick(area: GroundArea, delta: float) -> void:
	for child: Node in area.get_children():
		if child.has_meta(&"flame"):
			var ph: float = child.get_meta(&"flame")
			(child as Node3D).scale = Vector3(1.0, 1.0 + 0.5 * absf(sin(area.elapsed * 9.0 + ph)), 1.0)
			if randf() < 0.04:
				_ember(area, (child as Node3D).global_position, Color(1.0, 0.5, 0.1))
		if child.has_meta(&"spin"):
			(child as Node3D).rotate_y(delta * (2.0 + 8.0 * area.elapsed / maxf(area.ability.area_delay, 0.01)))


static func area_detonate(anchor: Node, at: Vector3, a: AbilityData) -> void:
	if not CombatFx.is_enabled():
		return
	var r: float = a.hit_radius
	if a.damage >= 15.0 or a.vfx == &"trap":
		Sfx.play(&"boom", at, -1.0 if a.damage >= 25.0 else -4.0)
	elif a.vfx == &"kirin":
		Sfx.play(&"electric", at)
	match a.vfx:
		&"kirin":
			_sky_bolt(anchor, at, Color(0.75, 0.9, 1.0))
			_explosion(anchor, at + Vector3.UP * 0.5, Color(0.6, 0.85, 1.0), r * 1.4)
			_ground_cracks(anchor, at, r, Color(0.6, 0.85, 1.0))
		&"okasho", &"stomp":
			_ground_cracks(anchor, at, r, Color(1.0, 0.45, 0.6))
			dust_ring(anchor, at, r * 1.2)
			_rocks(anchor, at, r)
		&"ninken":
			dust_ring(anchor, at, r)
			_dogs(anchor, at, r)
		&"kamui":
			_implosion(anchor, at, r, Color(0.45, 0.2, 0.75))
		&"sand_coffin":
			_closing_spheres(anchor, at, r, Color(0.85, 0.72, 0.45))
			dust_ring(anchor, at, r * 1.2)
		&"sand_tsunami":
			_wave(anchor, at, r, Color(0.85, 0.72, 0.45))
		&"shadow_gather", &"shadow_strangle":
			_spikes(anchor, at, r, Color(0.03, 0.03, 0.06))
		&"trap":
			_explosion(anchor, at + Vector3.UP * 0.5, Color(1.0, 0.55, 0.15), r * 1.3)
			dust_ring(anchor, at, r * 1.4)
		_:
			CombatFx.ring(anchor, at, r, a.color, 0.3)


# --- Reusable effects -------------------------------------------------------

## "Poof": expanding white smoke balls.
static func smoke(anchor: Node, at: Vector3, size: float) -> void:
	if not CombatFx.is_enabled():
		return
	for i in 7:
		var puff := _world_node(anchor, _sphere_mesh(size * randf_range(0.3, 0.5)), SMOKE, false)
		var dir := Vector3(randf_range(-1, 1), randf_range(0.2, 1.0), randf_range(-1, 1)).normalized()
		var start: Vector3 = HitQuery.flat(at) + Vector3.UP * (0.6 + randf() * 0.6)
		puff.global_position = start
		_animate(puff, 0.45 + randf() * 0.15, func(n: Node3D, t: float) -> void:
			n.global_position = start + dir * size * 0.9 * t
			n.scale = Vector3.ONE * (0.6 + 0.9 * t)
			(n as MeshInstance3D).transparency = t * t)


static func dust_ring(anchor: Node, at: Vector3, radius: float) -> void:
	if not CombatFx.is_enabled():
		return
	var ring := _world_node(anchor, _torus_mesh(0.5, 0.62), Color(0.85, 0.78, 0.65, 0.7), false)
	ring.global_position = HitQuery.flat(at) + Vector3.UP * 0.1
	_animate(ring, 0.35, func(n: Node3D, t: float) -> void:
		n.scale = Vector3(radius * (0.6 + 1.6 * t), 0.3, radius * (0.6 + 1.6 * t))
		(n as MeshInstance3D).transparency = t)


## Animated crescent swing (melee): reveals progressively, then fades.
static func swipe(anchor: Node, origin: Vector3, direction: Vector3, radius: float, degrees: float, color: Color, heavy: bool) -> void:
	if not CombatFx.is_enabled():
		return
	var im := ImmediateMesh.new()
	var node := _world_node(anchor, im, Color(color.lightened(0.3), 0.85), true)
	node.global_position = HitQuery.flat(origin) + Vector3.UP * 0.95
	var half: float = deg_to_rad(degrees) * 0.5
	var inner: float = radius * 0.45
	var width: float = 0.35 if heavy else 0.22
	_animate(node, 0.2 if heavy else 0.14, func(_n: Node3D, t: float) -> void:
		im.clear_surfaces()
		var reveal: float = clampf(t * 2.2, 0.0, 1.0)
		var fade: float = clampf((t - 0.45) / 0.55, 0.0, 1.0)
		var steps: int = 16
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for i in steps + 1:
			var f: float = float(i) / steps
			if f > reveal:
				break
			var ang: float = lerpf(half, -half, f)
			var d: Vector3 = direction.rotated(Vector3.UP, ang)
			var thick: float = width * sin(f * PI) * (1.0 - fade)
			im.surface_add_vertex(d * maxf(inner, radius - thick * 3.0) + Vector3.UP * thick * 0.3)
			im.surface_add_vertex(d * radius)
		im.surface_end())
	if heavy:
		CombatFx.burst(anchor, HitQuery.flat(origin) + direction * radius * 0.8 + Vector3.UP * 0.9, Color.WHITE, 0.8)


# --- Building blocks ------------------------------------------------------

## Glowing orb held in a hand, grows during startup.
static func _orb(hand: Node3D, color: Color, radius: float, grow_time: float) -> Node3D:
	var root := Node3D.new()
	hand.add_child(root)
	root.position = Vector3(0, -0.1, 0)
	var core := _mesh_node(root, _sphere_mesh(radius * 0.6), Color(1, 1, 1, 0.95), true)
	var shell := _mesh_node(root, _sphere_mesh(radius), Color(color, 0.55), true)
	var ring := _mesh_node(root, _torus_mesh(radius * 0.9, radius * 1.15), Color(color.lightened(0.3), 0.7), true)
	_animate(root, 30.0, func(n: Node3D, t: float) -> void:
		var age: float = t * 30.0
		var g: float = clampf(age / maxf(grow_time, 0.05), 0.15, 1.0)
		n.scale = Vector3.ONE * g * (1.0 + 0.06 * sin(age * 30.0))
		ring.rotation = Vector3(age * 9.0, age * 13.0, 0)
		shell.rotation.y = age * 20.0
		core.scale = Vector3.ONE * (0.9 + 0.2 * sin(age * 45.0)))
	return root


## Crackling lightning around the hand (rebuilt every frame).
static func _lightning_hand(hand: Node3D, color: Color) -> Node3D:
	var root := Node3D.new()
	hand.add_child(root)
	_mesh_node(root, _sphere_mesh(0.16), Color(1, 1, 1, 0.9), true)
	var im := ImmediateMesh.new()
	_mesh_node(root, im, Color(color, 1.0), true)
	_animate(root, 30.0, func(_n: Node3D, _t: float) -> void:
		im.clear_surfaces()
		im.surface_begin(Mesh.PRIMITIVE_LINES)
		for b in 9:
			var dir := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
			_jagged(im, Vector3.ZERO, dir * randf_range(0.35, 0.8), 4, 0.12)
		im.surface_end())
	return root


static func _shuriken_held(hand: Node3D, grow_time: float) -> Node3D:
	var root := _shuriken(0.9)
	hand.add_child(root)
	root.position = Vector3(0, -0.2, 0)
	_animate(root, 30.0, func(n: Node3D, t: float) -> void:
		var age: float = t * 30.0
		n.scale = Vector3.ONE * clampf(age / maxf(grow_time, 0.05), 0.1, 1.0)
		n.rotate_object_local(Vector3.UP, 0.6))
	return root


## Rasenshuriken: white core + 4 spinning blades + ring.
static func _shuriken(radius: float) -> Node3D:
	var root := Node3D.new()
	root.set_meta(&"spin", true)
	_mesh_node(root, _sphere_mesh(radius * 0.35), Color(1, 1, 1, 0.95), true)
	_mesh_node(root, _sphere_mesh(radius * 0.5), Color(0.5, 0.8, 1.0, 0.5), true)
	for i in 4:
		var blade_mesh := PrismMesh.new()
		blade_mesh.size = Vector3(radius * 0.55, radius * 1.4, 0.04)
		var blade := _mesh_node(root, blade_mesh, Color(0.85, 0.95, 1.0, 0.75), true)
		blade.rotation = Vector3(PI / 2.0, i * PI / 2.0, 0)
		blade.position = Vector3(cos(i * PI / 2.0), 0, -sin(i * PI / 2.0)) * radius * 0.75
		blade.rotate_object_local(Vector3.FORWARD, 0.0)
	var ring := _mesh_node(root, _torus_mesh(radius * 0.95, radius * 1.05), Color(0.8, 0.95, 1.0, 0.6), true)
	ring.scale = Vector3(1, 0.3, 1)
	return root


static func _heal_aura(c: CombatCharacter, color: Color, life: float) -> Node3D:
	var root := Node3D.new()
	c.add_child(root)
	var ring := _mesh_node(root, _torus_mesh(0.7, 0.82), Color(color, 0.7), true)
	ring.scale = Vector3(1, 0.25, 1)
	_animate(root, life, func(n: Node3D, t: float) -> void:
		ring.rotation.y = t * 8.0
		ring.position.y = 0.1 + t * 1.6
		if randf() < 0.6:
			var p := _mesh_node(n, _sphere_mesh(0.06), Color(color, 0.9), true)
			var x: Vector3 = Vector3(randf_range(-0.6, 0.6), 0.2, randf_range(-0.6, 0.6))
			p.position = x
			_animate(p, 0.6, func(m: Node3D, u: float) -> void:
				m.position = x + Vector3.UP * u * 1.8
				(m as MeshInstance3D).transparency = u))
	return root


static func _tomoe_ring(c: CombatCharacter) -> Node3D:
	var root := Node3D.new()
	c.add_child(root)
	root.position = Vector3.UP * 0.08
	var ring := _mesh_node(root, _torus_mesh(0.95, 1.08), Color(0.9, 0.1, 0.1, 0.8), true)
	ring.scale = Vector3(1, 0.15, 1)
	for i in 3:
		var tomoe := _mesh_node(root, _sphere_mesh(0.12), Color(0.08, 0.02, 0.02, 0.95), false)
		tomoe.position = Vector3(cos(i * TAU / 3.0), 0, sin(i * TAU / 3.0)) * 1.0
	_animate(root, 30.0, func(n: Node3D, t: float) -> void:
		n.rotation.y = t * 30.0 * 6.0)
	return root


## Translucent spinning dome (Kaiten, Susanoo, crow clone) held on the fighter.
static func _dome(c: CombatCharacter, color: Color, radius: float) -> Node3D:
	var root := Node3D.new()
	c.add_child(root)
	root.position = Vector3.UP * 0.9
	var shell := _mesh_node(root, _sphere_mesh(radius), Color(color, 0.3), true)
	var ring := _mesh_node(root, _torus_mesh(radius * 0.95, radius * 1.05), Color(color.lightened(0.3), 0.6), true)
	_animate(root, 30.0, func(_n: Node3D, t: float) -> void:
		var age: float = t * 30.0
		shell.rotation.y = age * 12.0
		ring.rotation = Vector3(age * 6.0, age * 11.0, 0)
		root.scale = Vector3.ONE * minf(1.0, age * 8.0))
	return root


static func _closing_spheres(anchor: Node, at: Vector3, radius: float, color: Color) -> void:
	for i in 10:
		var dir := Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 10.0)
		var ball := _world_node(anchor, _sphere_mesh(0.45), Color(color, 1.0), false)
		var start: Vector3 = HitQuery.flat(at) + dir * radius + Vector3.UP * 0.4
		_animate(ball, 0.5, func(n: Node3D, t: float) -> void:
			n.global_position = start.lerp(HitQuery.flat(at) + Vector3.UP * (0.4 + t * 0.8), minf(1.0, t * 2.0))
			n.scale = Vector3.ONE * (1.0 - maxf(0.0, t - 0.6) * 2.0))


static func _wave(anchor: Node, at: Vector3, radius: float, color: Color) -> void:
	var ring := _world_node(anchor, _torus_mesh(0.7, 1.0), Color(color, 0.9), false)
	ring.global_position = HitQuery.flat(at)
	_animate(ring, 0.6, func(n: Node3D, t: float) -> void:
		n.scale = Vector3(radius * (0.3 + t), 1.5 * sin(t * PI) + 0.1, radius * (0.3 + t))
		(n as MeshInstance3D).transparency = t * t)
	dust_ring(anchor, at, radius)


static func _spikes(anchor: Node, at: Vector3, radius: float, color: Color) -> void:
	for i in 12:
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.0
		mesh.bottom_radius = 0.12
		mesh.height = 1.4
		var spike := _world_node(anchor, mesh, Color(color, 0.95), false)
		var base: Vector3 = HitQuery.flat(at) + Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU) * randf() * radius
		spike.global_position = base
		spike.rotation = Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))
		_animate(spike, 0.7, func(n: Node3D, t: float) -> void:
			n.global_position = base + Vector3.UP * (0.7 * sin(minf(1.0, t * 1.5) * PI)))


## Crows bursting out (Itachi's crow clone).
static func crows(anchor: Node, at: Vector3) -> void:
	if not CombatFx.is_enabled():
		return
	for i in 10:
		var mesh := PrismMesh.new()
		mesh.size = Vector3(0.35, 0.12, 0.2)
		var crow := _world_node(anchor, mesh, Color(0.05, 0.04, 0.08, 1.0), false)
		var start: Vector3 = HitQuery.flat(at) + Vector3.UP * 1.0
		var dir := Vector3(randf_range(-1, 1), randf_range(0.2, 1.0), randf_range(-1, 1)).normalized()
		_animate(crow, 0.8, func(n: Node3D, t: float) -> void:
			n.global_position = start + dir * t * 4.0
			n.rotation.y = t * 10.0)


static func _column(anchor: Node, at: Vector3, color: Color, radius: float) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 3.0
	var col := _world_node(anchor, mesh, Color(color, 0.45), true)
	col.global_position = HitQuery.flat(at) + Vector3.UP * 1.5
	_animate(col, 0.5, func(n: Node3D, t: float) -> void:
		n.scale = Vector3(1.0 - t * 0.7, 1.0 + t * 0.5, 1.0 - t * 0.7)
		(n as MeshInstance3D).transparency = t)


static func _diamond(anchor: Node, at: Vector3) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.35, 0.35, 0.05)
	var d := _world_node(anchor, mesh, Color(0.75, 0.4, 1.0, 0.95), true)
	d.global_position = at
	d.rotation.z = PI / 4.0
	_animate(d, 0.8, func(n: Node3D, t: float) -> void:
		n.scale = Vector3.ONE * (1.0 + t * 1.5)
		(n as MeshInstance3D).transparency = t)


static func _ember(anchor: Node, at: Vector3, color: Color) -> void:
	var e := _world_node(anchor, _sphere_mesh(0.07), Color(color, 0.9), true)
	var start: Vector3 = at + Vector3(randf_range(-0.3, 0.3), randf_range(-0.2, 0.3), randf_range(-0.3, 0.3))
	e.global_position = start
	_animate(e, 0.35, func(n: Node3D, t: float) -> void:
		n.global_position = start + Vector3.UP * t * 0.8
		(n as MeshInstance3D).transparency = t)


static func _explosion(anchor: Node, at: Vector3, color: Color, size: float) -> void:
	for i in 3:
		var ball := _world_node(anchor, _sphere_mesh(size * 0.5), Color([Color.WHITE, color, color.darkened(0.3)][i], 0.8), true)
		ball.global_position = at
		var delay: float = i * 0.04
		_animate(ball, 0.35 + delay, func(n: Node3D, t: float) -> void:
			n.scale = Vector3.ONE * (0.3 + 1.2 * t)
			(n as MeshInstance3D).transparency = t)
	for i in 8:
		_ember(anchor, at, color)


static func _implosion(anchor: Node, at: Vector3, radius: float, color: Color) -> void:
	var disk := _spiral_disk(radius * 1.3, Color(color, 0.8))
	_world(anchor).add_child(disk)
	disk.global_position = HitQuery.flat(at) + Vector3.UP * 0.6
	_animate(disk, 0.45, func(n: Node3D, t: float) -> void:
		n.rotate_y(0.5)
		n.scale = Vector3.ONE * (1.0 - t)
		n.position.y = 0.6 + t * 0.6)
	CombatFx.burst(anchor, at + Vector3.UP * 0.8, Color(0.6, 0.35, 0.9), 1.2)


static func _sky_bolt(anchor: Node, at: Vector3, color: Color) -> void:
	var im := ImmediateMesh.new()
	var node := _world_node(anchor, im, Color(color, 1.0), true)
	node.global_position = HitQuery.flat(at)
	_animate(node, 0.35, func(n: Node3D, t: float) -> void:
		im.clear_surfaces()
		im.surface_begin(Mesh.PRIMITIVE_LINES)
		for b in 3:
			_jagged(im, Vector3(randf_range(-0.6, 0.6), 14.0, randf_range(-0.6, 0.6)), Vector3.ZERO, 12, 0.7)
		im.surface_end()
		(n as MeshInstance3D).transparency = t * t)
	var flash := _world_node(anchor, _sphere_mesh(2.0), Color(1, 1, 1, 0.6), true)
	flash.global_position = HitQuery.flat(at) + Vector3.UP
	_animate(flash, 0.15, func(n: Node3D, t: float) -> void:
		(n as MeshInstance3D).transparency = t)


static func _ground_cracks(anchor: Node, at: Vector3, radius: float, color: Color) -> void:
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in 9:
		var dir := Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 9.0 + randf() * 0.3)
		_jagged(im, Vector3.UP * 0.04, dir * radius * randf_range(0.8, 1.2) + Vector3.UP * 0.04, 4, 0.25)
	im.surface_end()
	var node := _world_node(anchor, im, Color(color.darkened(0.2), 1.0), false)
	node.global_position = HitQuery.flat(at)
	_animate(node, 1.2, func(n: Node3D, t: float) -> void:
		(n as MeshInstance3D).transparency = clampf((t - 0.5) * 2.0, 0.0, 1.0))


static func _rocks(anchor: Node, at: Vector3, radius: float) -> void:
	for i in 8:
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE * randf_range(0.15, 0.35)
		var rock := _world_node(anchor, mesh, Color(0.5, 0.45, 0.38, 1.0), false)
		var dir := Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU)
		var start: Vector3 = HitQuery.flat(at) + dir * randf() * radius * 0.6
		var vel: Vector3 = dir * randf_range(1.5, 3.5) + Vector3.UP * randf_range(4.0, 7.0)
		_animate(rock, 0.7, func(n: Node3D, t: float) -> void:
			var time: float = t * 0.7
			n.global_position = start + vel * time + Vector3.DOWN * 9.8 * time * time * 0.5
			n.rotation = Vector3(time * 9.0, time * 7.0, 0))


static func _dogs(anchor: Node, at: Vector3, radius: float) -> void:
	for i in 3:
		var dog := Node3D.new()
		_world(anchor).add_child(dog)
		var dir := Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 3.0)
		dog.global_position = HitQuery.flat(at) + dir * radius * 0.6
		dog.basis = Basis.looking_at(-dir, Vector3.UP)
		var body := BoxMesh.new()
		body.size = Vector3(0.3, 0.3, 0.6)
		_mesh_node(dog, body, Color(0.45, 0.35, 0.25, 1.0), false).position = Vector3(0, 0.3, 0)
		var head := BoxMesh.new()
		head.size = Vector3(0.25, 0.25, 0.3)
		_mesh_node(dog, head, Color(0.4, 0.3, 0.22, 1.0), false).position = Vector3(0, 0.5, -0.35)
		_animate(dog, 0.9, func(n: Node3D, t: float) -> void:
			n.position.y = -0.6 + 0.6 * sin(clampf(t * 1.3, 0.0, 1.0) * PI))
		dog.add_to_group(&"round_entities")


static func _spiral_disk(radius: float, color: Color) -> MeshInstance3D:
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var steps: int = 90
	for i in steps:
		var t: float = float(i) / steps
		var a: float = t * TAU * 2.5
		var r: float = radius * t
		var d := Vector3(cos(a), 0, sin(a))
		im.surface_add_vertex(d * r + Vector3.UP * 0.04)
		im.surface_add_vertex(d * (r + radius * 0.12) + Vector3.UP * 0.04)
	im.surface_end()
	var node := MeshInstance3D.new()
	node.mesh = im
	node.material_override = _material(color, true)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_to_group(&"round_entities")
	return node


## Zig-zag segment from `a` to `b` (adds LINE vertex pairs).
static func _jagged(im: ImmediateMesh, a: Vector3, b: Vector3, segments: int, jitter: float) -> void:
	var prev: Vector3 = a
	for i in range(1, segments + 1):
		var p: Vector3 = a.lerp(b, float(i) / segments)
		if i < segments:
			p += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * jitter
		im.surface_add_vertex(prev)
		im.surface_add_vertex(p)
		prev = p


static func _material(color: Color, additive: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return m


## Effect attached to `parent` (moves with it).
static func _mesh_node(parent: Node, mesh: Mesh, color: Color, additive: bool) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _material(color, additive)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node


## Effect placed in the world next to `anchor` (survives the anchor).
static func _world_node(anchor: Node, mesh: Mesh, color: Color, additive: bool) -> MeshInstance3D:
	var node := _mesh_node(_world(anchor), mesh, color, additive)
	node.add_to_group(&"round_entities")
	return node


static func _world(anchor: Node) -> Node:
	if anchor is CombatCharacter or anchor is Projectile or anchor is GroundArea or anchor is CombatFx:
		return anchor.get_parent()
	return anchor


static func _sphere_mesh(radius: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = 16
	m.rings = 8
	return m


static func _torus_mesh(inner: float, outer: float) -> TorusMesh:
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = 24
	m.ring_segments = 6
	return m


## Runs `updater(node, t)` every frame for `life` seconds (t in 0..1), then frees it.
static func _animate(node: Node3D, life: float, updater: Callable) -> void:
	var driver := SpellFxDriver.new()
	driver.life = life
	driver.updater = updater
	node.add_child(driver)
