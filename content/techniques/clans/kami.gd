extends RefCounted
## Technique kit: Clan Kami (design bible). Signature: Feuilles — a paper
## reserve (100) recharging slowly. Techniques detach leaf packets onto the
## field ("feuilles" objects); walking over them (or recalling them with
## Ailes du papier) restores the reserve much faster. Leaves can be
## Explosive (packet data "explosive", or the "papier_explosif" mark stuck on
## an enemy), but only some techniques set them off (Clone origami, Cage de
## mille feuillets, Océan de papier).

const KIT_ID := &"clan_kami"
const SIGNATURE = KamiSignature
const TECHNIQUES := {
	&"clan_kami_d_shuriken_de_papier": ShurikenDePapier,
	&"clan_kami_c_clone_origami": CloneOrigami,
	&"clan_kami_b_ailes_du_papier": AilesDuPapier,
	&"clan_kami_a_cage_de_mille_feuillets": CageDeMilleFeuillets,
	&"clan_kami_s_ocean_de_papier_mille_detonations": OceanDePapier,
}

const FEUILLES := "feuilles"
const FEUILLES_MAX: float = 100.0
const FEUILLES_REGEN: float = 2.5
const PACKET := "feuilles"
const PACKET_GAIN: float = 10.0
const PACKET_LIFE: float = 15.0
const EXPLOSIF := "papier_explosif"
const COLLEES := "feuilles_collees"
const PAPER := Color(0.92, 0.9, 0.98)
const BOOM := Color(1.0, 0.55, 0.25)


## Feuilles: slow recharge, fast recovery by picking up leaf packets.
class KamiSignature extends KitSignature:
	func setup(f: CombatCharacter) -> void:
		f.kit.define_resource(FEUILLES, FEUILLES_MAX, "Feuilles", PAPER)
		f.kit.add_res(FEUILLES, FEUILLES_MAX)

	func tick(f: CombatCharacter, delta: float) -> void:
		if f.kit.res(FEUILLES) < FEUILLES_MAX and not f.kit.has_modifier("ailes_papier"):
			f.kit.add_res(FEUILLES, FEUILLES_REGEN * delta)
		for o: KitObject in KitObject.find(f.get_tree(), f, &"", PACKET):
			if o.age > 0.4 and HitQuery.flat(o.global_position - f.global_position).length() <= 1.2:
				f.kit.add_res(FEUILLES, PACKET_GAIN * (1.5 if o.data.get("explosive", false) else 1.0))
				o.destroy("picked")


## Shared Kami rules.
class K:
	static func spend(t: Tk, amount: float) -> bool:
		return t.spend_res(FEUILLES, amount)

	## A leaf packet on the ground (recoverable; explosive ones are beacons).
	static func packet(t: Tk, at: Vector3, explosive: bool = false) -> KitObject:
		return t.object(at, {"kind": PACKET, "radius": 0.5, "lifetime": PACKET_LIFE, "look": KitObject.Look.GLYPH,
			"targetable": false, "color": BOOM if explosive else PAPER, "data": {"explosive": explosive}})

	static func explosive_packets(t: Tk, center: Vector3, radius: float) -> Array[KitObject]:
		var out: Array[KitObject] = []
		for o: KitObject in t.objects(PACKET, &""):
			if o.data.get("explosive", false) and t.distance(o.global_position, center) <= radius:
				out.append(o)
		return out

	static func blast(t: Tk, at: Vector3, radius: float, damage: float, push: float = 0.0) -> Array[CombatCharacter]:
		t.fx("explosion", at, radius, BOOM)
		var opts: Dictionary = {}
		if push > 0.0:
			opts["push"] = push
		return t.area(at, radius, damage, opts)


