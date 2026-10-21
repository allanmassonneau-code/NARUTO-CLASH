extends RefCounted
## Technique kit: Katon (design bible §4). Signature: Braise / Ignition — a
## target carries up to 3 Braises ("braise" mark); an Ignition consumes them
## all and scales with the count. Cendres zones ("cendres" objects) deal
## almost nothing alone but fuel other techniques; missed Braises stay on
## the ground ("braise_sol" objects).

const KIT_ID := &"katon"
const SIGNATURE = null
const TECHNIQUES := {
	&"katon_d_braise_tracante": BraiseTracante,
	&"katon_d_souffle_de_recul": SouffleDeRecul,
	&"katon_c_anneau_de_cendres": AnneauDeCendres,
	&"katon_c_comete_incendiaire": CometeIncendiaire,
	&"katon_b_prison_thermique": PrisonThermique,
	&"katon_b_lance_de_verre": LanceDeVerre,
	&"katon_a_mer_de_flammes": MerDeFlammes,
	&"katon_a_phenix_a_rebond": PhenixARebond,
	&"katon_s_fournaise_solaire": FournaiseSolaire,
	&"katon_s_dragon_de_feu_devorant": DragonDeFeuDevorant,
}

const BRAISE := "braise"
const BRAISE_TIME: float = 6.0
const ASH := Color(0.45, 0.42, 0.4)


## Shared Katon rules.
class K:
	static func braise(t: Tk, target: CombatCharacter, stacks: int = 1) -> int:
		return t.mark(target, BRAISE, stacks, BRAISE_TIME, 3, "Braise")

	## Ignition: consumes every Braise of `target`; returns how many.
	## Ignited Braises always add a micro-explosion; inside an Anneau de
	## cendres the ring flares; 3 Braises inside a Prison thermique pulse it.
	static func ignite(t: Tk, target: CombatCharacter, mult_per_braise: float = 0.35) -> int:
		var n: int = t.consume_mark(target, BRAISE)
		if n <= 0 or not t.is_enemy(target):
			return n
		var at: Vector3 = HitQuery.flat(target.global_position)
		t.fx("explosion", at, 0.8 + 0.3 * n)
		t.hit(target, t.dmg(mult_per_braise * n))
		t.area(at, 1.6, t.dmg(0.25))
		for ring: KitObject in t.objects("anneau", &"katon_c_anneau_de_cendres"):
			if ring.contains(at):
				ring_flare(t, ring)
		if n >= 3:
			for dome: KitObject in t.objects("dome", &"katon_b_prison_thermique"):
				if dome.contains(at) and not dome.data.get("pulsed", false):
					dome.data["pulsed"] = true
					t.fx("wave", dome.global_position, dome.radius)
					for e: CombatCharacter in t.enemies_in(dome.global_position, dome.radius + 1.5):
						t.pull(e, dome.global_position, 2.0)
		return n

	## The ring's edge flares: whoever stands on the border is pushed inward.
	static func ring_flare(t: Tk, ring: KitObject) -> void:
		t.fx("ring", ring.global_position, ring.radius, Color(1.0, 0.5, 0.1))
		for e: CombatCharacter in t.enemies_in(ring.global_position, ring.radius + 1.0):
			var d: float = t.distance(e.global_position, ring.global_position)
			if d > ring.radius - 1.2:
				t.hit(e, t.dmg(0.2))
				t.pull(e, ring.global_position, 1.8)

	## Ashes on the ground: fuel for flames and ignitions.
	static func ashes(t: Tk, center: Vector3, radius: float, lifetime: float) -> KitObject:
		return t.zone(center, radius, lifetime, {"kind": "cendres", "color": ASH, "targetable": false})

	## A missed Braise stays on the ground.
	static func ground_braise(t: Tk, at: Vector3) -> KitObject:
		return t.object(at, {"kind": "braise_sol", "radius": 0.9, "lifetime": BRAISE_TIME, "look": KitObject.Look.ORB,
			"targetable": false, "color": Color(1.0, 0.45, 0.1)})


