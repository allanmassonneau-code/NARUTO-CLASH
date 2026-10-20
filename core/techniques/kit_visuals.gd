class_name KitVisuals
## Presentation of the technique runtime (objects, projectiles, one-shot
## effects). Never called on headless servers (callers check
## CombatFx.is_enabled()).

## One-shot effects available to techniques (Tk.fx).
const EFFECTS: Array[String] = ["burst", "explosion", "wave", "spikes", "column", "implosion", "bolt", "cracks",
	"rocks", "smoke", "dust", "crows", "ember", "spheres", "ring", "sparks"]


static func _mat(color: Color, emission: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if color.a < 1.0 else BaseMaterial3D.TRANSPARENCY_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = Color(color, 1.0)
		m.emission_energy_multiplier = emission
	return m


static func _mesh(mesh: Mesh, mat: Material, at: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = at
	return mi


static func object_visual(o: KitObject) -> Node3D:
	var root := Node3D.new()
	var c: Color = o.color
	match o.look:
		KitObject.Look.DISC, KitObject.Look.GLYPH, KitObject.Look.RING:
			if o.look != KitObject.Look.RING:
				var disc := CylinderMesh.new()
				disc.top_radius = o.radius
				disc.bottom_radius = o.radius
				disc.height = 0.02
				disc.radial_segments = 40
				root.add_child(_mesh(disc, _mat(Color(c, 0.16)), Vector3.UP * 0.03))
			var edge := TorusMesh.new()
			edge.inner_radius = maxf(0.05, o.radius - 0.1)
			edge.outer_radius = o.radius
			edge.rings = 40
			root.add_child(_mesh(edge, _mat(Color(c, 0.8), 1.0), Vector3.UP * 0.05))
			if o.look == KitObject.Look.GLYPH:
				var inner := TorusMesh.new()
				inner.inner_radius = o.radius * 0.45
				inner.outer_radius = o.radius * 0.5
				root.add_child(_mesh(inner, _mat(Color(c, 0.7), 1.0), Vector3.UP * 0.05))
		KitObject.Look.WALL:
			var box := BoxMesh.new()
			box.size = Vector3(o.half_extents.x * 2.0, 1.8, o.half_extents.y * 2.0)
			var wall := _mesh(box, _mat(Color(c, 0.85)), Vector3.UP * 0.9)
			root.add_child(wall)
			root.basis = Basis.looking_at(o.facing, Vector3.UP)
		KitObject.Look.PILLAR:
			var cyl := CylinderMesh.new()
			cyl.top_radius = minf(o.radius, 0.6)
			cyl.bottom_radius = minf(o.radius, 0.6) * 1.2
			cyl.height = 2.2
			root.add_child(_mesh(cyl, _mat(Color(c, 0.9), 0.4), Vector3.UP * 1.1))
		KitObject.Look.ORB:
			var sphere := SphereMesh.new()
			sphere.radius = 0.35
			sphere.height = 0.7
			root.add_child(_mesh(sphere, _mat(Color(c, 0.9), 2.0), Vector3.UP * 1.0))
		KitObject.Look.DECOY:
			var cap := CapsuleMesh.new()
			cap.radius = 0.35
			cap.height = 1.7
			var body := _mesh(cap, _mat(Color(c, 0.55)), Vector3.UP * 0.85)
			root.add_child(body)
	return root


static func object_tick(o: KitObject, visual: Node3D, _delta: float) -> void:
	# Fade out over the last half second; pulse glyph edges.
	var fade: float = 1.0 if o.lifetime <= 0.0 else clampf((o.lifetime - o.age) / 0.5, 0.0, 1.0)
	visual.scale = Vector3.ONE * (0.6 + 0.4 * minf(o.age / 0.15, 1.0))
	if o.look == KitObject.Look.GLYPH or o.look == KitObject.Look.ORB:
		visual.rotation.y += _delta * 0.8
	visual.visible = fade > 0.02


static func projectile_visual(p: TkProjectile) -> Node3D:
	var root := Node3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = p.size
	sphere.height = p.size * 2.0
	root.add_child(_mesh(sphere, _mat(Color(p.color, 1.0), 2.5)))
	var halo := SphereMesh.new()
	halo.radius = p.size * 1.8
	halo.height = p.size * 3.6
	root.add_child(_mesh(halo, _mat(Color(p.color, 0.25), 1.0)))
	var light := OmniLight3D.new()
	light.light_color = p.color
	light.light_energy = 0.8
	light.omni_range = 3.0
	root.add_child(light)
	return root


## Line between two fighters / points (tether, chain). Returns the node; the
## caller updates it with update_line.
static func line_visual(anchor: Node, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = ImmediateMesh.new()
	mi.material_override = _mat(Color(color, 0.9), 1.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.add_to_group(&"round_entities")
	anchor.add_child(mi)
	mi.global_transform = Transform3D.IDENTITY
	return mi


static func update_line(mi: MeshInstance3D, from: Vector3, to: Vector3) -> void:
	var im := mi.mesh as ImmediateMesh
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for h: float in [0.8, 1.0, 1.2]:
		im.surface_add_vertex(Vector3(from.x, h, from.z))
		im.surface_add_vertex(Vector3(to.x, h, to.z))
	im.surface_end()


## One-shot effect by name (see EFFECTS).
static func fx(anchor: Node, effect: String, at: Vector3, radius: float, color: Color) -> void:
	if not CombatFx.is_enabled() or anchor == null or not anchor.is_inside_tree():
		return
	var ground := Vector3(at.x, 0.0, at.z)
	match effect:
		"explosion":
			SpellVfx._explosion(anchor, ground, color, radius)
		"wave":
			SpellVfx._wave(anchor, ground, radius, color)
		"spikes":
			SpellVfx._spikes(anchor, ground, radius, color)
		"column":
			SpellVfx._column(anchor, ground, color, radius)
		"implosion":
			SpellVfx._implosion(anchor, ground, radius, color)
		"bolt":
			SpellVfx._sky_bolt(anchor, ground, color)
		"cracks":
			SpellVfx._ground_cracks(anchor, ground, radius, color)
		"rocks":
			SpellVfx._rocks(anchor, ground, radius)
		"smoke":
			SpellVfx.smoke(anchor, ground, radius)
		"dust":
			SpellVfx.dust_ring(anchor, ground, radius)
		"crows":
			SpellVfx.crows(anchor, ground)
		"ember":
			SpellVfx._ember(anchor, ground, color)
		"spheres":
			SpellVfx._closing_spheres(anchor, ground, radius, color)
		"sparks":
			CombatFx.sparks(anchor, ground + Vector3.UP, color, 10)
		"ring":
			CombatFx.ring(anchor, ground, radius, color, 0.35)
		_:
			CombatFx.burst(anchor, ground + Vector3.UP * 0.8, color, radius)
