extends RefCounted
## Technique kit: clan Yuki (design bible). Signature: Givre ("givre" mark,
## max 4). Each stack adds glide after a sharp change of direction (the
## carrier keeps sliding along its previous velocity). At 4 stacks the next
## Yuki technique that hits consumes them for a Gel bref (short stun; the
## Senbon gives a strong short slow instead). Ice Mirrors ("miroir",
## "miroir_laby" objects) are destructible, limited teleport / reflection
## points: small Yuki projectiles that touch one exit from another.

const KIT_ID := &"clan_yuki"
const SIGNATURE = null
const TECHNIQUES := {
	&"clan_yuki_d_senbon_de_givre": SenbonDeGivre,
	&"clan_yuki_c_miroir_de_glace": MiroirDeGlace,
	&"clan_yuki_b_patinoire_fracturee": PatinoireFracturee,
	&"clan_yuki_a_labyrinthe_des_miroirs": LabyrintheDesMiroirs,
	&"clan_yuki_s_zero_absolu_cercueil_cristallin": ZeroAbsolu,
}

const GIVRE := "givre"
const GIVRE_TIME: float = 5.0
const ICE := Color(0.7, 0.9, 1.0)
const MIROIR_ID := &"clan_yuki_c_miroir_de_glace"
const PATINOIRE_ID := &"clan_yuki_b_patinoire_fracturee"
const LABY_ID := &"clan_yuki_a_labyrinthe_des_miroirs"