## D — Projectile multiple, Ressource, Marque. Three paper shuriken in a fan
## (3 Feuilles each). Misses stick in the ground as recoverable leaf packets.
## Recast while they fly ("hold"): 10 Feuilles make the central one
## Explosive — it does not explode, it becomes a beacon (mark on the enemy
## hit, or an explosive packet where it lands).
class ShurikenDePapier extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.12
		a.active_time = 0.05
		a.recovery_time = 0.2
		a.max_range = 12.0
		a.anim = &"throw"

	func cast(t: Tk) -> void:
		var count: int = 3 if K.spend(t, 9.0) else 1
		var held := {"central": null}
		for i in count:
			var off: float = 0.0 if count == 1 else -10.0 + 10.0 * i
			var p: TkProjectile = t.projectile({"dir": t.dir.rotated(Vector3.UP, deg_to_rad(off)), "speed": 24.0, "range": 12.0,
				"radius": 0.45, "size": 0.16, "color": PAPER, "data": {"explosive": false},
				"on_hit": func(e: CombatCharacter, proj: TkProjectile) -> bool:
					t.hit(e, t.dmg(0.4))
					if proj.data.get("explosive", false):
						t.mark(e, EXPLOSIF, 1, 10.0, 5, "Papier explosif")
						t.text(e, "BALISE")
					return false,
				"on_end": func(point: Vector3, proj: TkProjectile, reason: String) -> void:
					if reason != "hit":
						K.packet(t, point, bool(proj.data.get("explosive", false)))})
			if count == 1 or i == 1:
				held["central"] = p
		t.recast(0.6, func(rt: Tk) -> void:
			var central: Variant = held.central
			if is_instance_valid(central) and (central as TkProjectile).is_alive() and K.spend(rt, 10.0):
				(central as TkProjectile).data["explosive"] = true
				rt.fx("sparks", (central as TkProjectile).ground_point(), 0.5, BOOM))


## C — Decoy, Trap, Recast. A paper clone runs straight along the aim
## (4 s); it picks up Explosive packets it runs over. The first hit it takes
## turns it into leaf packets. Recast: it bursts into a leaf cloud (blinds:
## damage dealt -20 %, slow); carrying an Explosive leaf, the burst also
## knocks back.
class CloneOrigami extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.15
		a.active_time = 0.05
		a.max_range = 12.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var life: float = 4.0 if K.spend(t, 15.0) else 2.0
		var d: Vector3 = t.dir
		t.object(t.origin + d * 1.0, {"kind": "clone_origami", "radius": 0.5, "lifetime": life,
			"health": 1.0, "look": KitObject.Look.DECOY, "color": PAPER, "data": {"explosive": false},
			"on_tick": func(o: KitObject) -> void:
				var step: float = 6.5 * o.get_physics_process_delta_time()
				var next: Vector3 = t.clear_point(o.global_position, d, step + 0.6)
				if t.distance(next, o.global_position) > step:
					o.global_position += d * step
				for p: KitObject in K.explosive_packets(t, o.global_position, 0.9):
					p.destroy("carried")
					o.data["explosive"] = true,
			"on_destroy": func(o: KitObject, reason: String) -> void:
				if reason == "destroyed" or reason == "expired":
					t.fx("burst", o.global_position, 0.8, PAPER)
					K.packet(t, o.global_position, bool(o.data.get("explosive", false)))
					K.packet(t, o.global_position + d.cross(Vector3.UP) * 0.8)})
		t.recast(life, func(rt: Tk) -> void:
			for clone: KitObject in rt.objects("clone_origami"):
				_cloud(rt, clone))

	func _cloud(t: Tk, clone: KitObject) -> void:
		var at: Vector3 = clone.global_position
		var explosive: bool = clone.data.get("explosive", false)
		clone.destroy("cloud")
		t.fx("smoke", at, 2.6, PAPER)
		if explosive:
			K.blast(t, at, 2.6, t.dmg(0.35), 3.0)
		t.zone(at, 2.6, 2.5, {"kind": "nuage_feuilles", "tick_interval": 0.25, "targetable": false, "color": PAPER,
			"on_tick": func(o: KitObject) -> void:
				for e: CombatCharacter in o.enemies_inside():
					if t.is_enemy(e):
						t.status(e, StatusController.Type.SLOW, 0.4)
						t.debuff(e, "aveugle_papier", 0.6, {"damage_dealt": 0.8, "label": "Aveuglé", "color": PAPER})})