## D — Projectile, Marque, Poke. Fast ember with slight tracking on a
## visible target; on hit a Braise, on a miss a ground Braise.
class BraiseTracante extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.12
		a.recovery_time = 0.2
		a.max_range = 13.0
		a.anim = &"throw"

	func cast(t: Tk) -> void:
		t.projectile({"speed": 26.0, "range": 13.0, "radius": 0.5, "homing": 1.6, "size": 0.18,
			"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
				t.hit(e, t.dmg(0.45))
				K.braise(t, e)
				return false,
			"on_end": func(point: Vector3, _p: TkProjectile, reason: String) -> void:
				if reason != "hit":
					K.ground_braise(t, point)})


## D — Cône, Anti-melee, Zone. Short burst: strong push (stronger in the
## centre), staggers melee attackers, leaves a band of Cendres.
class SouffleDeRecul extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.22
		a.recovery_time = 0.25
		a.max_range = 3.5
		a.anim = &"breath"

	func cast(t: Tk) -> void:
		t.fx("wave", t.origin + t.dir * 1.5, 2.0, Color(1.0, 0.5, 0.15))
		for e: CombatCharacter in t.enemies_in_cone(t.origin, t.dir, 3.5, 75.0):
			var to: Vector3 = HitQuery.flat(e.global_position - t.origin)
			var central: bool = t.dir.angle_to(to) < deg_to_rad(18.0)
			var melee_attacker: bool = e.abilities.is_casting() and e.abilities.current != null \
				and e.abilities.current.kind == AbilityData.Kind.MELEE_ARC
			var opts: Dictionary = {"push": 5.5 if central else 3.5}
			if melee_attacker:
				opts["stun"] = 0.45
			t.hit(e, t.dmg(0.4), opts)
		K.ashes(t, t.origin + t.dir * 2.2, 1.8, 5.0)


## C — Zone, Piège, Contrôle. Ring of Cendres: the first enemy crossing its
## edge gets a Braise and a slow; an Ignition inside makes the edge flare.
class AnneauDeCendres extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.2
		a.max_range = 9.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var cross := func(e: CombatCharacter, ring: KitObject) -> void:
			if t.is_enemy(e) and not ring.data.get("triggered", false):
				ring.data["triggered"] = true
				K.braise(t, e)
				t.status(e, StatusController.Type.SLOW, 1.5)
				t.fx("ember", e.global_position, 1.0)
		var ring: KitObject = t.zone(t.aim, 3.5, 7.0, {"kind": "anneau", "look": KitObject.Look.RING, "targetable": false,
			"color": Color(1.0, 0.45, 0.15), "on_enter": cross, "on_exit": cross})
		ring.data["triggered"] = false
		K.ashes(t, t.aim, 3.5, 7.0)


## C — Projectile chargé, Burst, Recast. Heavy lobbed fireball; recast in
## flight splits it into three fragments. The full ball consumes 2+ Braises
## for a vertical explosion that launches.
class CometeIncendiaire extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.45
		a.cast_move_multiplier = 0.3
		a.max_range = 11.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var ball: TkProjectile = t.projectile({"lob_to": t.aim, "speed": 13.0, "size": 0.45,
			"on_end": func(point: Vector3, p: TkProjectile, reason: String) -> void:
				if reason == "recast":
					return
				t.fx("explosion", point, 2.0)
				for e: CombatCharacter in t.area(point, 2.0, t.dmg(0.9)):
					if t.marks(e, BRAISE) >= 2:
						K.ignite(t, e, 0.3)
						t.launch(e, 1.0)
				t.zone(point, 1.8, 3.0, {"kind": "brulante", "tick_interval": 0.5, "targetable": false,
					"color": Color(1.0, 0.35, 0.1), "on_tick": func(o: KitObject) -> void:
						for e: CombatCharacter in o.enemies_inside():
							t.hit(e, t.dmg(0.12))})})
		t.recast(1.5, func(rt: Tk) -> void:
			if not is_instance_valid(ball) or not ball.is_alive():
				return
			var at: Vector3 = ball.ground_point()
			ball.end("recast")
			for i in 3:
				var d: Vector3 = rt.dir.rotated(Vector3.UP, deg_to_rad(-25.0 + 25.0 * i))
				rt.projectile({"from": at, "dir": d, "speed": 20.0, "range": 7.0, "size": 0.2,
					"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
						rt.hit(e, rt.dmg(0.4))
						return false}))


