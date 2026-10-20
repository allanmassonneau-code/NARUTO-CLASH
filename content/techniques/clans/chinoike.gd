extends RefCounted
## Technique kit: clan Chinoike (design bible, Ame). Signature: Dette de sang
## — enemies carry up to 3 Gouttes de dette ("goutte" mark). Gouttes come
## from the techniques, from Chinoike hits on a bleeding target, and from
## the debt of whoever wounds the Chinoike (ChinoikeSignature). Techniques
## consume them for control or links. Hémorragie = a short purgeable bleed
## (BURN status + "hemorragie" label that ends with it). Blood variants cost
## the caster a little HP, never lethal (health.drain keeps 1 HP).

const KIT_ID := &"clan_chinoike"
const SIGNATURE = ChinoikeSignature
const TECHNIQUES := {
	&"clan_chinoike_d_aiguille_carmine": AiguilleCarmine,
	&"clan_chinoike_c_miroir_hematique": MiroirHematique,
	&"clan_chinoike_b_marionnette_ecarlate": MarionnetteEcarlate,
	&"clan_chinoike_a_ketsuryugan_regard_de_coagulation": Ketsuryugan,
	&"clan_chinoike_s_palais_de_sang": PalaisDeSang,
}

const GOUTTE := "goutte"
const GOUTTE_TIME: float = 9.0
const HEMORRAGIE := "hemorragie"
const BLOOD := Color(0.75, 0.05, 0.1)


## Blood debt: hitting a bleeding target with a Chinoike technique adds a
## Goutte (1.5 s per target); an enemy who deals a real blow to the Chinoike
## owes a Goutte (2.5 s per attacker). HUD mirror: strongest debt held.
class ChinoikeSignature extends KitSignature:
	var _cd: Dictionary = {}

	func setup(f: CombatCharacter) -> void:
		f.kit.define_resource(GOUTTE, 3.0, "Dette", BLOOD)

	func tick(f: CombatCharacter, dt: float) -> void:
		for key: int in _cd.keys():
			_cd[key] = float(_cd[key]) - dt
			if float(_cd[key]) <= 0.0:
				_cd.erase(key)
		var best: int = 0
		for node: Node in f.get_tree().get_nodes_in_group(&"fighters"):
			var e := node as CombatCharacter
			if e != null and e.team != f.team and not e.is_dead() and e.kit.mark_source(GOUTTE) == f:
				best = maxi(best, e.kit.mark(GOUTTE))
		var cur: float = f.kit.res(GOUTTE)
		if absf(cur - float(best)) > 0.01:
			f.kit.add_res(GOUTTE, float(best) - cur)

	func on_deal(f: CombatCharacter, target: CombatCharacter, hit: HitData, damage: float) -> Variant:
		if damage <= 0.0 or hit.ability == null or not String(hit.ability.source_id).begins_with("clan_chinoike"):
			return null
		if target.kit.has_modifier(HEMORRAGIE) and not _cd.has(target.get_instance_id()):
			_cd[target.get_instance_id()] = 1.5
			target.kit.add_mark(GOUTTE, 1, GOUTTE_TIME, 3, f, "Goutte", BLOOD)
		return null

	func on_take(f: CombatCharacter, hit: HitData, damage: float) -> Variant:
		var src: CombatCharacter = hit.source
		if damage >= 6.0 and src != null and is_instance_valid(src) and src != f and src.team != f.team \
				and not src.is_dead() and not _cd.has(-src.get_instance_id()):
			_cd[-src.get_instance_id()] = 2.5
			src.kit.add_mark(GOUTTE, 1, GOUTTE_TIME, 3, f, "Goutte", BLOOD)
		return null