## B — Vol limité, Ressource continue, Pluie. Paper wings (4 s): the caster
## flies (airborne: ground areas pass under, +20 % speed) while the reserve
## drains (5 Feuilles / 0.5 s, wings fold when empty). Basic attacks that
## land drop leaves onto the ground (packet + small paper rain hit). Recast:
## fold into a fast dive (small impact) and recall half the nearby packets
## right under the caster.
class AilesDuPapier extends Technique:
	const MODE := "ailes_papier"

	func configure(a: AbilityData) -> void:
		a.startup_time = 0.2
		a.active_time = 0.05
		a.max_range = 6.0
		a.anim = &"leap"

	func cast(t: Tk) -> void:
		var state := {"drain": 0.0, "rain": -1.0}
		var c: CombatCharacter = t.caster
		t.fx("wave", t.origin, 1.5, PAPER)
		t.buff(MODE, 4.0, {"speed": 1.2, "label": "Ailes", "color": PAPER,
			"on_tick": func(dt: float) -> void:
				if not is_instance_valid(c):
					return
				c.air_time = maxf(c.air_time, CombatCharacter.JUMP_DURATION * 0.5)
				state["drain"] = float(state.drain) + dt
				if float(state.drain) >= 0.5:
					state["drain"] = 0.0
					if not c.kit.spend_res(FEUILLES, 5.0):
						c.kit.remove_modifier(MODE),
			"on_deal": func(target: CombatCharacter, hit: HitData, _dmg: float) -> Variant:
				var now: float = Time.get_ticks_msec() / 1000.0
				if hit.ability != null and c.abilities.is_basic_attack(hit.ability) and now - float(state.rain) > 0.35:
					state["rain"] = now
					K.packet(t, target.global_position + Vector3(randf_range(-0.6, 0.6), 0.0, randf_range(-0.6, 0.6)))
					t.after(0.0, func(rt: Tk) -> void:
						rt.fx("burst", target.global_position, 0.6, PAPER)
						rt.hit(target, rt.dmg(0.15)))
				return null,
			"on_end": func() -> void:
				if is_instance_valid(c):
					c.air_time = minf(c.air_time, 0.1)
					c.kit.close_recast(t.id)})
		t.recast(4.0, func(rt: Tk) -> void:
			if not rt.kit().has_modifier(MODE):
				return
			rt.kit().remove_modifier(MODE)
			rt.fx("wave", rt.origin, 2.0, PAPER)
			rt.area(rt.origin, 2.0, rt.dmg(0.4))
			_recall(rt))

	func _recall(t: Tk) -> void:
		var packets: Array[KitObject] = []
		for o: KitObject in t.objects(PACKET, &""):
			if t.distance(o.global_position, t.origin) <= 10.0:
				packets.append(o)
		packets.sort_custom(func(a: KitObject, b: KitObject) -> bool:
			return t.distance(a.global_position, t.origin) < t.distance(b.global_position, t.origin))
		var n: int = ceili(packets.size() * 0.5)
		for i in n:
			var o: KitObject = packets[i]
			t.fx("burst", o.global_position, 0.4, PAPER)
			o.global_position = t.origin + Vector3(randf_range(-0.5, 0.5), 0.0, randf_range(-0.5, 0.5))
			o.age = maxf(o.age, 0.5)