## B — Dôme, Contrôle, Anti-heal. A destructible core opens into a porous
## heat dome: every crossing applies a Braise and a slow; Braises inside
## don't fade; an Ignition of 3 Braises inside pulls everyone back in once.
class PrisonThermique extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.25
		a.max_range = 9.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		t.object(t.aim, {"kind": "noyau", "radius": 0.6, "lifetime": 0.9, "health": 25.0, "look": KitObject.Look.ORB,
			"color": Color(1.0, 0.4, 0.1), "on_expire": func(core: KitObject) -> void:
				_open_dome(t.refreshed(), core.global_position)})

	func _open_dome(t: Tk, at: Vector3) -> void:
		var crossing := func(e: CombatCharacter, _o: KitObject) -> void:
			if t.is_enemy(e):
				K.braise(t, e)
				t.status(e, StatusController.Type.SLOW, 0.8)
		t.fx("spheres", at, 4.0, Color(1.0, 0.5, 0.15))
		t.zone(at, 4.0, 6.0, {"kind": "dome", "look": KitObject.Look.RING, "targetable": false, "tick_interval": 0.5,
			"color": Color(1.0, 0.55, 0.2), "on_enter": crossing, "on_exit": crossing,
			"on_tick": func(o: KitObject) -> void:
				for e: CombatCharacter in o.enemies_inside():
					if e.kit.marks.has(BRAISE):
						e.kit.marks[BRAISE].left = maxf(e.kit.marks[BRAISE].left, 2.0)  # Braises don't fade inside
					t.debuff(e, "chaleur", 0.6, {"label": "Chaleur", "color": Color(1.0, 0.5, 0.2)})})


## B — Skillshot, Perforation, Anti-armure. Thin piercing line; extra damage
## to shields; bursts one Braise (without consuming the others) into a short
## Fracture thermique (+25 % damage taken).
class LanceDeVerre extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.3
		a.recovery_time = 0.35
		a.cast_move_multiplier = 0.0
		a.recovery_move_multiplier = 0.0
		a.max_range = 13.0
		a.anim = &"throw"

	func cast(t: Tk) -> void:
		for e: CombatCharacter in t.enemies_in_line(t.origin, t.dir, 13.0, 0.5):
			var dmg: float = t.dmg(1.0) * (1.5 if e.health.shield > 0.0 else 1.0)
			if t.marks(e, BRAISE) > 0:
				e.kit.add_mark(BRAISE, -1, 0.0, 3, t.caster)
				if t.marks(e, BRAISE) <= 0:
					e.kit.consume_mark(BRAISE)
				t.debuff(e, "fracture_thermique", 2.0, {"damage_taken": 1.25, "label": "Fracture", "color": Color(1.0, 0.7, 0.3)})
				t.text(e, "FRACTURE")
			t.hit(e, dmg)
		t.line(13.0, 0.5, 0.0)
		t.zone(t.clear_point(t.origin, t.dir, 13.0), 0.8, 4.0, {"kind": "vitrifie", "color": Color(0.7, 0.9, 1.0), "targetable": false})