## Shared Yuki rules.
class K:
	## Adds Givre (capped at 4, no Gel) and the glide it causes.
	static func givre(t: Tk, e: CombatCharacter, n: int = 1) -> int:
		if e == null or not is_instance_valid(e) or e.is_dead():
			return 0
		var stacks: int = t.mark(e, GIVRE, n, GIVRE_TIME, 4, "Givre")
		ensure_glide(e)
		return stacks

	## A Yuki technique hit: at 4 Givre the threshold is consumed for a Gel
	## bref (or a strong short slow with `soft`); otherwise adds `n` Givre.
	## Returns true if the threshold was consumed.
	static func frost_hit(t: Tk, e: CombatCharacter, n: int = 1, soft: bool = false) -> bool:
		if not t.is_enemy(e):
			return false
		if t.marks(e, GIVRE) >= 4:
			t.consume_mark(e, GIVRE)
			t.fx("spikes", HitQuery.flat(e.global_position), 1.0, ICE)
			if soft:
				t.debuff(e, "givre_saisi", 0.6, {"speed": 0.25, "label": "Saisi", "color": ICE})
				t.text(e, "SAISI", ICE)
			else:
				t.status(e, StatusController.Type.STUN, 0.5)
				t.text(e, "GEL", ICE)
			return true
		givre(t, e, n)
		return false

	## Givre glide: a modifier on the carrier that keeps it sliding along its
	## previous velocity after a sharp turn or stop, stronger per stack.
	static func ensure_glide(f: CombatCharacter) -> void:
		if f.kit.has_modifier("givre_glisse"):
			f.kit.modifiers["givre_glisse"].left = GIVRE_TIME + 0.5
			return
		var st: Dictionary = {"prev": Vector3.ZERO, "cd": 0.0}
		f.kit.add_modifier("givre_glisse", GIVRE_TIME + 0.5, {"on_tick": func(dt: float) -> void:
			if is_instance_valid(f):
				slide_step(f, st, 0.45 * f.kit.mark(GIVRE), dt)})

	static func slide_step(f: CombatCharacter, st: Dictionary, strength: float, dt: float) -> void:
		st.cd = float(st.cd) - dt
		var v: Vector3 = HitQuery.flat(f.velocity)
		var prev: Vector3 = st.prev
		st.prev = v
		if strength <= 0.0 or float(st.cd) > 0.0 or f.movement.is_forced() or f.is_dead():
			return
		if prev.length() > 3.0 and (v.length() < 0.5 or prev.angle_to(v) > 1.0):
			f.movement.apply_forced_motion(prev.normalized() * (strength / 0.25), 0.25, true, false)
			st.cd = 0.45

	## Every alive mirror of the caster (both techniques).
	static func mirrors(t: Tk) -> Array[KitObject]:
		var out: Array[KitObject] = t.objects("miroir", MIROIR_ID)
		out.append_array(t.objects("miroir_laby", LABY_ID))
		return out

	## Where a projectile entering `m` comes out, or null.
	static func exit_mirror(t: Tk, m: KitObject) -> KitObject:
		if m.kind == "miroir":
			for o: KitObject in t.objects("miroir", MIROIR_ID):
				if o != m:
					return o
			return null
		var laby: Array[KitObject] = t.objects("miroir_laby", LABY_ID)
		var want: int = (int(m.data.get("index", 0)) + 2) % 4
		for o: KitObject in laby:
			if int(o.data.get("index", -1)) == want:
				return o
		for o: KitObject in laby:
			if o != m:
				return o
		return null

	## Ice needle: 1 Givre (strong short slow at 4). Goes through up to
	## `max_passes` mirrors (2 while a labyrinth stands), loses speed each
	## time; touching a Patinoire Fissure shatters the plate; a wall leaves a
	## tiny reflective shard.
	static func senbon(t: Tk, from: Vector3, d: Vector3, dmg_mult: float = 0.35) -> TkProjectile:
		var max_passes: int = 2 if not t.objects("miroir_laby", LABY_ID).is_empty() else 1
		return t.projectile({"from": from, "dir": d, "speed": 30.0, "range": 13.0, "radius": 0.45, "size": 0.1, "color": ICE,
			"data": {"passes": 0, "last": null},
			"on_tick": func(p: TkProjectile, _dt: float) -> void:
				if not is_instance_valid(t.caster):
					return
				var pos: Vector3 = p.ground_point()
				for fz: KitObject in t.objects("fissure", PATINOIRE_ID):
					if t.distance(fz.global_position, pos) < 0.8:
						shatter(t, fz.data.get("plate", {}))
						p.end("fissure")
						return
				if int(p.data.passes) >= max_passes:
					return
				for m: KitObject in mirrors(t):
					if m == p.data.last or t.distance(m.global_position, pos) > m.radius + 0.3:
						continue
					var out: KitObject = exit_mirror(t, m)
					if out == null:
						continue
					p.data.passes = int(p.data.passes) + 1
					p.data.last = out
					t.fx("sparks", m.global_position, 0.6, ICE)
					p.global_position = out.global_position + Vector3.UP * HitQuery.BODY_HEIGHT + p.direction * (out.radius + 0.4)
					p.speed *= 0.85
					p.travelled *= 0.5
					t.fx("sparks", out.global_position, 0.6, ICE)
					break,
			"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
				if not is_instance_valid(t.caster):
					return false
				if t.hit(e, t.dmg(dmg_mult)) == HitData.Result.HIT:
					frost_hit(t, e, 1, true)
				return false,
			"on_end": func(point: Vector3, _p: TkProjectile, reason: String) -> void:
				if not is_instance_valid(t.caster):
					return
				if reason == "wall":
					t.object(point, {"kind": "eclat", "radius": 0.3, "lifetime": 6.0, "look": KitObject.Look.ORB,
						"targetable": false, "color": ICE})})

	## A Patinoire plate bursts: fragments hit (Yuki technique) and slow.
	static func shatter(t: Tk, plate: Dictionary) -> void:
		if plate.is_empty() or plate.get("shattered", true):
			return
		plate["shattered"] = true
		for seg: KitObject in plate.get("segments", []):
			if not is_instance_valid(seg) or not seg.is_alive():
				continue
			t.fx("spikes", seg.global_position, seg.radius, ICE)
			for e: CombatCharacter in t.enemies_in(seg.global_position, seg.radius + 0.3):
				if t.hit(e, t.dmg(0.6), {"slow": 1.0}) == HitData.Result.HIT:
					frost_hit(t, e, 1)
			seg.destroy("shattered")
		for fz: KitObject in plate.get("fissures", []):
			if is_instance_valid(fz) and fz.is_alive():
				fz.destroy("shattered")

	## True if a fighter stands at `point` or a movement blocker covers it.
	static func obstructed(t: Tk, point: Vector3) -> bool:
		for f: CombatCharacter in t.fighters():
			if f != t.caster and t.distance(f.global_position, point) < 0.9:
				return true
		for node: Node in t.tree().get_nodes_in_group(&"kit_objects"):
			var o := node as KitObject
			if o != null and o.is_alive() and o.blocks_movement and o.contains(point):
				return true
		return false

	static func spawn_mirror(t: Tk, at: Vector3, kind: String, health: float, lifetime: float, data: Dictionary = {}) -> KitObject:
		t.fx("spikes", at, 0.8, ICE)
		return t.object(at, {"kind": kind, "radius": 0.6, "lifetime": lifetime, "health": health, "look": KitObject.Look.PILLAR,
			"color": ICE, "data": data})