## A — Zone, Barrière poreuse, Détonateurs. Spinning paper cage (7 s, 30
## Feuilles; smaller without). Crossing its wall sticks 2 leaves on a
## character (mark). Explosive packets inside the cage are woven into it:
## each makes one stuck leaf Explosive. Single recast: only Explosive leaves
## blow up (damage per leaf); the others become visible beacons for 4 s.
class CageDeMilleFeuillets extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.3
		a.active_time = 0.05
		a.max_range = 10.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var r: float = 4.5 if K.spend(t, 30.0) else 3.0
		var strips: int = 0
		for p: KitObject in K.explosive_packets(t, t.aim, r):
			p.destroy("woven")
			strips += 1
		var state := {"strips": strips}
		var stick := func(e: CombatCharacter, _o: KitObject) -> void:
			if not t.is_enemy(e):
				return
			t.mark(e, COLLEES, 2, 8.0, 8, "Feuilles collées")
			if int(state.strips) > 0:
				state["strips"] = int(state.strips) - 1
				t.mark(e, EXPLOSIF, 1, 10.0, 5, "Papier explosif")
		t.fx("ring", t.aim, r, PAPER)
		t.zone(t.aim, r, 7.0, {"kind": "cage", "look": KitObject.Look.RING, "targetable": false,
			"color": PAPER, "on_enter": stick, "on_exit": stick})
		t.recast(7.0, func(rt: Tk) -> void:
			var cages: Array[KitObject] = rt.objects("cage")
			var center: Vector3 = cages[0].global_position if not cages.is_empty() else rt.aim
			for e: CombatCharacter in rt.enemies_in(rt.origin, 25.0):
				var n: int = rt.consume_mark(e, EXPLOSIF)
				if n > 0:
					rt.fx("explosion", e.global_position, 1.0 + 0.2 * n, BOOM)
					rt.hit(e, rt.dmg(0.3 * n), {"push": 1.5 + 0.5 * n, "push_from": center})
				if rt.consume_mark(e, COLLEES) > 0:
					rt.debuff(e, "balise_papier", 4.0, {"label": "Balisé", "color": PAPER})
					rt.text(e, "BALISE")
			for cage: KitObject in cages:
				cage.destroy("detonated"))