## A — Terrain, Propagation, Zoning. Ignites a point; the fire slowly spreads
## to nearby Cendres. Standing in it stacks Braises. Recast once: stop the
## spread and blow up the current edge.
class MerDeFlammes extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.35
		a.max_range = 10.0
		a.anim = &"breath"

	func cast(t: Tk) -> void:
		_flame(t, t.aim)
		t.recast(7.0, func(rt: Tk) -> void:
			for f: KitObject in rt.objects("flamme"):
				rt.fx("explosion", f.global_position, f.radius)
				rt.area(f.global_position, f.radius + 0.5, rt.dmg(0.7))
				f.destroy("detonated"))

	func _flame(t: Tk, at: Vector3) -> void:
		t.fx("column", at, 1.0, Color(1.0, 0.4, 0.1))
		t.zone(at, 2.3, 7.0, {"kind": "flamme", "tick_interval": 0.5, "targetable": false, "color": Color(1.0, 0.35, 0.05),
			"on_tick": func(o: KitObject) -> void:
				for e: CombatCharacter in o.enemies_inside():
					t.hit(e, t.dmg(0.1))
					if int(o.age * 2.0) % 2 == 0:
						K.braise(t, e)
				# Slow spread: each second, light the Cendres within reach.
				if o.age - float(o.data.get("spread_at", 0.0)) >= 1.0:
					o.data["spread_at"] = o.age
					for ash: KitObject in t.objects("cendres", &""):
						if ash.is_alive() and t.distance(ash.global_position, o.global_position) <= 4.5:
							var where: Vector3 = ash.global_position
							ash.destroy("ignited")
							_flame(t, where)})


## A — Multi-projectile, Recast, Pression. Three fire birds, each bounces
## once (wall or target). After the first bounce, recast redirects every
## bird to the aim. Birds carry ground Braises they fly through.
class PhenixARebond extends Technique:
	var _last_hit: Dictionary = {}

	func configure(a: AbilityData) -> void:
		a.startup_time = 0.2
		a.max_range = 12.0
		a.anim = &"throw"

	func cast(t: Tk) -> void:
		for i in 3:
			t.after(0.15 * i, func(rt: Tk) -> void:
				_bird(rt, rt.origin, t.dir.rotated(Vector3.UP, deg_to_rad(-8.0 + 8.0 * i)), true))

	func _bird(t: Tk, from: Vector3, d: Vector3, can_bounce: bool) -> void:
		t.projectile({"from": from, "dir": d, "speed": 19.0, "range": 12.0, "size": 0.22, "data": {"bird": true},
			"on_tick": func(p: TkProjectile, _dt: float) -> void:
				for b: KitObject in t.objects("braise_sol", &""):
					if b.is_alive() and t.distance(b.global_position, p.global_position) < 1.0:
						p.data["carry"] = true
						b.destroy("carried"),
			"on_hit": func(e: CombatCharacter, p: TkProjectile) -> bool:
				# Damage spacing: two birds can't burst the same target at once.
				var now: float = Time.get_ticks_msec() / 1000.0
				var key: int = e.get_instance_id()
				var mult: float = 0.3 if now - float(_last_hit.get(key, -10.0)) < 0.25 else 0.6
				_last_hit[key] = now
				t.hit(e, t.dmg(mult))
				if p.data.get("carry", false):
					K.braise(t, e)
				if can_bounce:
					var other: CombatCharacter = t.nearest_enemy(e.global_position, 7.0)
					var nd: Vector3 = -p.direction if other == null or other == e else HitQuery.flat(other.global_position - e.global_position).normalized()
					_bounced(t, p.ground_point(), nd)
				return false,
			"on_end": func(point: Vector3, p: TkProjectile, reason: String) -> void:
				if reason == "wall" and can_bounce:
					_bounced(t, point - p.direction * 0.4, -p.direction)})

	func _bounced(t: Tk, at: Vector3, d: Vector3) -> void:
		_bird(t, at, d, false)
		if not t.kit().has_recast(t.id):
			t.recast(2.0, func(rt: Tk) -> void:
				for node: Node in rt.tree().get_nodes_in_group(&"tk_projectiles"):
					var p := node as TkProjectile
					if p != null and p.is_alive() and p.caster == rt.caster and p.data.get("bird", false):
						p.direction = HitQuery.flat(rt.aim - p.global_position).normalized()
						p.travelled = 0.0)