## D — Projectile rapide, Stack, Poke. Fast thin needle: low damage, 1 Givre;
## on a target already at 4, consumes the threshold for a strong short slow
## (no full freeze). On a wall: a tiny shard hinting a mirror angle. Passes
## through a mirror pair once (twice in the labyrinth).
class SenbonDeGivre extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.1
		a.recovery_time = 0.18
		a.max_range = 13.0
		a.anim = &"throw"

	func cast(t: Tk) -> void:
		K.senbon(t, t.origin, t.dir)


## C — Objet, Téléportation, Angle. Places an ice Mirror at the aim (max 2,
## the oldest breaks; 30 HP, 25 s). Pressing again (recast chain, 6 s, up to
## 3 more uses) near a Mirror while two exist teleports to the other after a
## 0.3 s materialisation (vanished, rooted); fails if the exit is obstructed
## (checked at both ends of the delay). Otherwise places the next Mirror.
class MiroirDeGlace extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.12
		a.recovery_time = 0.15
		a.cast_move_multiplier = 1.0
		a.max_range = 10.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		_action(t, 3)

	func _action(t: Tk, uses_left: int) -> void:
		var mine: Array[KitObject] = t.objects("miroir")
		var near: KitObject = null
		for m: KitObject in mine:
			if t.distance(m.global_position, t.origin) <= 2.5:
				near = m
				break
		if near != null and mine.size() >= 2:
			var exit: KitObject = mine[0] if mine[1] == near else mine[1]
			_teleport(t, exit)
		else:
			if mine.size() >= 2:
				var oldest: KitObject = mine[0]
				for m: KitObject in mine:
					if m.age > oldest.age:
						oldest = m
				oldest.destroy("replaced")
			var d: Vector3 = HitQuery.flat(t.aim - t.origin)
			var at: Vector3 = t.aim if d.length() < 0.5 else t.clear_point(t.origin, d.normalized(), d.length())
			K.spawn_mirror(t, at, "miroir", 30.0, 25.0)
		if uses_left > 0:
			t.recast(6.0, func(rt: Tk) -> void:
				_action(rt, uses_left - 1))

	func _teleport(t: Tk, exit: KitObject) -> void:
		var dest: Vector3 = HitQuery.flat(exit.global_position) + t.dir * 1.0
		if K.obstructed(t, dest):
			t.text(t.caster, "BLOQUÉ", ICE)
			return
		t.fx("spheres", t.origin, 0.8, ICE)
		t.status(t.caster, StatusController.Type.IMMATERIAL, 0.3)
		t.status(t.caster, StatusController.Type.ROOT, 0.3)
		t.after(0.3, func(rt: Tk) -> void:
			if not is_instance_valid(exit) or not exit.is_alive() or K.obstructed(rt, dest):
				rt.text(rt.caster, "BLOQUÉ", ICE)
				return
			rt.blink(dest)
			rt.fx("spikes", dest, 0.8, ICE))


## B — Terrain, Glisse, Fissures. A long ice plate (3 segments along the aim,
## 9 s). Everyone on it glides (keeps sliding after turns). Each dash or
## heavy knockback on it cracks a Fissure (glyph); 2 Fissures announce the
## break, 3 burst the plate into fragments (damage, slow, Givre). A Senbon
## shot into a Fissure bursts it on demand.
class PatinoireFracturee extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.25
		a.recovery_time = 0.25
		a.max_range = 9.0
		a.anim = &"stomp"

	func cast(t: Tk) -> void:
		var plate: Dictionary = {"segments": [], "fissures": [], "n": 0, "shattered": false, "cd": {}}
		for i in 3:
			var at: Vector3 = t.aim + t.dir * (-2.8 + 2.8 * i)
			var seg: KitObject = t.zone(at, 1.7, 9.0, {"kind": "glace", "color": ICE, "targetable": false, "data": {"plate": plate},
				"on_tick": func(o: KitObject) -> void:
					if not is_instance_valid(t.caster):
						return
					for f: CombatCharacter in o.inside:
						if not is_instance_valid(f) or f.is_dead():
							continue
						_glide(f)
						if f.movement.is_forced() and f.movement.forced_speed() > 10.0:
							var key: int = f.get_instance_id()
							if o.age - float(plate.cd.get(key, -10.0)) > 0.6:
								plate.cd[key] = o.age
								_fissure(t, plate, HitQuery.flat(f.global_position), 9.0 - o.age)})
			plate.segments.append(seg)
		t.fx("wave", t.aim, 4.0, ICE)

	## Ice contact: a short refreshed glide modifier (both teams).
	func _glide(f: CombatCharacter) -> void:
		if f.kit.has_modifier("patinoire"):
			f.kit.modifiers["patinoire"].left = 0.25
			return
		var st: Dictionary = {"prev": Vector3.ZERO, "cd": 0.0}
		f.kit.add_modifier("patinoire", 0.25, {"on_tick": func(dt: float) -> void:
			if is_instance_valid(f):
				K.slide_step(f, st, 1.6, dt)})

	func _fissure(t: Tk, plate: Dictionary, at: Vector3, left: float) -> void:
		if plate.shattered:
			return
		plate.n = int(plate.n) + 1
		t.fx("cracks", at, 1.0, ICE)
		plate.fissures.append(t.object(at, {"kind": "fissure", "radius": 0.5, "lifetime": maxf(left, 0.5),
			"look": KitObject.Look.GLYPH, "targetable": false, "color": Color(0.5, 0.75, 1.0), "data": {"plate": plate}}))
		if int(plate.n) == 2:
			for seg: KitObject in plate.segments:
				if is_instance_valid(seg) and seg.is_alive():
					t.fx("cracks", seg.global_position, seg.radius, ICE)
		elif int(plate.n) >= 3:
			K.shatter(t, plate)


