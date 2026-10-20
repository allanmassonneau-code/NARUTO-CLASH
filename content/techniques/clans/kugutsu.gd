extends RefCounted
## Technique kit: clan Kugutsu (design bible). Signature: Marionnette — a
## real second body (KitObject kind "marionnette", Look.DECOY, 70 HP,
## permanent) summoned automatically by the first technique and kept until
## destroyed. Its wires have a max range (14 m): beyond it the puppet is
## partially recalled. Commands are issued by the player but take the puppet
## as origin (K.command, reproduced by Cent fils copies). A destroyed puppet
## imposes an 8 s rebuild delay ("reconstruction" modifier).

const KIT_ID := &"clan_kugutsu"
const SIGNATURE = null
const TECHNIQUES := {
	&"clan_kugutsu_d_karakuri_premier_fil": KarakuriPremierFil,
	&"clan_kugutsu_c_croisement_des_fils": CroisementDesFils,
	&"clan_kugutsu_b_arsenal_dissimule": ArsenalDissimule,
	&"clan_kugutsu_a_substitution_mecanique": SubstitutionMecanique,
	&"clan_kugutsu_s_cent_fils_atelier_de_guerre": CentFilsAtelierDeGuerre,
}

const PUPPET := "marionnette"
const COPY := "copie"
const WIRE: float = 14.0
const REBUILD: float = 8.0
const MARKED := "fil_marque"
const WOOD := Color(0.62, 0.45, 0.3)
const THREAD := Color(0.75, 0.85, 1.0)