## Shared Chinoike rules.
class K:
	static func goutte(t: Tk, e: CombatCharacter, n: int = 1) -> int:
		return t.mark(e, GOUTTE, n, GOUTTE_TIME, 3, "Goutte")

	static func spend_goutte(t: Tk, e: CombatCharacter, n: int = 1) -> int:
		var have: int = t.marks(e, GOUTTE)
		var spent: int = mini(have, n)
		if spent <= 0:
			return 0
		if spent >= have:
			e.kit.consume_mark(GOUTTE)
		else:
			e.kit.add_mark(GOUTTE, -spent, 0.0, 3, t.caster)
		return spent

	## Hémorragie: purgeable bleed (cleanse removes BURN, the label follows).
	static func bleed(t: Tk, e: CombatCharacter, seconds: float) -> void:
		if not t.is_enemy(e):
			return
		e.status.apply_status(StatusController.Type.BURN, seconds)
		t.debuff(e, HEMORRAGIE, seconds, {"label": "Hémorragie", "color": BLOOD,
			"on_tick": func(_dt: float) -> void:
				if is_instance_valid(e) and not e.status.has_status(StatusController.Type.BURN):
					e.kit.remove_modifier(HEMORRAGIE)})

	## Blood price paid by the caster (fraction of max HP, never lethal).
	static func blood_cost(t: Tk, fraction: float) -> void:
		t.caster.health.drain(t.caster.health.max_health * fraction)
		t.fx("spikes", t.caster.global_position, 0.5, BLOOD)

	static func has_los(t: Tk, a: Vector3, b: Vector3) -> bool:
		var up: Vector3 = Vector3.UP * HitQuery.BODY_HEIGHT
		return HitQuery.raycast_world(t.caster.get_world_3d(), HitQuery.flat(a) + up, HitQuery.flat(b) + up).is_empty()

	## Enemy with at least `need` Gouttes closest to the aim, within `reach`.
	static func indebted(t: Tk, reach: float, need: int) -> CombatCharacter:
		var best: CombatCharacter = null
		for e: CombatCharacter in t.enemies_in(t.origin, reach):
			if t.marks(e, GOUTTE) >= need and (best == null \
					or t.distance(e.global_position, t.aim) < t.distance(best.global_position, t.aim)):
				best = e
		return best


## D — Projectile, Hémorragie, Ressource. Fast thin blood needle: light
## damage, short Hémorragie, 1 Goutte. "Hold" variant = re-press while it
## flies (0.45 s): pays 4 % max HP and the needle pierces a second target.
class AiguilleCarmine extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.12
		a.recovery_time = 0.18
		a.max_range = 14.0
		a.anim = &"throw"

	func cast(t: Tk) -> void:
		var needle: TkProjectile = t.projectile({"speed": 30.0, "range": 14.0, "radius": 0.3, "size": 0.12,
			"color": BLOOD, "data": {"pierce_left": 0},
			"on_hit": func(e: CombatCharacter, p: TkProjectile) -> bool:
				t.hit(e, t.dmg(0.4))
				K.bleed(t, e, 2.5)
				K.goutte(t, e)
				if int(p.data.pierce_left) > 0:
					p.data["pierce_left"] = int(p.data.pierce_left) - 1
					return true
				return false})
		t.recast(0.45, func(rt: Tk) -> void:
			if not is_instance_valid(needle) or not needle.is_alive():
				return
			K.blood_cost(rt, 0.04)
			needle.data["pierce_left"] = 1
			needle.speed *= 1.2
			needle.size = 0.18)


