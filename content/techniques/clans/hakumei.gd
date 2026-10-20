extends RefCounted
## Technique kit: clan Hakumei (design bible, Suna). Signature: Doute — an
## enemy carries up to 3 Doute charges ("doute" mark, fades after a long
## time out of combat). They are earned when the target reacts to an
## illusion (silhouettes, fake kunai, copies) and spent to make illusions
## more convincing or to strike from outside its vision cone. Hitting the
## real Hakumei wipes the attacker's Doute (HakumeiSignature.on_take).

const KIT_ID := &"clan_hakumei"
const SIGNATURE = HakumeiSignature
const TECHNIQUES := {
	&"clan_hakumei_d_pas_dedouble": PasDedouble,
	&"clan_hakumei_c_kunai_du_reflet": KunaiDuReflet,
	&"clan_hakumei_b_marque_du_doute": MarqueDuDoute,
	&"clan_hakumei_a_assassinat_de_l_angle_mort": AssassinatAngleMort,
	&"clan_hakumei_s_theatre_des_morts_blancs": TheatreDesMortsBlancs,
}

const DOUTE := "doute"
const DOUTE_TIME: float = 10.0
const MARQUE := "marque_doute"
const PALE := Color(0.85, 0.88, 0.95)
## Half-angle of a fighter's vision cone (top-down approximation of the camera).
const VISION_HALF_DEG: float = 60.0


## Doute bookkeeping: HUD mirror of the strongest Doute held by an enemy, and
## loss of the charges when the target lands a hit on the real Hakumei.
class HakumeiSignature extends KitSignature:
	func setup(f: CombatCharacter) -> void:
		f.kit.define_resource(DOUTE, 3.0, "Doute", PALE)

	func tick(f: CombatCharacter, _dt: float) -> void:
		var best: int = 0
		for node: Node in f.get_tree().get_nodes_in_group(&"fighters"):
			var e := node as CombatCharacter
			if e != null and e.team != f.team and not e.is_dead() and e.kit.mark_source(DOUTE) == f:
				best = maxi(best, e.kit.mark(DOUTE))
		var cur: float = f.kit.res(DOUTE)
		if absf(cur - float(best)) > 0.01:
			f.kit.add_res(DOUTE, float(best) - cur)

	func on_take(f: CombatCharacter, hit: HitData, damage: float) -> Variant:
		var src: CombatCharacter = hit.source
		if damage > 0.0 and src != null and is_instance_valid(src) and src != f and src.team != f.team \
				and src.kit.mark(DOUTE) > 0:
			src.kit.consume_mark(DOUTE)  # struck the real one: the doubt is gone
		return null


## Shared Hakumei rules.
class K:
	static func doute(t: Tk, e: CombatCharacter, n: int = 1) -> int:
		if not t.is_enemy(e):
			return 0
		t.text(e, "DOUTE", PALE)
		return t.mark(e, DOUTE, n, DOUTE_TIME, 3, "Doute")

	## Removes `n` Doute charges; returns how many were actually spent.
	static func spend_doute(t: Tk, e: CombatCharacter, n: int = 1) -> int:
		var have: int = t.marks(e, DOUTE)
		var spent: int = mini(have, n)
		if spent <= 0:
			return 0
		if spent >= have:
			e.kit.consume_mark(DOUTE)
		else:
			e.kit.add_mark(DOUTE, -spent, 0.0, 3, t.caster)
		return spent

	## True if `point` is inside `viewer`'s vision cone.
	static func sees(viewer: CombatCharacter, point: Vector3, half_deg: float = VISION_HALF_DEG) -> bool:
		var to: Vector3 = HitQuery.flat(point - viewer.global_position)
		if to.length() < 0.4:
			return true
		return HitQuery.flat(viewer.facing.facing_direction).angle_to(to) <= deg_to_rad(half_deg)

	static func is_marked(t: Tk, e: CombatCharacter) -> bool:
		return t.marks(e, DOUTE) > 0 or (e != null and is_instance_valid(e) and e.kit.has_modifier(MARQUE))

	## Enemy carrying Doute (or the Marque) closest to the aim, within `reach` of the caster.
	static func doubting_target(t: Tk, reach: float) -> CombatCharacter:
		var best: CombatCharacter = null
		var best_d: float = INF
		for e: CombatCharacter in t.enemies_in(t.origin, reach):
			if is_marked(t, e):
				var d: float = t.distance(e.global_position, t.aim)
				if d < best_d:
					best = e
					best_d = d
		return best

	## Illusory silhouette: no collision, vanishes at the first impact
	## (any hit or projectile). Moves with `velocity`.
	static func silhouette(t: Tk, at: Vector3, velocity: Vector3, life: float, kind: String = "silhouette") -> KitObject:
		var o: KitObject = t.object(at, {"kind": kind, "radius": 0.6, "lifetime": life, "health": 1.0,
			"look": KitObject.Look.DECOY, "color": PALE, "data": {"vel": velocity},
			"on_tick": func(s: KitObject) -> void:
				var v: Vector3 = s.data.get("vel", Vector3.ZERO)
				if v != Vector3.ZERO:
					s.global_position += v * s.get_physics_process_delta_time()})
		o.on_projectile = func(_team: int, _point: Vector3) -> bool:
			if o.is_alive():
				o.destroy("impact")
			return false
		return o