## S — Finisher, Détonation globale, Risque. Channels, then ignites every
## Braise of the caster in a wide area: marked enemies, ground Braises,
## Cendres. 3 Braises on a target = vertical eruption (launch). Interrupted =
## nothing consumed.
class FournaiseSolaire extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.15
		a.max_range = 14.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		t.fx("ring", t.origin, 14.0, Color(1.0, 0.8, 0.3))
		t.channel(3, 0.4, func(ct: Tk, _i: int) -> void:
			ct.fx("ember", ct.caster.global_position, 1.0),
			func(dt: Tk, completed: bool) -> void:
				if completed:
					_detonate(dt))

	func _detonate(t: Tk) -> void:
		t.fx("explosion", t.origin, 3.0, Color(1.0, 0.85, 0.4))
		for e: CombatCharacter in t.enemies_in(t.origin, 14.0):
			var n: int = t.marks(e, BRAISE)
			if n <= 0:
				continue
			K.ignite(t, e, 0.55)
			if n >= 3:
				t.fx("column", e.global_position, 1.5, Color(1.0, 0.5, 0.1))
				t.hit(e, t.dmg(0.5))
				t.launch(e, 1.0)
				e.abilities.interrupt()
		for kind: String in ["braise_sol", "cendres", "flamme"]:
			for o: KitObject in t.objects(kind, &""):
				if t.distance(o.global_position, t.origin) <= 14.0:
					t.fx("explosion", o.global_position, 1.5)
					t.area(o.global_position, 2.0, t.dmg(0.45))
					o.destroy("ignited")


## S — Invocation dirigée, Absorption, Recast. A fire dragon steered with the
## cursor: contact damage, swallows small projectiles (Gueule ardente gauge).
## Recast: it dives, the explosion grows with the gauge. Caster slowed.
class DragonDeFeuDevorant extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.4
		a.max_range = 30.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		t.buff("dragon_controle", 5.0, {"speed": 0.55, "label": "Dragon", "color": Color(1.0, 0.45, 0.1)})
		var dragon: TkProjectile = t.projectile({"speed": 9.0, "range": 45.0, "radius": 1.0, "pierce": true, "size": 0.6,
			"data": {"gauge": 0},
			"on_tick": func(p: TkProjectile, dt: float) -> void:
				if p.age > 5.0:
					p.end("range")
					return
				var want: Vector3 = HitQuery.flat(t.caster.facing.aim_point - p.global_position)
				if want.length() > 0.5:
					var angle: float = p.direction.signed_angle_to(want.normalized(), Vector3.UP)
					p.direction = p.direction.rotated(Vector3.UP, clampf(angle, -2.5 * dt, 2.5 * dt))
				_swallow(t, p),
			"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
				t.hit(e, t.dmg(0.5))
				return true,
			"on_end": func(point: Vector3, p: TkProjectile, reason: String) -> void:
				t.kit().remove_modifier("dragon_controle")
				t.kit().close_recast(t.id)
				var gauge: int = int(p.data.get("gauge", 0))
				var radius: float = (2.2 + 0.5 * gauge) if reason == "recast" else 1.5
				t.fx("explosion", point, radius)
				t.area(point, radius, t.dmg((1.0 + 0.25 * gauge) if reason == "recast" else 0.4))})
		t.recast(5.0, func(_rt: Tk) -> void:
			if dragon.is_alive():
				dragon.end("recast"))

	func _swallow(t: Tk, p: TkProjectile) -> void:
		for node: Node in t.tree().get_nodes_in_group(&"projectiles"):
			var enemy_p := node as Projectile
			if enemy_p != null and enemy_p.team != t.caster.team and t.distance(enemy_p.global_position, p.global_position) < 1.4:
				enemy_p.queue_free()
				p.data["gauge"] = int(p.data.gauge) + 1
		for node: Node in t.tree().get_nodes_in_group(&"tk_projectiles"):
			var other := node as TkProjectile
			if other != null and other != p and other.team != t.caster.team and other.is_alive() \
					and t.distance(other.global_position, p.global_position) < 1.4:
				other.end("blocked")
				p.data["gauge"] = int(p.data.gauge) + 1
		for b: KitObject in t.objects("braise_sol", &""):
			if b.is_alive() and t.distance(b.global_position, p.global_position) < 1.2:
				b.destroy("swallowed")
				p.data["gauge"] = int(p.data.gauge) + 1