## C — Clone réactif, Contre, Information. Directional, destructible blood
## plate in front (4 s). The first direct attack from the front (projectile
## or facing melee / dash; AOE and attacks from behind are ignored) imprints
## the attacker's silhouette; recast (3 s) makes the silhouette surge as a
## phantom dash back along the attack line: 1 Goutte if it crosses the author.
class MiroirHematique extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.15
		a.recovery_time = 0.2
		a.max_range = 4.0
		a.anim = &"guard"

	func cast(t: Tk) -> void:
		var center: Vector3 = t.origin + t.dir * 1.6
		var mirror: KitObject = t.wall(center, t.dir, 2.4, 4.0, {"kind": "miroir", "health": 30.0, "thickness": 0.4,
			"blocks_movement": false, "blocks_projectiles": true, "color": BLOOD, "tick_interval": 0.05})
		mirror.data["author"] = null
		mirror.on_projectile = func(team: int, point: Vector3) -> bool:
			if not mirror.is_alive():
				return false
			var author: CombatCharacter = null
			for e: CombatCharacter in t.fighters():
				if e.team == team and _in_front(mirror, e.global_position) \
						and (author == null or t.distance(e.global_position, point) < t.distance(author.global_position, point)):
					author = e
			if author == null:
				return false  # from behind: the plate ignores it
			_imprint(t, mirror, author)
			mirror.damage(5.0)
			return true
		mirror.on_tick = func(o: KitObject) -> void:
			if o.data.author != null or not t.alive():
				return
			for e: CombatCharacter in t.enemies_in(o.global_position, 4.0):
				if not _in_front(o, e.global_position) or not e.abilities.is_casting() or e.abilities.current == null:
					continue
				if e.abilities.current.kind == AbilityData.Kind.GROUND_AREA:
					continue
				var to_mirror: Vector3 = HitQuery.flat(o.global_position - e.global_position)
				if HitQuery.flat(e.facing.facing_direction).angle_to(to_mirror) < deg_to_rad(45.0):
					_imprint(t, o, e)
					return

	func _in_front(mirror: KitObject, p: Vector3) -> bool:
		return HitQuery.flat(p - mirror.global_position).dot(mirror.facing) > 0.2

	func _imprint(t: Tk, mirror: KitObject, author: CombatCharacter) -> void:
		if mirror.data.author != null:
			return
		mirror.data["author"] = author
		var info: Dictionary = {"author": author, "from": HitQuery.flat(author.global_position),
			"start": HitQuery.flat(mirror.global_position), "facing": mirror.facing}
		t.text(author, "EMPREINTE", BLOOD)
		t.object(mirror.global_position, {"kind": "silhouette", "radius": 0.6, "lifetime": 3.0,
			"look": KitObject.Look.DECOY, "targetable": false, "color": BLOOD})
		t.recast(3.0, func(rt: Tk) -> void:
			_phantom(rt, info))

	## The silhouette surges back along the attack line (reproduces its
	## initial movement, no damage copy).
	func _phantom(t: Tk, info: Dictionary) -> void:
		var author: CombatCharacter = info.author
		if author == null or not is_instance_valid(author):
			return
		var start: Vector3 = info.start
		var to: Vector3 = HitQuery.flat(Vector3(info.from) - start)
		if to.length() < 0.3:
			to = Vector3(info.facing) * 3.0
		for s: KitObject in t.objects("silhouette"):
			s.destroy("surged")
		t.fx("smoke", start, 0.8, BLOOD)
		t.projectile({"from": start - to.normalized() * 0.5, "dir": to.normalized(), "speed": 24.0,
			"range": to.length() + 2.0, "radius": 0.6, "pierce": true, "size": 0.35, "color": BLOOD,
			"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
				if e == author:
					K.goutte(t, e)
					t.text(e, "DETTE", BLOOD)
				return true})


## B — Tether, Mouvement forcé conditionnel, Ressource. On a target with 2+
## Gouttes: blood thread (4.5 s, 9 m). Each sharp change of direction of the
## caster's run tugs the target 1.3 m the same way (the target keeps acting,
## dashes break the range). Recast: consume the 3rd Goutte for one strong
## yank, then the link breaks. Without a valid target: a blood lash (1 Goutte).
class MarionnetteEcarlate extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.2
		a.recovery_time = 0.2
		a.max_range = 9.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var target: CombatCharacter = K.indebted(t, 9.0, 2)
		if target == null:
			var e: CombatCharacter = t.target_at_aim(2.5)
			if e == null:
				e = t.nearest_enemy(t.origin, 6.0)
			if e != null:
				t.fx("bolt", e.global_position, 0.6, BLOOD)
				t.hit(e, t.dmg(0.3))
				K.goutte(t, e)
			return
		t.fx("spikes", target.global_position, 0.8, BLOOD)
		var st: Dictionary = {"prev": Vector3.ZERO, "last": -1.0}
		var link: KitObject = t.tether(target, 9.0, 4.5, {"interval": 0.1,
			"on_tick": func(o: KitObject) -> void:
				if not t.is_enemy(target):
					return
				var v: Vector3 = HitQuery.flat(t.caster.velocity)
				if v.length() < 2.5:
					return
				var d: Vector3 = v.normalized()
				var prev: Vector3 = st.prev
				st.prev = d
				if prev != Vector3.ZERO and prev.angle_to(d) > deg_to_rad(50.0) and o.age - float(st.last) > 0.5:
					st.last = o.age
					t.push(target, d, 1.3, 0.15)
					t.fx("dust", target.global_position, 0.6, BLOOD)})
		link.data["target"] = target
		t.recast(4.5, func(rt: Tk) -> void:
			_yank(rt, link, target))

	func _yank(t: Tk, link: KitObject, target: CombatCharacter) -> void:
		if not is_instance_valid(link) or not link.is_alive() or not t.is_enemy(target):
			return
		if t.marks(target, GOUTTE) < 3:
			t.text(t.caster, "2 GOUTTES", BLOOD)
			var left: float = link.lifetime - link.age
			if left > 0.1:
				t.recast(left, func(rt: Tk) -> void: _yank(rt, link, target))
			return
		K.spend_goutte(t, target)
		var v: Vector3 = HitQuery.flat(t.caster.velocity)
		var d: Vector3 = v.normalized() if v.length() > 1.0 else t.dir
		t.push(target, d, 4.0, 0.25)
		t.status(target, StatusController.Type.SLOW, 1.0)
		t.fx("wave", target.global_position, 1.0, BLOOD)
		link.destroy("released")