## D — Dash, Afterimage, Setup. Short dash (sidestep when it would follow the
## current run); a collisionless silhouette keeps running the old direction
## for 1 s. If the nearest enemy tracks or attacks it (or hits it), 1 Doute.
class PasDedouble extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.05
		a.recovery_time = 0.12
		a.max_range = 6.0
		a.anim = &"dash"

	func cast(t: Tk) -> void:
		var vel: Vector3 = HitQuery.flat(t.caster.velocity)
		var old: Vector3 = vel.normalized() if vel.length() > 1.0 else t.dir
		var dash_dir: Vector3 = t.dir
		if dash_dir.angle_to(old) < deg_to_rad(30.0):
			var side: Vector3 = old.cross(Vector3.UP).normalized()
			if t.distance(t.clear_point(t.origin, side, 4.5), t.origin) < 2.5:
				side = -side
			dash_dir = side
		var watcher: CombatCharacter = t.nearest_enemy(t.origin, 14.0)
		var ghost: KitObject = K.silhouette(t, t.origin, old * 7.0, 1.0, "silhouette")
		ghost.data["fooled"] = false
		var fool := func(e: CombatCharacter) -> void:
			if not ghost.data.get("fooled", false) and t.is_enemy(e):
				ghost.data["fooled"] = true
				K.doute(t, e)
		var user_tick: Callable = ghost.on_tick
		ghost.tick_interval = 0.0
		ghost.on_tick = func(s: KitObject) -> void:
			user_tick.call(s)
			if not t.is_enemy(watcher) or not t.alive():
				return
			var face: Vector3 = HitQuery.flat(watcher.facing.facing_direction)
			var to_ghost: Vector3 = HitQuery.flat(s.global_position - watcher.global_position)
			var to_real: Vector3 = HitQuery.flat(t.caster.global_position - watcher.global_position)
			if to_ghost.length() < 0.3:
				return
			var a_ghost: float = face.angle_to(to_ghost)
			var a_real: float = face.angle_to(to_real)
			var tracking: bool = a_ghost < deg_to_rad(15.0) and a_real - a_ghost > deg_to_rad(15.0)
			var attacking: bool = watcher.abilities.is_casting() and a_ghost < deg_to_rad(30.0) and a_real > a_ghost
			if tracking or attacking:
				fool.call(watcher)
		ghost.on_destroy = func(s: KitObject, reason: String) -> void:
			if (reason == "destroyed" or reason == "impact") and t.alive():
				fool.call(t.nearest_enemy(s.global_position, 6.0) if watcher == null else watcher)
		t.dash(4.5, dash_dir, 0.15)
		t.fx("smoke", t.origin, 0.7, PALE)


