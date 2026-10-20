extends RefCounted
## Technique kit: Fûton (design bible §4). Signature: Courants — several
## techniques briefly create an oriented Courant (a strip of wind, "courant"
## objects). Every fighter crossing it drifts along it; moving with it is
## faster, against it slower (the Fûton's team masters it: never slowed);
## every projectile crossing it (any team) bends toward its direction.

const KIT_ID := &"futon"
const SIGNATURE = null
const TECHNIQUES := {
	&"futon_d_lame_de_sillage": LameDeSillage,
	&"futon_d_paume_de_pression": PaumeDePression,
	&"futon_c_fil_du_vide": FilDuVide,
	&"futon_c_ascendance": Ascendance,
	&"futon_b_orbite_tranchante": OrbiteTranchante,
	&"futon_b_tornade_de_prise": TornadeDePrise,
	&"futon_a_pas_du_faucon": PasDuFaucon,
	&"futon_a_chambre_a_vide": ChambreAVide,
	&"futon_s_typhon_des_huit_directions": TyphonDesHuitDirections,
	&"futon_s_lame_atmospherique": LameAtmospherique,
}

const WIND := Color(0.7, 0.95, 0.85)


## Shared Fûton rules: Courants and projectile manipulation.
class K:
	## Oriented Courant: a strip `length` x `width` centred on `center`,
	## flowing along `direction` for `life` seconds.
	static func current(t: Tk, center: Vector3, direction: Vector3, length: float, width: float, life: float,
			strength: float = 1.0) -> KitObject:
		var d: Vector3 = HitQuery.flat(direction).normalized()
		if d.length() < 0.5:
			d = t.dir
		var line_node: MeshInstance3D = null
		if CombatFx.is_enabled():
			line_node = KitVisuals.line_visual(t.caster.get_parent(), WIND)
			KitVisuals.update_line(line_node, center - d * length * 0.5, center + d * length * 0.5)
		return t.object(center, {"kind": "courant", "radius": length * 0.5, "lifetime": life, "look": KitObject.Look.NONE,
			"targetable": false, "color": WIND,
			"data": {"dir": d, "len": length, "width": width, "strength": strength, "fx_at": -1.0},
			"on_tick": func(o: KitObject) -> void:
				_flow(t, o),
			"on_destroy": func(_o: KitObject, _reason: String) -> void:
				if line_node != null and is_instance_valid(line_node):
					line_node.queue_free()})

	static func in_strip(o: KitObject, point: Vector3) -> bool:
		var d: Vector3 = o.data.dir
		var to: Vector3 = HitQuery.flat(point - o.global_position)
		return absf(to.dot(d)) <= float(o.data.len) * 0.5 \
			and absf(to.dot(d.cross(Vector3.UP))) <= float(o.data.width) * 0.5 + HitQuery.HURTBOX_RADIUS

	static func _flow(t: Tk, o: KitObject) -> void:
		if not t.alive():
			o.destroy("caster")
			return
		var dt: float = o.get_physics_process_delta_time()
		var d: Vector3 = o.data.dir
		var s: float = float(o.data.strength)
		if o.age - float(o.data.fx_at) >= 0.4:
			o.data["fx_at"] = o.age
			t.fx("dust", o.global_position, 0.6)
		for f: CombatCharacter in t.fighters():
			if not in_strip(o, f.global_position):
				continue
			var v: Vector3 = HitQuery.flat(f.velocity)
			if v.length() > 0.5:
				var along: float = v.normalized().dot(d)
				if along > 0.5:
					f.kit.add_modifier("courant", 0.15, {"speed": 1.0 + 0.3 * s, "label": "Courant", "color": WIND})
				elif along < -0.5 and f.team != t.caster.team:
					f.kit.add_modifier("courant", 0.15, {"speed": maxf(0.4, 1.0 - 0.3 * s), "label": "Contre-courant", "color": WIND})
			drift(f, d * 1.2 * s * dt)
		for n: Node3D in projectiles(t, o.global_position, float(o.data.len) * 0.5 + float(o.data.width)):
			if in_strip(o, n.global_position):
				bend(n, d, 2.5 * s * dt)

	## Moves a fighter a little (collides with walls).
	static func drift(f: CombatCharacter, motion: Vector3) -> void:
		if f == null or not is_instance_valid(f) or f.is_dead() or motion.length() < 0.0001:
			return
		f.move_and_collide(HitQuery.flat(motion))
		f.global_position.y = 0.0

	## Live projectiles (both kinds, lobs excluded) within `radius` of `center`.
	static func projectiles(t: Tk, center: Vector3, radius: float) -> Array[Node3D]:
		var out: Array[Node3D] = []
		for node: Node in t.tree().get_nodes_in_group(&"tk_projectiles"):
			var p := node as TkProjectile
			if p != null and p.is_alive() and not p.lob and p.process_mode != Node.PROCESS_MODE_DISABLED \
					and HitQuery.flat(p.global_position - center).length() <= radius:
				out.append(p)
		for node: Node in t.tree().get_nodes_in_group(&"projectiles"):
			var q := node as Projectile
			if q != null and not q.visual_only and q.is_inside_tree() and not q.is_queued_for_deletion() \
					and q.process_mode != Node.PROCESS_MODE_DISABLED and HitQuery.flat(q.global_position - center).length() <= radius:
				out.append(q)
		return out

	## Small projectiles only (big ones are not caught / cut / deflected).
	static func small_projectiles(t: Tk, center: Vector3, radius: float) -> Array[Node3D]:
		var out: Array[Node3D] = []
		for n: Node3D in projectiles(t, center, radius):
			if is_small(n):
				out.append(n)
		return out

	static func is_small(n: Node3D) -> bool:
		if n is TkProjectile:
			var p := n as TkProjectile
			return p.size <= 0.35 and p.hit_radius <= 0.8
		var q := n as Projectile
		return q != null and q.ability != null and q.ability.hit_radius <= 0.8

	static func team_of(n: Node3D) -> int:
		if n is TkProjectile:
			return (n as TkProjectile).team
		return (n as Projectile).team

	static func dir_of(n: Node3D) -> Vector3:
		if n is TkProjectile:
			return (n as TkProjectile).direction
		return (n as Projectile).direction

	static func speed_of(n: Node3D) -> float:
		if n is TkProjectile:
			return (n as TkProjectile).speed
		var q := n as Projectile
		return q.ability.projectile_speed if q.ability != null else 0.0

	static func set_dir(n: Node3D, d: Vector3) -> void:
		var nd: Vector3 = HitQuery.flat(d).normalized()
		if nd.length() < 0.5:
			return
		var tp := n as TkProjectile
		if tp != null:
			tp.direction = nd
			return
		var q := n as Projectile
		if q != null:
			q.direction = nd

	static func bend(n: Node3D, toward: Vector3, max_angle: float) -> void:
		var d: Vector3 = dir_of(n)
		var angle: float = d.signed_angle_to(toward, Vector3.UP)
		set_dir(n, d.rotated(Vector3.UP, clampf(angle, -max_angle, max_angle)))

	static func kill(n: Node3D) -> void:
		if n is TkProjectile:
			(n as TkProjectile).end("blocked")
		elif is_instance_valid(n):
			n.queue_free()

	static func seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
		var ab: Vector3 = HitQuery.flat(b - a)
		var ap: Vector3 = HitQuery.flat(p - a)
		var k: float = clampf(ap.dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		return (ap - ab * k).length()


## D — Boomerang, Skillshot, Double ligne. A thin blade flies 8 m, then
## comes back to the caster wherever they moved (tracks their position);
## out and back hit separately, the return for less.
class LameDeSillage extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.12
		a.recovery_time = 0.2
		a.max_range = 8.0
		a.anim = &"throw"

	func cast(t: Tk) -> void:
		t.projectile({"speed": 22.0, "range": 8.0, "radius": 0.45, "pierce": true, "size": 0.16, "color": WIND,
			"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
				t.hit(e, t.dmg(0.55))
				return true,
			"on_end": func(point: Vector3, _p: TkProjectile, _reason: String) -> void:
				if t.alive():
					_back(t, point)})

	func _back(t: Tk, from: Vector3) -> void:
		var to: Vector3 = HitQuery.flat(t.caster.global_position - from)
		var d: Vector3 = to.normalized() if to.length() > 0.2 else -t.dir
		t.projectile({"from": from - d * 0.5, "dir": d, "speed": 20.0, "range": 40.0, "radius": 0.45, "pierce": true,
			"size": 0.16, "color": WIND,
			"on_tick": func(p: TkProjectile, dt: float) -> void:
				if not t.alive() or p.age > 2.5:
					p.end("range")
					return
				var back: Vector3 = HitQuery.flat(t.caster.global_position - p.global_position)
				if back.length() < 0.8:
					p.end("caught")
					return
				var angle: float = p.direction.signed_angle_to(back.normalized(), Vector3.UP)
				p.direction = p.direction.rotated(Vector3.UP, clampf(angle, -7.0 * dt, 7.0 * dt)).normalized(),
			"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
				t.hit(e, t.dmg(0.35))
				return true})


## D — Cône, Push/Pull, Contrôle directionnel. Pressure cone; the choice
## resolves 0.2 s after release: single tap = push (3.5 m, slow enough not to
## wall-slam), tap again within 0.2 s (stands in for "hold") = light pull.
## Minimal damage; a pushed target against an obstacle loses balance
## (0.25 s stun). Each palm leaves a brief Courant.
class PaumeDePression extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.1
		a.recovery_time = 0.2
		a.max_range = 4.0
		a.anim = &"palm"

	func cast(t: Tk) -> void:
		var d: Vector3 = t.dir
		t.fx("wave", t.origin + d * 1.2, 1.2, WIND)
		t.recast(0.2, func(rt: Tk) -> void:
			_pull(rt, d),
			func() -> void:
				if t.alive():
					_push(t.refreshed(), d))

	func _push(t: Tk, d: Vector3) -> void:
		t.fx("wave", t.origin + d * 2.0, 2.0, WIND)
		var up: Vector3 = Vector3.UP * HitQuery.BODY_HEIGHT
		for e: CombatCharacter in t.enemies_in_cone(t.origin, d, 4.0, 70.0):
			var pd: Vector3 = HitQuery.flat(e.global_position - t.origin)
			pd = pd.normalized() if pd.length() > 0.1 else d
			if t.hit(e, t.dmg(0.15)) != HitData.Result.HIT:
				continue
			t.push(e, pd, 3.5, 0.6)
			var from: Vector3 = HitQuery.flat(e.global_position)
			var blocked: bool = not HitQuery.raycast_world(t.caster.get_world_3d(), from + up, from + up + pd * 3.5).is_empty()
			if not blocked:
				for node: Node in t.tree().get_nodes_in_group(&"kit_objects"):
					var o := node as KitObject
					if o != null and o.is_alive() and o.blocks_movement and o.contains(from + pd * 1.5):
						blocked = true
						break
			if blocked:
				t.status(e, StatusController.Type.STUN, 0.25)
				t.text(e, "DÉSÉQUILIBRE")
		K.current(t, t.origin + d * 2.5, d, 4.0, 2.5, 1.0)

	func _pull(t: Tk, d: Vector3) -> void:
		t.fx("implosion", t.origin + d * 2.0, 2.0, WIND)
		for e: CombatCharacter in t.enemies_in_cone(t.origin, d, 4.5, 70.0):
			if t.hit(e, t.dmg(0.1)) == HitData.Result.HIT:
				t.pull(e, t.origin, 2.0, 0.35)
		K.current(t, t.origin + d * 2.5, -d, 4.0, 2.5, 1.0)


## C — Skillshot retardé, Coupe, Anti-projectile. A thin 6 m line across the
## aim (perpendicular to the cast) is drawn, then contracts after 0.7 s: cuts
## every enemy on it (centre 1.8 m = precision zone, more damage) and
## destroys small enemy projectiles crossing it at that instant.
class FilDuVide extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.2
		a.max_range = 11.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var side: Vector3 = t.dir.cross(Vector3.UP).normalized()
		var mid: Vector3 = t.aim
		var a: Vector3 = mid - side * 3.0
		var b: Vector3 = mid + side * 3.0
		var line_node: MeshInstance3D = null
		if CombatFx.is_enabled():
			line_node = KitVisuals.line_visual(t.caster.get_parent(), Color(WIND, 0.5))
			KitVisuals.update_line(line_node, a, b)
		t.object(mid, {"kind": "fil", "radius": 3.0, "lifetime": 0.7, "look": KitObject.Look.NONE, "targetable": false,
			"on_expire": func(_o: KitObject) -> void:
				if t.alive():
					_contract(t, a, b, side),
			"on_destroy": func(_o: KitObject, _reason: String) -> void:
				if line_node != null and is_instance_valid(line_node):
					line_node.queue_free()})

	func _contract(t: Tk, a: Vector3, b: Vector3, side: Vector3) -> void:
		var mid: Vector3 = (a + b) * 0.5
		t.fx("sparks", mid, 1.0, WIND)
		if CombatFx.is_enabled():
			var flash: MeshInstance3D = KitVisuals.line_visual(t.caster.get_parent(), WIND)
			KitVisuals.update_line(flash, a, b)
			t.tree().create_timer(0.2).timeout.connect(flash.queue_free)
		for e: CombatCharacter in t.enemies_in_line(a, side, 6.0, 0.6):
			var along: float = absf(HitQuery.flat(e.global_position - mid).dot(side))
			var precise: bool = along <= 0.9
			t.hit(e, t.dmg(1.1 if precise else 0.6))
			if precise:
				t.text(e, "PRÉCISION")
		for n: Node3D in K.small_projectiles(t, mid, 3.8):
			if K.team_of(n) != t.caster.team and K.seg_dist(n.global_position, a, b) <= 0.8:
				t.fx("sparks", HitQuery.flat(n.global_position), 0.5, WIND)
				K.kill(n)


## C — Colonne d'air, Mobilité verticale, Terrain. A 4 s updraft column:
## anyone inside (allies or enemies — neutral tool) is held airborne while
## keeping horizontal control (dodges ground zones) and gets Altitude
## (+15 % damage, plunging shots) for 1.5 s; projectiles crossing it speed up.
class Ascendance extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.2
		a.max_range = 10.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		t.fx("column", t.aim, 1.5, WIND)
		t.zone(t.aim, 1.8, 4.0, {"kind": "colonne", "look": KitObject.Look.RING, "targetable": false, "color": WIND,
			"on_enter": func(f: CombatCharacter, _o: KitObject) -> void:
				t.fx("wave", f.global_position, 0.8, WIND),
			"on_tick": func(o: KitObject) -> void:
				var dt: float = o.get_physics_process_delta_time()
				for f: CombatCharacter in o.inside:
					if not is_instance_valid(f) or f.is_dead():
						continue
					if not f.is_launched():
						f.air_time = maxf(f.air_time, 0.25)
					f.kit.add_modifier("altitude", 1.5, {"damage_dealt": 1.15, "label": "Altitude", "color": WIND})
				for n: Node3D in K.projectiles(t, o.global_position, o.radius):
					if n.has_meta("ascendance"):
						continue
					var tp := n as TkProjectile
					if tp != null:
						tp.set_meta("ascendance", true)
						tp.speed *= 1.3
					else:
						n.global_position += K.dir_of(n) * K.speed_of(n) * dt * 0.3})


## B — Aura directionnelle, Anti-projectile, Mêlée. A 5 s wind ring around
## the caster: small enemy projectiles entering it are deflected
## tangentially (not cancelled) and enemies in melee range take small
## repeated cuts — except through the opening behind the caster (facing).
class OrbiteTranchante extends Technique:
	const RADIUS: float = 2.2

	func configure(a: AbilityData) -> void:
		a.startup_time = 0.15
		a.max_range = 2.5
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		t.buff("orbite", 5.0, {"label": "Orbite", "color": WIND})
		t.object(t.origin, {"kind": "orbite", "radius": RADIUS, "lifetime": 5.0, "look": KitObject.Look.RING,
			"targetable": false, "color": WIND, "data": {"cut_at": -1.0},
			"on_tick": func(o: KitObject) -> void:
				_spin(t, o)})

	func _spin(t: Tk, o: KitObject) -> void:
		if not t.alive():
			o.destroy("caster")
			return
		o.global_position = HitQuery.flat(t.caster.global_position)
		var facing: Vector3 = HitQuery.flat(t.caster.facing.facing_direction).normalized()
		for n: Node3D in K.small_projectiles(t, o.global_position, RADIUS + 0.3):
			if K.team_of(n) == t.caster.team or n.has_meta("orbite"):
				continue
			var to: Vector3 = HitQuery.flat(n.global_position - o.global_position)
			if to.length() < 0.05 or facing.dot(to.normalized()) < -0.55:
				continue  # rear opening
			var radial: Vector3 = to.normalized()
			var tangent: Vector3 = Vector3.UP.cross(radial).normalized()
			if tangent.dot(K.dir_of(n)) < 0.0:
				tangent = -tangent
			n.set_meta("orbite", true)
			K.set_dir(n, tangent)
			n.global_position = o.global_position + radial * (RADIUS + 0.4) + Vector3.UP * HitQuery.BODY_HEIGHT
			t.fx("sparks", HitQuery.flat(n.global_position), 0.5, WIND)
		if o.age - float(o.data.cut_at) >= 0.35:
			o.data["cut_at"] = o.age
			for e: CombatCharacter in t.enemies_in(o.global_position, 2.0):
				var to_e: Vector3 = HitQuery.flat(e.global_position - o.global_position)
				if to_e.length() > 0.05 and facing.dot(to_e.normalized()) < -0.55:
					continue
				t.hit(e, t.dmg(0.15))


## B — Vortex mobile, Pull, Projectile manipulation. A slow tornado (2.6 m/s)
## moves along the aim for 4.5 s: draws nearby enemies in, light ticks, and
## captures up to 6 small projectiles it crosses (any team), orbiting them.
## At its end or on recast it releases them in a spiral around that point,
## owners unchanged (they can hit the caster).
class TornadeDePrise extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.25
		a.max_range = 12.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var d: Vector3 = t.dir
		var tornado: KitObject = t.object(t.origin + d * 1.5, {"kind": "tornade", "radius": 1.4, "lifetime": 4.5,
			"look": KitObject.Look.GLYPH, "targetable": false, "color": WIND,
			"data": {"captured": [], "hit_at": -1.0},
			"on_tick": func(o: KitObject) -> void:
				_move(t, o, d),
			"on_destroy": func(o: KitObject, _reason: String) -> void:
				_release(t, o)})
		t.recast(4.5, func(_rt: Tk) -> void:
			if is_instance_valid(tornado) and tornado.is_alive():
				tornado.destroy("recast"))

	func _move(t: Tk, o: KitObject, d: Vector3) -> void:
		if not t.alive():
			o.destroy("caster")
			return
		var dt: float = o.get_physics_process_delta_time()
		var up: Vector3 = Vector3.UP * HitQuery.BODY_HEIGHT
		var step: Vector3 = d * 2.6 * dt
		if HitQuery.raycast_world(t.caster.get_world_3d(), o.global_position + up, o.global_position + up + d * 0.8).is_empty():
			o.global_position += step
		for e: CombatCharacter in t.enemies_in(o.global_position, 3.5):
			var to: Vector3 = HitQuery.flat(o.global_position - e.global_position)
			if to.length() > 0.6:
				K.drift(e, to.normalized() * 1.6 * dt)
		if o.age - float(o.data.hit_at) >= 0.5:
			o.data["hit_at"] = o.age
			for e: CombatCharacter in t.enemies_in(o.global_position, o.radius):
				t.hit(e, t.dmg(0.12))
		var captured: Array = o.data.captured
		for n: Node3D in K.small_projectiles(t, o.global_position, o.radius + 0.4):
			if captured.size() >= 6:
				break
			if captured.has(n):
				continue
			n.process_mode = Node.PROCESS_MODE_DISABLED
			captured.append(n)
		var alive: Array = captured.filter(func(n: Variant) -> bool: return is_instance_valid(n))
		o.data["captured"] = alive
		for i in alive.size():
			var n: Node3D = alive[i]
			var ang: float = o.age * 5.0 + TAU * i / maxf(1.0, alive.size())
			n.global_position = o.global_position + Vector3(cos(ang), 0.0, sin(ang)) * 0.9 + up

	func _release(t: Tk, o: KitObject) -> void:
		var captured: Array = o.data.get("captured", [])
		var center: Vector3 = HitQuery.flat(o.global_position)
		t.fx("wave", center, 2.0, WIND)
		var i: int = 0
		for v: Variant in captured:
			if not is_instance_valid(v):
				continue
			var n: Node3D = v
			var ang: float = TAU * i / maxf(1.0, captured.size())
			i += 1
			var radial: Vector3 = Vector3(cos(ang), 0.0, sin(ang))
			n.global_position = center + radial * 1.0 + Vector3.UP * HitQuery.BODY_HEIGHT
			K.set_dir(n, radial.rotated(Vector3.UP, 0.6))
			var tp := n as TkProjectile
			if tp != null:
				tp.travelled = 0.0
			elif n is Projectile:
				n.set("_travelled", 0.0)
			n.process_mode = Node.PROCESS_MODE_INHERIT
		o.data["captured"] = []


## A — Mobilité aérienne, Recast, Assaut. Diagonal air impulse (5 m,
## airborne). While still in the air (0.75 s) a recast fires a second
## impulse perpendicular to the first (toward the aim's side). After it, the
## first offensive hit pushes the target along the caster's facing and
## leaves a Courant behind the Fûton. Interrupted in the air: recast lost.
class PasDuFaucon extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.08
		a.recovery_time = 0.1
		a.max_range = 6.0
		a.anim = &"dash"

	func cast(t: Tk) -> void:
		var d: Vector3 = t.dir
		_impulse(t, d, 5.0)
		t.recast(0.75, func(rt: Tk) -> void:
			if not rt.caster.status.can_act() or rt.caster.is_launched():
				return
			var side: Vector3 = d.cross(Vector3.UP).normalized()
			if side.dot(rt.aim - rt.origin) < 0.0:
				side = -side
			_impulse(rt, side, 4.5)
			var caster: CombatCharacter = rt.caster
			rt.buff("faucon_assaut", 4.0, {"uses": 1, "label": "Assaut", "color": WIND,
				"on_deal": func(target: CombatCharacter, _hit: HitData, dmg: float) -> float:
					if is_instance_valid(target) and not target.is_dead() and is_instance_valid(caster):
						var facing: Vector3 = HitQuery.flat(caster.facing.facing_direction).normalized()
						rt.push(target, facing, 2.0, 0.25)
						K.current(rt, HitQuery.flat(caster.global_position) - facing * 2.5, facing, 5.0, 2.0, 3.0)
					return dmg}))
		t.object(t.origin, {"kind": "envol", "radius": 0.3, "lifetime": 0.8, "look": KitObject.Look.NONE, "targetable": false,
			"on_tick": func(o: KitObject) -> void:
				if not t.alive() or not t.caster.status.can_act() or t.caster.is_launched():
					if t.alive():
						t.kit().close_recast(t.id)
					o.destroy("interrupted")})

	func _impulse(t: Tk, d: Vector3, dist: float) -> void:
		t.fx("dust", t.caster.global_position, 1.0)
		t.caster.air_time = maxf(t.caster.air_time, 0.7)
		t.dash(dist, d, 0.25)


## A — Zone, Anti-projectile, Gestion de souffle. A 6 s low-pressure sphere:
## projectiles inside (any team) are strongly slowed (the caster's own less:
## mastery), airborne time drains twice as fast, and breath techniques cast
## inside are cut short (caster tolerates longer). No damage, no hard CC.
class ChambreAVide extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.3
		a.max_range = 11.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		t.fx("implosion", t.aim, 4.0, WIND)
		t.zone(t.aim, 4.0, 6.0, {"kind": "vide", "look": KitObject.Look.RING, "targetable": false,
			"color": Color(0.6, 0.75, 0.9), "data": {"since": {}},
			"on_tick": func(o: KitObject) -> void:
				_press(t, o)})

	func _press(t: Tk, o: KitObject) -> void:
		var dt: float = o.get_physics_process_delta_time()
		for n: Node3D in K.projectiles(t, o.global_position, o.radius):
			var own: bool = t.alive() and K.team_of(n) == t.caster.team
			n.global_position -= K.dir_of(n) * K.speed_of(n) * dt * (0.35 if own else 0.65)
		var since: Dictionary = o.data.since
		var now: Dictionary = {}
		for f: CombatCharacter in o.inside:
			if not is_instance_valid(f) or f.is_dead():
				continue
			if f.air_time > 0.0:
				f.air_time = maxf(0.0, f.air_time - dt)
			if t.is_enemy(f):
				f.kit.add_modifier("basse_pression", 0.3, {"label": "Basse pression", "color": Color(0.6, 0.75, 0.9)})
			var ab: AbilityController = f.abilities
			if ab.is_casting() and ab.current != null and ab.current.anim == &"breath" and ab.phase == AbilityController.Phase.ACTIVE:
				var key: int = f.get_instance_id()
				var s: float = float(since.get(key, 0.0)) + dt
				now[key] = s
				if s >= (1.2 if t.alive() and f == t.caster else 0.5):
					ab.end_active_early()
					t.text(f, "SOUFFLE COURT")
		o.data["since"] = now


## S — Domaine vectoriel, Recast, Contrôle. Eight wind points around a 7 m
## domain for 8 s. Every second, each point blows a corridor (Courant +
## enemy push 2 m, never a stun): four toward the centre, four outward,
## alternating. Recast (every 0.8 s): rotate the pattern by 45° — the
## inward / outward corridors swap instantly.
class TyphonDesHuitDirections extends Technique:
	const R: float = 7.0

	func configure(a: AbilityData) -> void:
		a.startup_time = 0.5
		a.max_range = 10.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var c: Vector3 = t.aim
		var base: Vector3 = t.dir
		var state: Dictionary = {"offset": 0}
		t.fx("ring", c, R, WIND)
		var domain: KitObject = t.zone(c, R, 8.0, {"kind": "typhon", "look": KitObject.Look.RING, "targetable": false,
			"color": WIND, "tick_interval": 1.0,
			"on_tick": func(o: KitObject) -> void:
				_pulse(t, o, base, state)})
		_arm_rotate(t, domain, state)

	func _arm_rotate(t: Tk, dv: Variant, state: Dictionary) -> void:
		if not is_instance_valid(dv) or not (dv as KitObject).is_alive():
			return
		var domain: KitObject = dv
		var left: float = domain.lifetime - domain.age
		if left <= 0.2:
			return
		t.recast(left, func(rt: Tk) -> void:
			if not is_instance_valid(domain) or not domain.is_alive():
				return
			state["offset"] = int(state.offset) + 1
			rt.fx("spheres", domain.global_position, R, WIND)
			rt.after(0.8, func(rt2: Tk) -> void:
				_arm_rotate(rt2, domain, state)))

	func _pulse(t: Tk, o: KitObject, base: Vector3, state: Dictionary) -> void:
		if not t.alive():
			o.destroy("caster")
			return
		var c: Vector3 = o.global_position
		for i in 8:
			var di: Vector3 = base.rotated(Vector3.UP, PI * 0.25 * i)
			var inward: bool = (i + int(state.offset)) % 2 == 0
			var flow: Vector3 = -di if inward else di
			var p: Vector3 = c + di * R
			t.fx("ring", p, 0.6, WIND)
			K.current(t, c + di * R * 0.5, flow, R, 2.2, 0.9, 1.4)
			var start: Vector3 = p if inward else c
			for e: CombatCharacter in t.enemies_in_line(start, flow, R, 2.2):
				if t.hit(e, t.dmg(0.1)) == HitData.Result.HIT:
					t.push(e, flow, 2.0, 0.45)


## S — Grande coupe, Télégraphe, Corridor. Direction locked at cast; a 1.2 s
## air distortion (line telegraph, caster slowed; stunned = lost), then a
## huge piercing blade crosses up to 30 m. Along its path a low-pressure
## Corridor (strong Courant, 4 s) stays: faster with it, slower against it.
class LameAtmospherique extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.35
		a.recovery_time = 0.3
		a.cast_move_multiplier = 0.3
		a.max_range = 30.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var d: Vector3 = t.dir
		var start: Vector3 = t.origin
		var end_at: Vector3 = t.clear_point(start, d, 30.0)
		var line_node: MeshInstance3D = null
		if CombatFx.is_enabled():
			line_node = KitVisuals.line_visual(t.caster.get_parent(), Color(WIND, 0.35))
			KitVisuals.update_line(line_node, start, end_at)
		t.object((start + end_at) * 0.5, {"kind": "distorsion", "radius": 0.5, "lifetime": 1.2, "look": KitObject.Look.NONE,
			"targetable": false,
			"on_destroy": func(_o: KitObject, _reason: String) -> void:
				if line_node != null and is_instance_valid(line_node):
					line_node.queue_free()})
		t.buff("condensation", 1.2, {"speed": 0.4, "label": "Condensation", "color": WIND})
		t.after(1.2, func(rt: Tk) -> void:
			if not rt.caster.status.can_act():
				rt.text(rt.caster, "DISSIPÉE")
				return
			var from: Vector3 = rt.origin
			rt.fx("wave", from, 1.5, WIND)
			rt.projectile({"from": from, "dir": d, "speed": 45.0, "range": 30.0, "radius": 1.1, "pierce": true, "size": 0.5,
				"color": WIND,
				"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
					rt.hit(e, rt.dmg(1.5))
					return true,
				"on_end": func(point: Vector3, _p: TkProjectile, _reason: String) -> void:
					if not rt.alive():
						return
					var length: float = rt.distance(from, point)
					if length > 1.0:
						K.current(rt, (HitQuery.flat(from) + point) * 0.5, d, length, 3.0, 4.0, 1.5)}))