## S — Domaine, Ressource totale, Chaîne programmable. Takes the whole
## reserve to cover a 10 m domain with paper, then channels 3 × 0.45 s: each
## pulse records a detonation path toward the cursor. Paths then go off in
## order, each announced 0.4 s before, explosions running along it. Explosive
## packets in the domain branch off the nearest path; Explosive leaves stuck
## on enemies blow up too. Damage scales with the reserve; ≤ 4 hits/target.
class OceanDePapier extends Technique:
	const DOMAIN: float = 10.0

	func configure(a: AbilityData) -> void:
		a.startup_time = 0.4
		a.active_time = 0.05
		a.max_range = 10.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var reserve: float = t.take_all_res(FEUILLES)
		var center: Vector3 = t.origin
		var state := {"paths": [], "hits": {}, "mult": 0.3 + 0.35 * reserve / FEUILLES_MAX}
		t.zone(center, DOMAIN, 4.5, {"kind": "ocean", "targetable": false, "color": Color(0.9, 0.9, 1.0, 0.35)})
		t.fx("wave", center, DOMAIN, PAPER)
		t.channel(3, 0.45, func(ct: Tk, _i: int) -> void:
			var from: Vector3 = ct.origin
			var to: Vector3 = center + HitQuery.flat(ct.aim - center).limit_length(DOMAIN)
			if ct.distance(from, to) < 2.0:
				to = from + ct.dir * 6.0
			(state.paths as Array).append([from, to])
			ct.fx("ring", to, 0.8, BOOM),
			func(dt: Tk, _completed: bool) -> void:
				_detonate(dt, center, state))

	func _detonate(t: Tk, center: Vector3, state: Dictionary) -> void:
		var paths: Array = state.paths
		var branches: Array[KitObject] = K.explosive_packets(t, center, DOMAIN)
		for k in paths.size():
			var from: Vector3 = paths[k][0]
			var to: Vector3 = paths[k][1]
			var delay: float = 0.7 * k
			var my_branches: Array[KitObject] = []
			for b: KitObject in branches:
				if _nearest_path(b.global_position, paths) == k:
					my_branches.append(b)
			t.after(delay, func(rt: Tk) -> void:
				_run_path(rt, from, to, state, my_branches, k))
		t.after(0.7 * paths.size() + 0.4, func(rt: Tk) -> void:
			for e: CombatCharacter in rt.enemies_in(center, DOMAIN):
				var n: int = rt.consume_mark(e, EXPLOSIF)
				if n > 0:
					_boom(rt, e.global_position, 1.4, state, 0.6 * n, "mark%d" % e.get_instance_id()))

	func _nearest_path(p: Vector3, paths: Array) -> int:
		var best: int = 0
		var best_d: float = INF
		for k in paths.size():
			var d: float = _dist_to_segment(p, paths[k][0], paths[k][1])
			if d < best_d:
				best = k
				best_d = d
		return best

	func _dist_to_segment(p: Vector3, a: Vector3, b: Vector3) -> float:
		var ab: Vector3 = HitQuery.flat(b - a)
		var u: float = 0.0 if ab.length_squared() < 0.01 else clampf(HitQuery.flat(p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		return HitQuery.flat(p - (a + ab * u)).length()

	## Telegraph the path, then explosions run along it; branches to the
	## explosive packets start from the closest point of the path.
	func _run_path(t: Tk, from: Vector3, to: Vector3, state: Dictionary, branches: Array[KitObject], path_id: int) -> void:
		var points: Array[Vector3] = _points(from, to)
		for p: Vector3 in points:
			t.object(p, {"kind": "chemin", "radius": 0.7, "lifetime": 0.4, "look": KitObject.Look.RING,
				"targetable": false, "color": BOOM})
		for j in points.size():
			var at: Vector3 = points[j]
			t.after(0.4 + 0.07 * j, func(rt: Tk) -> void:
				_boom(rt, at, 1.3, state, 1.0, "path%d" % path_id))
		for bv: Variant in branches:
			if not is_instance_valid(bv) or not (bv as KitObject).is_alive():
				continue
			var b: KitObject = bv
			var target: Vector3 = b.global_position
			var ab: Vector3 = HitQuery.flat(to - from)
			var u: float = 0.0 if ab.length_squared() < 0.01 else clampf(HitQuery.flat(target - from).dot(ab) / ab.length_squared(), 0.0, 1.0)
			var start: Vector3 = from + ab * u
			var start_delay: float = 0.4 + 0.07 * u * float(points.size())
			var bpoints: Array[Vector3] = _points(start, target)
			var branch := {"packet": b}
			var bid: int = b.get_instance_id()
			for j in bpoints.size():
				var at: Vector3 = bpoints[j]
				var last: bool = j == bpoints.size() - 1
				t.after(start_delay + 0.07 * (j + 1), func(rt: Tk) -> void:
					if last:
						var packet: Variant = branch.packet
						if is_instance_valid(packet) and (packet as KitObject).is_alive():
							(packet as KitObject).destroy("detonated")
						_boom(rt, at, 2.0, state, 1.6, "end%d" % bid)
					else:
						_boom(rt, at, 1.1, state, 0.8, "branch%d" % bid))

	func _points(from: Vector3, to: Vector3) -> Array[Vector3]:
		var out: Array[Vector3] = []
		var length: float = HitQuery.flat(to - from).length()
		var n: int = maxi(1, int(length / 1.4))
		for j in n + 1:
			out.append(HitQuery.flat(from.lerp(to, float(j) / float(n))))
		return out

	## One explosion; a chain (`group`: a path, a branch) hits a target once,
	## and a target takes at most 4 hits from the whole ultimate.
	func _boom(t: Tk, at: Vector3, radius: float, state: Dictionary, scale: float, group: String) -> void:
		t.fx("explosion", at, radius, BOOM)
		var hits: Dictionary = state.hits
		for e: CombatCharacter in t.enemies_in(at, radius):
			var key: int = e.get_instance_id()
			var tag: String = group + ":" + str(key)
			if int(hits.get(key, 0)) >= 4 or hits.has(tag):
				continue
			hits[key] = int(hits.get(key, 0)) + 1
			hits[tag] = true
			t.hit(e, t.dmg(float(state.mult) * scale))
		KitObject.damage_objects_in(t.tree(), at, radius, t.caster.team, t.dmg(0.3))