## C — Projectile multi-angle, Illusion, Recast. One real kunai from the hand
## and two illusory ones from offset positions; only the real one deals
## damage (bonus when it comes from outside the target's view). Recast (only
## if an enemy has Doute): spend 1 Doute to choose late which kunai is real
## (the one closest to the cursor), as long as none has hit yet.
class KunaiDuReflet extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.15
		a.recovery_time = 0.2
		a.max_range = 14.0
		a.anim = &"throw"

	func cast(t: Tk) -> void:
		var state: Dictionary = {"hit": false, "projs": []}
		var side: Vector3 = t.dir.cross(Vector3.UP).normalized()
		var focus: Vector3 = t.origin + t.dir * 14.0
		for i in 3:
			var from: Vector3 = t.origin + side * (1.3 * float(i - 1))
			var d: Vector3 = HitQuery.flat(focus - from).normalized()
			var p: TkProjectile = t.projectile({"from": from, "dir": d, "speed": 24.0, "range": 14.0, "radius": 0.45,
				"size": 0.15, "pierce": true, "data": {"real": i == 1, "from": from, "fooled": []},
				"on_hit": func(e: CombatCharacter, kp: TkProjectile) -> bool:
					if kp.data.get("real", false):
						if state.hit:
							return true
						state.hit = true
						var mult: float = 1.35 if not K.sees(e, kp.data.from) else 1.0
						t.hit(e, t.dmg(0.75 * mult))
						kp.end("hit")
						return false
					# Illusion: harmless, but guarding against it is a tell.
					if (e.guarding or e.abilities.is_casting()) and not (kp.data.fooled as Array).has(e):
						(kp.data.fooled as Array).append(e)
						K.doute(t, e)
					return true})
			(state.projs as Array).append(p)
		var doubter: CombatCharacter = null
		for e: CombatCharacter in t.enemies_in(t.origin, 16.0):
			if t.marks(e, DOUTE) > 0:
				doubter = e
		if doubter == null:
			return
		t.recast(1.2, func(rt: Tk) -> void:
			if state.hit:
				return
			var payer: CombatCharacter = null
			var best_d: float = INF
			for e: CombatCharacter in rt.enemies_in(rt.origin, 18.0):
				if rt.marks(e, DOUTE) > 0 and rt.distance(e.global_position, rt.aim) < best_d:
					payer = e
					best_d = rt.distance(e.global_position, rt.aim)
			if payer == null:
				return
			var chosen: TkProjectile = null
			var cd: float = INF
			for p: TkProjectile in state.projs:
				if is_instance_valid(p) and p.is_alive():
					var d: float = rt.distance(p.global_position, rt.aim)
					if d < cd:
						chosen = p
						cd = d
			if chosen == null:
				return
			K.spend_doute(rt, payer)
			for p: TkProjectile in state.projs:
				if is_instance_valid(p) and p.is_alive():
					p.data["real"] = p == chosen
			rt.fx("sparks", chosen.ground_point(), 0.6, PALE))


## B — Cible, Faux télégraphes, Pression. Marks a target that already has
## Doute (6 s, visible). Each time the Hakumei starts a cast, a harmless fake
## telegraph + silhouette appears from another angle around the target, each
## consuming 1 Doute. Marked targets are valid for Assassinat. Without a
## doubting target, the gaze only plants 1 Doute on the aimed enemy.
class MarqueDuDoute extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.2
		a.recovery_time = 0.2
		a.max_range = 11.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var e: CombatCharacter = K.doubting_target(t, 11.0)
		if e == null or t.marks(e, DOUTE) <= 0:
			var fallback: CombatCharacter = t.target_at_aim(3.0)
			if fallback == null:
				fallback = t.nearest_enemy(t.origin, 11.0)
			if fallback != null:
				t.fx("crows", fallback.global_position, 0.8, PALE)
				K.doute(t, fallback)
			return
		t.fx("ring", e.global_position, 1.2, PALE)
		t.text(e, "MARQUE", PALE)
		var st: Dictionary = {"was": t.caster.abilities.is_casting(), "side": 1.0}
		t.debuff(e, MARQUE, 6.0, {"label": "Marque du doute", "color": PALE,
			"on_tick": func(_dt: float) -> void:
				if not t.alive() or not t.is_enemy(e):
					return
				var casting: bool = t.caster.abilities.is_casting()
				if casting and not st.was and t.marks(e, DOUTE) > 0:
					st.side = -float(st.side)
					_fake_telegraph(t.refreshed(), e, float(st.side))
				st.was = casting})

	func _fake_telegraph(t: Tk, e: CombatCharacter, side: float) -> void:
		var to_caster: Vector3 = HitQuery.flat(t.caster.global_position - e.global_position)
		if to_caster.length() < 0.5:
			to_caster = -HitQuery.flat(e.facing.facing_direction)
		var dist: float = clampf(to_caster.length(), 3.0, 7.0)
		var from_dir: Vector3 = to_caster.normalized().rotated(Vector3.UP, deg_to_rad(105.0 * side))
		var at: Vector3 = HitQuery.flat(e.global_position) + from_dir * dist
		var radius: float = clampf(t.caster.abilities.current.max_range * 0.25, 1.5, 3.0) \
			if t.caster.abilities.current != null else 2.0
		# Plausible: same footprint as the spell really being cast, but never any damage.
		t.object(e.global_position, {"kind": "faux_telegraphe", "radius": radius, "lifetime": 0.6,
			"look": KitObject.Look.RING, "targetable": false, "color": t.color})
		K.silhouette(t, at, Vector3.ZERO, 0.6, "faux_lanceur")
		K.spend_doute(t, e)
		t.text(e, "?", PALE)