## Shared Kugutsu rules: the puppet, its wires and Commands.
class K:
	static func puppet(t: Tk) -> KitObject:
		var all: Array[KitObject] = t.objects(PUPPET, &"")
		return all[0] if not all.is_empty() else null

	static func valid(o: Variant) -> bool:
		return is_instance_valid(o) and (o as KitObject).is_alive()

	## Live KitObject from an instance id (callbacks never capture objects
	## that may be freed before them).
	static func by_id(id: int) -> KitObject:
		var o := instance_from_id(id) as KitObject
		return o if o != null and o.is_alive() else null

	## The puppet, summoned toward `near` (<= 5 m) if absent; null while
	## it is being rebuilt.
	static func ensure(t: Tk, near: Vector3) -> KitObject:
		var p: KitObject = puppet(t)
		if p != null:
			return p
		if t.kit().has_modifier("reconstruction"):
			t.text(t.caster, "RECONSTRUCTION")
			return null
		var to: Vector3 = HitQuery.flat(near - t.origin)
		var d: Vector3 = to.normalized() if to.length() > 0.1 else t.dir
		return spawn(t, t.clear_point(t.origin, d, clampf(to.length(), 1.5, 5.0)))

	static func spawn(t: Tk, at: Vector3) -> KitObject:
		var line: MeshInstance3D = KitVisuals.line_visual(t.caster.get_parent(), THREAD) if CombatFx.is_enabled() else null
		var line_id: int = line.get_instance_id() if line != null else 0
		t.fx("smoke", at, 0.9, WOOD)
		return t.object(at, {"kind": PUPPET, "radius": 0.7, "lifetime": 0.0, "health": 70.0, "look": KitObject.Look.DECOY,
			"color": WOOD, "data": {"goal": HitQuery.flat(at), "speed": 9.0, "locked": false},
			"on_tick": func(o: KitObject) -> void:
				_tick(t, o, instance_from_id(line_id) as MeshInstance3D if line_id != 0 else null),
			"on_destroy": func(_o: KitObject, reason: String) -> void:
				var l := instance_from_id(line_id) as Node if line_id != 0 else null
				if l != null:
					l.queue_free()
				if reason == "destroyed" and t.alive():
					t.kit().add_modifier("reconstruction", REBUILD, {"label": "Marionnette détruite", "color": WOOD})})

	static func _tick(t: Tk, o: KitObject, line: MeshInstance3D) -> void:
		if not is_instance_valid(t.caster) or t.caster.is_dead():
			return
		var master: Vector3 = HitQuery.flat(t.caster.global_position)
		# Wire range: beyond it the puppet is dragged back (partial recall).
		if t.distance(o.global_position, master) > WIRE and not bool(o.data.locked):
			var back: Vector3 = HitQuery.flat(o.global_position - master).normalized()
			o.data.goal = master + back * (WIRE - 3.0)
			o.data.speed = 12.0
		var goal: Vector3 = o.data.goal
		var to: Vector3 = HitQuery.flat(goal - o.global_position)
		if to.length() > 0.05 and not bool(o.data.locked):
			var step: float = minf(float(o.data.speed) * o.get_physics_process_delta_time(), to.length())
			var from: Vector3 = o.global_position + Vector3.UP * 0.6
			if HitQuery.raycast_world(t.caster.get_world_3d(), from, from + to.normalized() * (step + 0.3)).is_empty():
				o.global_position = HitQuery.flat(o.global_position + to.normalized() * step)
			else:
				o.data.goal = HitQuery.flat(o.global_position)  # obstacle: the body stops
		if line != null and is_instance_valid(line):
			KitVisuals.update_line(line, master, o.global_position)

	static func move(p: KitObject, to: Vector3, speed: float = 9.0) -> void:
		p.data.goal = HitQuery.flat(to)
		p.data.speed = speed

	## A Command: `order.call(t, from, dir, body)` from the puppet toward the
	## aim, then reproduced by each Cent fils copy with a slight delay from
	## its own angle (each copy dies after two reproductions).
	static func command(t: Tk, order: Callable) -> bool:
		var p: KitObject = puppet(t)
		if p == null:
			return false
		var target: Vector3 = t.aim
		order.call(t, p.global_position, aim_dir(t, p.global_position, target), p)
		var i: int = 0
		for c: KitObject in t.objects(COPY, &""):
			i += 1
			var cid: int = c.get_instance_id()
			t.after(0.15 * i, func(rt: Tk) -> void:
				var copy: KitObject = by_id(cid)
				if copy == null:
					return
				order.call(rt, copy.global_position, aim_dir(rt, copy.global_position, target), copy)
				copy.data.uses = int(copy.data.uses) - 1
				if int(copy.data.uses) <= 0:
					copy.destroy("used"))
		return true

	static func aim_dir(t: Tk, from: Vector3, target: Vector3) -> Vector3:
		var to: Vector3 = HitQuery.flat(target - from)
		return to.normalized() if to.length() > 0.5 else t.dir

	## Command hit: a target marked by the mechanical substitution takes
	## +50 % and is briefly rooted (mark consumed).
	static func command_hit(t: Tk, e: CombatCharacter, damage: float, opts: Dictionary = {}) -> HitData.Result:
		var o: Dictionary = opts.duplicate()
		if t.consume_mark(e, MARKED) > 0:
			damage *= 1.5
			o["root"] = 0.4
			t.text(e, "FIL")
		return t.hit(e, damage, o)

	## Basic telegraphed strike from a body along `d`.
	static func strike(t: Tk, from: Vector3, d: Vector3, body: KitObject) -> void:
		t.fx("ring", from + d * 1.5, 0.8, WOOD)
		var bid: int = body.get_instance_id()
		t.after(0.25, func(st: Tk) -> void:
			if by_id(bid) == null:
				return
			st.fx("wave", from + d * 2.0, 1.2, WOOD)
			for e: CombatCharacter in st.enemies_in_line(from, d, 3.5, 1.2):
				command_hit(st, e, st.dmg(0.6), {"push": 1.5, "push_from": from}))

	static func seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
		var ab: Vector3 = HitQuery.flat(b - a)
		var ap: Vector3 = HitQuery.flat(p - a)
		var k: float = clampf(ap.dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		return (ap - ab * k).length()


## D — Summon, Commande, Double origine. Deploys the puppet at a nearby
## point (or re-places it). Then for 8 s, up to 3 recast Commands: a
## telegraphed strike along the aim from the puppet; aiming at yourself
## (< 2 m) recalls it instead ("hold" approximated). Over-range wires
## auto-recall partially.
class KarakuriPremierFil extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.2
		a.recovery_time = 0.2
		a.cast_move_multiplier = 0.3
		a.max_range = 8.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var dist: float = clampf(t.distance(t.aim, t.origin) - 1.2, 1.5, 6.0)
		var spot: Vector3 = t.clear_point(t.origin, t.dir, dist)
		var p: KitObject = K.puppet(t)
		if p == null:
			p = K.ensure(t, spot)
		else:
			K.move(p, spot, 12.0)
		if p == null:
			return
		var state := {"left": 3, "end": Time.get_ticks_msec() / 1000.0 + 8.0}
		t.recast(8.0, _order.bind(state))

	func _order(t: Tk, state: Dictionary) -> void:
		var p: KitObject = K.puppet(t)
		if p == null:
			return
		if t.distance(t.aim, t.origin) < 2.0:
			K.move(p, t.origin - t.dir * 1.2, 14.0)
			t.fx("ring", p.global_position, 0.8, THREAD)
		else:
			K.command(t, K.strike)
		state.left = int(state.left) - 1
		var left: float = float(state.end) - Time.get_ticks_msec() / 1000.0
		if int(state.left) > 0 and left > 0.1:
			t.recast(left, _order.bind(state))


## C — Swap, Trap de ligne, Mobilité. A wire is stretched between master and
## puppet for 3 s: enemies crossing it take light damage, are slowed and
## Révélé (+10 % damage taken). Recast: both bodies slide toward each other
## (85 % of the gap, nearly swapping); if an obstacle blocks either body,
## both stop at the shorter clear distance.
class CroisementDesFils extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.15
		a.recovery_time = 0.2
		a.max_range = WIRE
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var p: KitObject = K.ensure(t, t.origin + t.dir * 4.0)
		if p == null:
			return
		var pid: int = p.get_instance_id()
		var line: MeshInstance3D = KitVisuals.line_visual(t.caster.get_parent(), THREAD) if CombatFx.is_enabled() else null
		t.object(t.origin, {"kind": "fil_croise", "radius": 0.1, "lifetime": 3.0, "look": KitObject.Look.NONE, "targetable": false,
			"data": {"crossed": {}, "line": line},
			"on_tick": func(o: KitObject) -> void:
				var pup: KitObject = K.by_id(pid)
				if pup == null or not t.alive():
					o.destroy("broken")
					return
				var a: Vector3 = HitQuery.flat(t.caster.global_position)
				var b: Vector3 = pup.global_position
				o.global_position = a
				var ln: Variant = o.data.get("line")
				if ln != null and is_instance_valid(ln):
					KitVisuals.update_line(ln as MeshInstance3D, a, b)
				for e: CombatCharacter in t.enemies_in((a + b) * 0.5, t.distance(a, b) * 0.5 + 1.0):
					var key: int = e.get_instance_id()
					if o.data.crossed.has(key) or K.seg_dist(e.global_position, a, b) > 0.6:
						continue
					o.data.crossed[key] = true
					t.hit(e, t.dmg(0.3), {"slow": 1.5})
					t.debuff(e, "revele", 3.0, {"damage_taken": 1.1, "label": "Révélé", "color": THREAD}),
			"on_destroy": func(o: KitObject, _r: String) -> void:
				var ln: Variant = o.data.get("line")
				if ln != null and is_instance_valid(ln):
					(ln as Node).queue_free()})
		t.recast(3.0, func(rt: Tk) -> void:
			_slide(rt))

	func _slide(t: Tk) -> void:
		var p: KitObject = K.puppet(t)
		if p == null:
			return
		var a: Vector3 = t.origin
		var b: Vector3 = p.global_position
		var gap: float = t.distance(a, b)
		if gap < 1.0:
			return
		var d: Vector3 = HitQuery.flat(b - a).normalized()
		var want: float = gap * 0.85
		var free_m: float = t.distance(a, t.clear_point(a, d, want + 0.6)) - 0.6
		var free_p: float = t.distance(b, t.clear_point(b, -d, want + 0.6)) - 0.6
		var travel: float = clampf(minf(want, minf(free_m, free_p) + 0.6), 0.0, want)
		if travel < want - 0.3:
			t.text(t.caster, "BLOQUÉ")
		if travel < 0.3:
			return
		t.dash(travel, d, 0.25)
		K.move(p, b - d * travel, travel / 0.25)


## B — Mode marionnette, Choix d'arme, Recast. The puppet visibly opens its
## compartments; the recast (5 s) fires ONE weapon, chosen by where you aim
## relative to the puppet: < 3 m = local toxic smoke (zoning), 3-7 m =
## senbon cone (poke), > 7 m = narrow grappling cable (pulls the first enemy
## to the puppet, or hauls the puppet to the anchor point). Destroying the
## puppet cancels the arsenal. Issued as a Command (copies repeat it).
class ArsenalDissimule extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.35
		a.recovery_time = 0.2
		a.max_range = 16.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var p: KitObject = K.ensure(t, t.aim)
		if p == null:
			return
		p.data["arsenal"] = true
		var pid: int = p.get_instance_id()
		t.fx("ring", p.global_position, 1.2, WOOD)
		t.text(t.caster, "ARSENAL")
		t.recast(5.0, func(rt: Tk) -> void:
			_choose(rt), func() -> void:
				var pup: KitObject = K.by_id(pid)
				if pup != null:
					pup.data["arsenal"] = false)

	func _choose(t: Tk) -> void:
		var p: KitObject = K.puppet(t)
		if p == null or not bool(p.data.get("arsenal", false)):
			t.text(t.caster, "ARSENAL ANNULÉ")
			return
		p.data["arsenal"] = false
		var dist: float = t.distance(t.aim, p.global_position)
		if dist < 3.0:
			K.command(t, _smoke)
		elif dist <= 7.0:
			K.command(t, _senbon)
		else:
			K.command(t, _grapple)

	func _senbon(t: Tk, from: Vector3, d: Vector3, _body: KitObject) -> void:
		t.fx("spikes", from + d * 2.5, 2.0, WOOD)
		for e: CombatCharacter in t.enemies_in_cone(from, d, 6.0, 50.0):
			K.command_hit(t, e, t.dmg(0.55))

	func _grapple(t: Tk, from: Vector3, d: Vector3, body: KitObject) -> void:
		var best: CombatCharacter = null
		var best_d: float = 99.0
		for e: CombatCharacter in t.enemies_in_line(from, d, 11.0, 0.8):
			var along: float = HitQuery.flat(e.global_position - from).dot(d)
			if along < best_d:
				best = e
				best_d = along
		if best != null:
			t.fx("bolt", best.global_position, 0.6, THREAD)
			if K.command_hit(t, best, t.dmg(0.4)) == HitData.Result.HIT:
				t.pull(best, from, 4.0)
		elif K.valid(body):
			K.move(body, t.clear_point(from, d, 11.0), 22.0)

	func _smoke(t: Tk, from: Vector3, _d: Vector3, _body: KitObject) -> void:
		t.fx("smoke", from, 2.5, Color(0.5, 0.75, 0.35))
		for e: CombatCharacter in t.enemies_in(from, 2.5):
			K.command_hit(t, e, t.dmg(0.2))
		t.zone(from, 2.5, 4.0, {"kind": "fumee_toxique", "targetable": false, "tick_interval": 0.5, "color": Color(0.5, 0.75, 0.35),
			"on_tick": func(o: KitObject) -> void:
				for e: CombatCharacter in o.enemies_inside():
					t.hit(e, t.dmg(0.1), {"slow": 0.6})})


## A — Body swap, Faux corps, Piège. Locks the puppet in place for 4 s. The
## swap is never automatic: recast right after taking a direct hit (0.7 s)
## or just before one (0.4 s, the hit is then negated) to trade places with
## the puppet (fails if it is too far, behind a wall or destroyed). The body
## left behind becomes an explosive mannequin: telegraphed 0.8 s, mostly
## knockback, and marks targets for the next Command (+50 %, root).
class SubstitutionMecanique extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.15
		a.recovery_time = 0.15
		a.max_range = WIRE
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var p: KitObject = K.ensure(t, t.origin - t.dir * 4.0)
		if p == null:
			return
		p.data.locked = true
		var pid: int = p.get_instance_id()
		t.fx("ring", p.global_position, 1.0, THREAD)
		var state := {"clock": 0.0, "hit_at": -10.0, "armed_until": -10.0, "done": false}
		var kit: KitState = t.kit()
		t.buff("sub_verrou", 4.0, {"label": "Substitution prête", "color": THREAD,
			"on_tick": func(dt: float) -> void:
				state.clock = float(state.clock) + dt,
			"on_take": func(hit: HitData, _dmg: float) -> Variant:
				if bool(state.done) or not is_instance_valid(hit.source):
					return null
				state.hit_at = state.clock
				if float(state.clock) <= float(state.armed_until):
					kit.after(0.0, func() -> void:
						if t.alive():
							_swap(t.refreshed(), state))
					return 0.0
				return null,
			"on_end": func() -> void:
				var pup: KitObject = K.by_id(pid)
				if pup != null:
					pup.data.locked = false})
		t.recast(4.0, _confirm.bind(state))

	func _confirm(t: Tk, state: Dictionary) -> void:
		if bool(state.done) or not t.kit().has_modifier("sub_verrou"):
			return
		if float(state.clock) - float(state.hit_at) <= 0.7:
			_swap(t, state)
			return
		state.armed_until = float(state.clock) + 0.4
		var left: float = t.kit().modifier_left("sub_verrou")
		if left > 0.1:
			t.recast(left, _confirm.bind(state))

	func _swap(t: Tk, state: Dictionary) -> void:
		if bool(state.done):
			return
		state.done = true
		t.kit().close_recast(t.id)
		var p: KitObject = K.puppet(t)
		var up: Vector3 = Vector3.UP * HitQuery.BODY_HEIGHT
		if p == null or t.distance(p.global_position, t.origin) > WIRE \
				or not HitQuery.raycast_world(t.caster.get_world_3d(), t.origin + up, p.global_position + up).is_empty():
			t.text(t.caster, "ÉCHEC")
			t.kit().remove_modifier("sub_verrou")
			return
		var old: Vector3 = t.origin
		var there: Vector3 = p.global_position
		t.kit().remove_modifier("sub_verrou")
		t.cleanse(t.caster, true)
		t.blink(there)
		t.status(t.caster, StatusController.Type.IMMATERIAL, 0.3)
		p.global_position = HitQuery.flat(old - t.dir * 0.8)
		K.move(p, p.global_position)
		t.fx("ring", old, 2.8, Color(1.0, 0.5, 0.3))
		t.object(old, {"kind": "mannequin", "radius": 0.6, "lifetime": 0.8, "health": 20.0, "look": KitObject.Look.DECOY,
			"color": Color(0.9, 0.55, 0.35),
			"on_expire": func(o: KitObject) -> void:
				_explode(t.refreshed(), o.global_position)})

	func _explode(t: Tk, at: Vector3) -> void:
		t.fx("explosion", at, 2.8, Color(1.0, 0.5, 0.3))
		for e: CombatCharacter in t.area(at, 2.8, t.dmg(0.3), {"push": 3.5}):
			t.mark(e, MARKED, 1, 6.0, 1, "Fil marqué")


## S — Multi-puppet, Commandes de zone, Gestion. Deploys two 1-HP minor
## puppets at different angles around the main one (they follow it). Every
## Command (Karakuri strike, Arsenal weapon, this recast) is reproduced by
## each copy with a slight delay from its own angle; a copy vanishes after
## two reproductions. Recast (repeatable while copies live): a Commande de
## zone — every body strikes toward the aim.
class CentFilsAtelierDeGuerre extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.4
		a.recovery_time = 0.25
		a.max_range = 12.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var p: KitObject = K.ensure(t, t.origin + t.dir * 3.0)
		if p == null:
			return
		for old: KitObject in t.objects(COPY, &""):
			old.destroy("replaced")
		var base: Vector3 = K.aim_dir(t, p.global_position, t.aim)
		var pid: int = p.get_instance_id()
		for side: float in [-1.0, 1.0]:
			var offset: Vector3 = base.rotated(Vector3.UP, deg_to_rad(110.0 * side)) * 3.0
			t.fx("smoke", p.global_position + offset, 0.7, WOOD)
			t.object(p.global_position + offset, {"kind": COPY, "radius": 0.5, "lifetime": 14.0, "health": 1.0,
				"look": KitObject.Look.DECOY, "color": WOOD.lightened(0.3), "data": {"uses": 2},
				"on_tick": func(o: KitObject) -> void:
					var pup: KitObject = K.by_id(pid)
					if pup == null:
						o.destroy("puppet_lost")
						return
					o.global_position = HitQuery.flat(pup.global_position + offset)})
		t.recast(14.0, _zone_command)

	func _zone_command(t: Tk) -> void:
		K.command(t, K.strike)
		if not t.objects(COPY, &"").is_empty():
			t.recast(10.0, _zone_command)