## A — Multi-objet, Téléportation séquencée, Illusion légère. Four temporary
## Mirrors (25 HP, 8 s) in a diamond around the aim; the Yuki blinks to the
## nearest. Recast (chain, up to 6 hops, 0.35 s minimum spacing): blink to
## the adjacent Mirror closest to the cursor. Each hop leaves an ice
## silhouette that takes one step then shatters (small hit + Givre). Senbon
## can go through two Mirrors while it stands.
class LabyrintheDesMiroirs extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.3
		a.recovery_time = 0.2
		a.cast_move_multiplier = 1.0
		a.max_range = 8.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		for m: KitObject in t.objects("miroir_laby"):
			m.destroy("replaced")
		var side: Vector3 = t.dir.cross(Vector3.UP).normalized()
		var dirs: Array[Vector3] = [t.dir, side, -t.dir, -side]
		var center: Vector3 = t.aim
		for i in 4:
			var at: Vector3 = t.clear_point(center, dirs[i], 3.5)
			K.spawn_mirror(t, at, "miroir_laby", 25.0, 8.0, {"index": i})
		t.fx("ring", center, 3.5, ICE)
		var st: Dictionary = {"at": -1, "last": -1.0, "age": 0.0}
		t.buff("labyrinthe", 8.0, {"on_tick": func(dt: float) -> void:
			st.age = float(st.age) + dt})
		_enter(t, st)
		_open(t, st, 6)

	func _mirror(t: Tk, index: int) -> KitObject:
		for m: KitObject in t.objects("miroir_laby"):
			if int(m.data.get("index", -1)) == index:
				return m
		return null

	func _enter(t: Tk, st: Dictionary) -> void:
		var best: KitObject = null
		for m: KitObject in t.objects("miroir_laby"):
			if best == null or t.distance(m.global_position, t.origin) < t.distance(best.global_position, t.origin):
				best = m
		if best == null:
			return
		_hop(t, st, best)

	func _hop(t: Tk, st: Dictionary, to: KitObject) -> void:
		var from: Vector3 = HitQuery.flat(t.caster.global_position)
		var dest: Vector3 = HitQuery.flat(to.global_position) + HitQuery.flat(from - to.global_position).normalized() * 0.9
		if K.obstructed(t, dest):
			dest = HitQuery.flat(to.global_position) - HitQuery.flat(from - to.global_position).normalized() * 0.9
		st.at = int(to.data.get("index", -1))
		st.last = float(st.age)
		var step: Vector3 = HitQuery.flat(dest - from).normalized()
		t.blink(dest)
		t.object(from, {"kind": "silhouette", "radius": 0.5, "lifetime": 0.45, "look": KitObject.Look.DECOY, "targetable": false,
			"color": ICE, "on_tick": func(o: KitObject) -> void:
				if not is_instance_valid(t.caster):
					return
				o.global_position += step * 2.6 * o.get_physics_process_delta_time(),
			"on_expire": func(o: KitObject) -> void:
				if not is_instance_valid(t.caster):
					return
				var at: Vector3 = HitQuery.flat(o.global_position)
				t.fx("spikes", at, 1.2, ICE)
				for e: CombatCharacter in t.enemies_in(at, 1.2):
					if t.hit(e, t.dmg(0.3)) == HitData.Result.HIT:
						K.frost_hit(t, e, 1)})

	func _open(t: Tk, st: Dictionary, hops_left: int) -> void:
		if hops_left <= 0 or t.objects("miroir_laby").is_empty():
			return
		t.recast(8.0 - float(st.age), func(rt: Tk) -> void:
			if float(st.age) - float(st.last) < 0.35:
				_open(rt, st, hops_left)
				return
			var cur: int = int(st.at)
			var here: KitObject = _mirror(rt, cur)
			if here == null or rt.distance(here.global_position, rt.origin) > 2.5:
				_enter(rt, st)
			else:
				var best: KitObject = null
				for idx: int in [(cur + 1) % 4, (cur + 3) % 4]:
					var m: KitObject = _mirror(rt, idx)
					if m != null and (best == null or rt.distance(m.global_position, rt.aim) < rt.distance(best.global_position, rt.aim)):
						best = m
				if best == null:
					rt.text(rt.caster, "BRISÉ", ICE)
					return
				_hop(rt, st, best)
			_open(rt, st, hops_left - 1))