## A — Focus, Debuff adaptatif, Vision. Channels a gaze (3 × 0.3 s, broken by
## line of sight or range). Completed: Gouttes become Coagulation (8 s): each
## chakra spend of the target leaves a visible red trace and stacks a chakra
## regen slow. With 3 Gouttes consumed, its next big jutsu (25+ chakra)
## opens a weak point (1.5 s): if the Chinoike hits the target meanwhile,
## its chakra recovery stops for 4 s (the cast already started goes on).
class Ketsuryugan extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.15
		a.recovery_time = 0.15
		a.max_range = 13.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var target: CombatCharacter = t.target_at_aim(3.0)
		if target == null:
			target = t.nearest_enemy(t.origin, 13.0)
		if target == null:
			return
		t.text(target, "REGARD", BLOOD)
		var gaze: Dictionary = {"broken": false}
		t.channel(3, 0.3, func(ct: Tk, _i: int) -> void:
			if gaze.broken:
				return
			if not ct.is_enemy(target) or ct.distance(ct.origin, target.global_position) > 15.0 \
					or not K.has_los(ct, ct.origin, target.global_position):
				gaze.broken = true
				ct.text(ct.caster, "ROMPU", BLOOD)
				return
			ct.caster.facing.set_direction(HitQuery.flat(target.global_position - ct.origin).normalized())
			ct.fx("ring", target.global_position, 0.7, BLOOD),
			func(dt: Tk, completed: bool) -> void:
				if completed and not gaze.broken and dt.is_enemy(target) \
						and K.has_los(dt, dt.origin, target.global_position):
					_coagulate(dt, target), 0.5)

	func _coagulate(t: Tk, e: CombatCharacter) -> void:
		var n: int = t.consume_mark(e, GOUTTE)
		var st: Dictionary = {"energy": e.energy.current_energy, "stacks": n, "armed": n >= 3, "was": e.abilities.is_casting()}
		t.fx("implosion", e.global_position, 1.0, BLOOD)
		t.text(e, "COAGULATION", BLOOD)
		_regen_slow(t, e, st, 8.0)
		t.debuff(e, "coagulation", 8.0, {"label": "Coagulation", "color": BLOOD,
			"on_tick": func(_dt: float) -> void:
				if not is_instance_valid(e) or e.is_dead() or not t.alive():
					return
				var now: float = e.energy.current_energy
				if now < float(st.energy) - 1.0:
					st.stacks = mini(int(st.stacks) + 1, 6)
					t.zone(e.global_position, 0.7, 3.0, {"kind": "trace_rouge", "color": BLOOD, "targetable": false})
					_regen_slow(t, e, st, e.kit.modifier_left("coagulation"))
				st.energy = now
				var casting: bool = e.abilities.is_casting()
				if casting and not st.was and st.armed and e.abilities.current != null \
						and e.abilities.current.energy_cost >= 25.0:
					st.armed = false
					_weak_point(t, e)
				st.was = casting,
			"on_take": func(hit: HitData, _dmg: float) -> void:
				if hit.source == t.caster and is_instance_valid(e):
					for wp: KitObject in t.objects("point_faible"):
						if wp.data.get("target") == e:
							wp.destroy("struck")
							t.debuff(e, "hemostase", 4.0, {"chakra_regen": 0.0, "label": "Hémostase", "color": BLOOD})
							t.text(e, "HÉMOSTASE", BLOOD)})

	func _regen_slow(t: Tk, e: CombatCharacter, st: Dictionary, seconds: float) -> void:
		if seconds <= 0.0:
			return
		var mult: float = maxf(0.4, 1.0 - 0.1 * float(st.stacks))
		t.debuff(e, "coagulation_regen", seconds, {"chakra_regen": mult})

	func _weak_point(t: Tk, e: CombatCharacter) -> void:
		t.text(e, "POINT FAIBLE", BLOOD)
		t.object(e.global_position, {"kind": "point_faible", "radius": 0.5, "lifetime": 1.5, "look": KitObject.Look.ORB,
			"targetable": false, "color": BLOOD, "data": {"target": e},
			"on_tick": func(o: KitObject) -> void:
				if is_instance_valid(e) and not e.is_dead():
					o.global_position = HitQuery.flat(e.global_position)})