## A — Dash ciblé, Condition vision, Finisher. Locks a (preferably marked)
## target and opens a 3 s recast. The recast only fires while the Hakumei is
## really outside the target's vision cone (otherwise "VU", window kept):
## Doute consumed = +range and a silent dash (no telegraph); circles behind
## and strikes — back hits deal +60 % and stun briefly, frontal ones never.
class AssassinatAngleMort extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.2
		a.recovery_time = 0.2
		a.max_range = 10.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var target: CombatCharacter = K.doubting_target(t, 10.0)
		if target == null:
			target = t.target_at_aim(3.0)
		if target == null:
			target = t.nearest_enemy(t.origin, 8.0)
		if target == null:
			return
		var ring: KitObject = t.object(target.global_position, {"kind": "angle_mort", "radius": 2.2, "lifetime": 3.0,
			"look": KitObject.Look.RING, "targetable": false, "color": PALE,
			"on_tick": func(o: KitObject) -> void:
				if is_instance_valid(target) and not target.is_dead():
					o.global_position = HitQuery.flat(target.global_position)
				else:
					o.destroy("lost")})
		t.text(target, "CIBLE", PALE)
		_open(t, target, ring, 3.0)

	func _open(t: Tk, target: CombatCharacter, ring: KitObject, seconds: float) -> void:
		t.recast(seconds, func(rt: Tk) -> void:
			_try(rt, target, ring),
			func() -> void:
				if is_instance_valid(ring) and ring.is_alive():
					ring.destroy("expired"))

	func _try(t: Tk, target: CombatCharacter, ring: KitObject) -> void:
		if not t.is_enemy(target) or not is_instance_valid(ring) or not ring.is_alive():
			return
		var left: float = ring.lifetime - ring.age
		var n: int = t.marks(target, DOUTE)
		var reach: float = 6.0 + 1.2 * float(n)
		if K.sees(target, t.caster.global_position):
			t.text(t.caster, "VU", Color(1.0, 0.4, 0.4))
			if left > 0.1:
				_open(t, target, ring, left)
			return
		if t.distance(t.caster.global_position, target.global_position) > reach:
			t.text(t.caster, "TROP LOIN", Color(1.0, 0.7, 0.4))
			if left > 0.1:
				_open(t, target, ring, left)
			return
		n = t.consume_mark(target, DOUTE)
		ring.destroy("executed")
		if n <= 0:
			# Noisy dash: a puff of smoke betrays the destination for an instant.
			t.fx("smoke", HitQuery.flat(target.global_position - target.facing.facing_direction * 1.3), 0.8)
			t.after(0.15, func(at: Tk) -> void: _strike(at, target))
		else:
			_strike(t, target)

	func _strike(t: Tk, target: CombatCharacter) -> void:
		if not t.is_enemy(target):
			return
		var back: Vector3 = HitQuery.flat(target.global_position - HitQuery.flat(target.facing.facing_direction).normalized() * 1.3)
		t.fx("smoke", t.caster.global_position, 0.6, PALE)
		var landed: Vector3 = t.blink(back)
		var to_target: Vector3 = HitQuery.flat(target.global_position - landed)
		if to_target.length() > 0.05:
			t.caster.facing.set_direction(to_target.normalized())
		var in_back: bool = not K.sees(target, landed, 90.0)
		t.fx("bolt", target.global_position, 0.8, PALE)
		if in_back:
			t.text(target, "ANGLE MORT", PALE)
			t.hit(target, t.dmg(0.95 * 1.6), {"stun": 0.4})
		else:
			t.hit(target, t.dmg(0.95))