## S — Domaine froid, Gestion de stacks, Finisher. An ice storm (radius 7,
## 8 s): every second +1 Givre to enemies inside (no Gel), the Yuki itself
## every 3 s; mirrors inside are reinforced once (health doubled). Recast
## (repeatable while the domain lasts): every enemy inside at 4 Givre loses
## them and gets three destructible ice plates around it that close after
## 1 s: still inside with all plates intact = crystal coffin (stun + heavy
## damage). Leaving or breaking a plate escapes.
class ZeroAbsolu extends Technique:
	const RADIUS: float = 7.0
	const LIFE: float = 8.0

	func configure(a: AbilityData) -> void:
		a.startup_time = 0.5
		a.recovery_time = 0.3
		a.max_range = 6.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var center: Vector3 = t.aim
		t.fx("wave", center, RADIUS, ICE)
		var domain: KitObject = t.zone(center, RADIUS, LIFE, {"kind": "domaine_froid", "look": KitObject.Look.RING, "targetable": false,
			"color": ICE, "tick_interval": 1.0, "data": {"pulses": 0},
			"on_tick": func(o: KitObject) -> void:
				if not is_instance_valid(t.caster):
					return
				if o.age < 0.5:
					return
				o.data.pulses = int(o.data.pulses) + 1
				t.fx("ring", o.global_position, RADIUS, ICE)
				for e: CombatCharacter in o.enemies_inside():
					K.givre(t, e, 1)
				if int(o.data.pulses) % 3 == 0 and t.alive() and o.contains(t.caster.global_position):
					K.givre(t, t.caster, 1)
				for m: KitObject in K.mirrors(t):
					if o.contains(m.global_position) and not m.data.get("reinforced", false):
						m.data["reinforced"] = true
						m.health += maxf(m.max_health, 0.0)
						t.fx("spheres", m.global_position, 0.7, ICE)})
		_open(t, domain)

	func _open(t: Tk, domain: KitObject) -> void:
		if not is_instance_valid(domain) or not domain.is_alive():
			return
		t.recast(maxf(0.1, LIFE - domain.age), func(rt: Tk) -> void:
			if not is_instance_valid(domain) or not domain.is_alive():
				return
			var any: bool = false
			for e: CombatCharacter in domain.enemies_inside():
				if rt.marks(e, GIVRE) >= 4:
					any = true
					rt.consume_mark(e, GIVRE)
					_coffin(rt, e)
			if not any:
				rt.text(rt.caster, "PAS DE SEUIL", ICE)
			_open(rt, domain))

	func _coffin(t: Tk, e: CombatCharacter) -> void:
		var center: Vector3 = HitQuery.flat(e.global_position)
		var plates: Array[KitObject] = []
		for i in 3:
			var d: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 3.0)
			plates.append(t.wall(center + d * 2.0, d, 2.4, 1.6, {"kind": "plaque", "health": 30.0, "color": ICE}))
		t.fx("spikes", center, 2.0, ICE)
		t.text(e, "CERCUEIL", ICE)
		t.after(1.0, func(rt: Tk) -> void:
			var intact: bool = true
			for p: KitObject in plates:
				if not is_instance_valid(p) or not p.is_alive():
					intact = false
			for p: KitObject in plates:
				if is_instance_valid(p) and p.is_alive():
					p.destroy("closed")
			if intact and rt.is_enemy(e) and rt.distance(e.global_position, center) <= 2.0:
				rt.fx("column", center, 1.5, ICE)
				if rt.hit(e, rt.dmg(1.6), {"stun": 0.8}) == HitData.Result.HIT:
					rt.text(e, "CRISTAL", ICE)
			else:
				rt.fx("cracks", center, 2.0, ICE))