## S — Domaine, Ressource partagée, Finisher. Large domain (10 s). Anyone who
## loses 8 % max HP inside leaves a neutral Flaque de sang. While the
## Chinoike stands inside, Flaques drift toward his cursor (onto himself or a
## marked target). Recast (caster inside): every Flaque bursts into spikes
## toward nearby enemies — damage scales with the number of distinct angles
## covering a target, one capped hit per target (+ Gouttes consumed).
class PalaisDeSang extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.4
		a.recovery_time = 0.3
		a.max_range = 8.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		t.fx("spikes", t.origin, 8.0, BLOOD)
		var hp: Dictionary = {}
		var domain: KitObject = t.zone(t.origin, 8.5, 10.0, {"kind": "palais", "look": KitObject.Look.RING,
			"targetable": false, "color": BLOOD, "tick_interval": 0.1,
			"on_tick": func(o: KitObject) -> void:
				_tick_domain(t, o, hp)})
		t.recast(10.0, func(rt: Tk) -> void:
			_burst(rt, domain))

	func _tick_domain(t: Tk, o: KitObject, hp: Dictionary) -> void:
		if not t.alive():
			return
		for f: CombatCharacter in o.inside:
			if not is_instance_valid(f) or f.is_dead():
				continue
			var key: int = f.get_instance_id()
			var cur: float = f.health.current_health
			var base: float = float(hp.get(key, cur))
			if cur > base:
				base = cur
			if base - cur >= f.health.max_health * 0.08:
				base = cur
				t.object(f.global_position, {"kind": "flaque", "radius": 0.8, "lifetime": 12.0, "targetable": false,
					"look": KitObject.Look.DISC, "color": Color(0.5, 0.02, 0.05)})
			hp[key] = base
		if o.contains(t.caster.global_position):
			var cursor: Vector3 = HitQuery.flat(t.caster.facing.aim_point)
			for fl: KitObject in t.objects("flaque"):
				var to: Vector3 = HitQuery.flat(cursor - fl.global_position)
				if to.length() > 0.2:
					var nxt: Vector3 = fl.global_position + to.normalized() * minf(to.length(), 0.25)
					if o.contains(nxt):
						fl.global_position = nxt

	func _burst(t: Tk, domain: KitObject) -> void:
		if not is_instance_valid(domain) or not domain.is_alive():
			return
		if not domain.contains(t.caster.global_position):
			t.text(t.caster, "HORS DU PALAIS", BLOOD)
			var left: float = domain.lifetime - domain.age
			if left > 0.1:
				t.recast(left, func(rt: Tk) -> void: _burst(rt, domain))
			return
		var pools: Array[Vector3] = []
		for fl: KitObject in t.objects("flaque"):
			if domain.contains(fl.global_position) or t.distance(fl.global_position, t.origin) < 4.0:
				pools.append(HitQuery.flat(fl.global_position))
				t.fx("spikes", fl.global_position, 1.0, BLOOD)
				fl.destroy("burst")
		if pools.is_empty():
			return
		for e: CombatCharacter in t.enemies_in(domain.global_position, domain.radius + 1.0):
			var sectors: Dictionary = {}
			for p: Vector3 in pools:
				var to: Vector3 = HitQuery.flat(p - e.global_position)
				if to.length() > 5.5:
					continue
				if to.length() < 0.6:
					sectors[-1] = true  # from below
				else:
					sectors[int(floor((atan2(to.z, to.x) + PI) / (PI / 4.0))) % 8] = true
			var n: int = mini(sectors.size(), 4)
			if n <= 0:
				continue
			var g: int = t.consume_mark(e, GOUTTE)
			var opts: Dictionary = {"root": 0.5} if n >= 3 else {}
			t.hit(e, t.dmg(0.3 + 0.3 * float(n) + 0.1 * float(g)), opts)
			t.fx("spikes", e.global_position, 0.6 + 0.2 * n, BLOOD)