## S — Domaine illusion, Information, Exécution. A pale veil (9 s) with three
## destructible copies replaying the Hakumei's movements with different
## delays and faking the start of his mudras (never impacts). Enemies who
## destroy a copy gain 1 Doute. Recast once: consume all Doute of the main
## target to swap places with the copy nearest the cursor; every copy then
## freezes 0.4 s, and the next hit is empowered.
class TheatreDesMortsBlancs extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.35
		a.recovery_time = 0.25
		a.max_range = 8.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var st: Dictionary = {"hist": [], "base": HitQuery.flat(t.caster.global_position), "freeze": 0.0,
			"was": true, "copies": [], "pulse": 0.0}
		var center: Vector3 = t.origin
		var delays: Array = [0.35, 0.7, 1.05]
		for i in 3:
			var off: Vector3 = t.dir.rotated(Vector3.UP, deg_to_rad(90.0 + 90.0 * i)) * 2.5
			var c: KitObject = t.object(t.clear_point(center, off.normalized(), 2.5), {"kind": "copie", "radius": 0.6,
				"lifetime": 9.0, "health": 12.0, "look": KitObject.Look.DECOY, "color": PALE,
				"data": {"delay": delays[i]},
				"on_destroy": func(o: KitObject, reason: String) -> void:
					if reason == "destroyed":
						var e: CombatCharacter = t.nearest_enemy(o.global_position, 4.0)
						if e != null:
							K.doute(t, e)})
			c.data["origin"] = HitQuery.flat(c.global_position)
			(st.copies as Array).append(c)
		t.fx("smoke", center, 7.5, PALE)
		var veil: KitObject = t.zone(center, 7.5, 9.0, {"kind": "voile", "color": PALE, "targetable": false,
			"on_tick": func(o: KitObject) -> void:
				_tick_theatre(t, o, st)})
		t.recast(9.0, func(rt: Tk) -> void:
			_swap(rt, veil, st))

	func _tick_theatre(t: Tk, veil: KitObject, st: Dictionary) -> void:
		if not t.alive():
			return
		var hist: Array = st.hist
		hist.append([veil.age, HitQuery.flat(t.caster.global_position)])
		while hist.size() > 2 and float(hist[1][0]) < veil.age - 1.5:
			hist.pop_front()
		# Enemies in the veil: readable "fog" debuff.
		if veil.age - float(st.pulse) >= 0.25:
			st.pulse = veil.age
			for e: CombatCharacter in veil.enemies_inside():
				t.debuff(e, "voile_pale", 0.4, {"label": "Voile pâle", "color": PALE})
		var casting: bool = t.caster.abilities.is_casting()
		var mudra: bool = casting and not st.was
		st.was = casting
		var frozen: bool = veil.age < float(st.freeze)
		for c: KitObject in st.copies:
			if not is_instance_valid(c) or not c.is_alive():
				continue
			var delay: float = float(c.data.delay)
			if not frozen:
				var sample: Vector3 = hist[0][1]
				for h: Array in hist:
					if float(h[0]) <= veil.age - delay:
						sample = h[1]
				c.global_position = c.data.origin + (sample - st.base)
			if mudra:
				t.after(delay, func(at: Tk) -> void:
					if is_instance_valid(c) and c.is_alive():
						at.fx("ring", c.global_position, 1.0, at.color))

	func _swap(t: Tk, veil: KitObject, st: Dictionary) -> void:
		if not is_instance_valid(veil) or not veil.is_alive():
			return
		var main: CombatCharacter = null
		for e: CombatCharacter in t.enemies_in(veil.global_position, veil.radius + 2.0):
			if main == null or t.marks(e, DOUTE) > t.marks(main, DOUTE):
				main = e
		var copy: KitObject = null
		for c: KitObject in st.copies:
			if is_instance_valid(c) and c.is_alive() and (copy == null \
					or t.distance(c.global_position, t.aim) < t.distance(copy.global_position, t.aim)):
				copy = c
		if main == null or t.marks(main, DOUTE) <= 0 or copy == null:
			t.text(t.caster, "AUCUN DOUTE", PALE)
			var left: float = veil.lifetime - veil.age
			if left > 0.1:
				t.recast(left, func(rt: Tk) -> void: _swap(rt, veil, st))
			return
		t.consume_mark(main, DOUTE)
		var old: Vector3 = HitQuery.flat(t.caster.global_position)
		var dest: Vector3 = HitQuery.flat(copy.global_position)
		t.blink(dest)
		var now: Vector3 = HitQuery.flat(t.caster.global_position)
		# Re-base every copy on its current spot; the swapped one takes the old place.
		st.hist = [[veil.age, now]]
		st.base = now
		for c: KitObject in st.copies:
			if is_instance_valid(c) and c.is_alive():
				if c == copy:
					c.global_position = old
				c.data["origin"] = HitQuery.flat(c.global_position)
		st.freeze = veil.age + 0.4
		t.fx("implosion", now, 1.2, PALE)
		t.buff("execution_blanche", 2.5, {"damage_dealt": 1.3, "uses": 1, "label": "Exécution", "color": PALE,
			"on_deal": func(_target: CombatCharacter, _hit: HitData, _d: float) -> void: pass})
