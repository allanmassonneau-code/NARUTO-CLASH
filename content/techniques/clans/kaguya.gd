extends RefCounted
## Technique kit: Clan Kaguya (design bible). Signature: Densité osseuse — a
## gauge (100) regenerating slowly. Big techniques spend it; detached bones
## stay on the ground as Éclats ("eclat" objects). Walking over an Éclat
## picks it up and restores Densité. Forêt de tessons recycles every Éclat
## into secondary spikes; Shikotsumyaku condenses the whole gauge into armor.

const KIT_ID := &"clan_kaguya"
const SIGNATURE = KaguyaSignature
const TECHNIQUES := {
	&"clan_kaguya_d_lame_phalangienne": LamePhalangienne,
	&"clan_kaguya_c_danse_des_cotes": DanseDesCotes,
	&"clan_kaguya_b_balles_digitales": BallesDigitales,
	&"clan_kaguya_a_foret_de_tessons": ForetDeTessons,
	&"clan_kaguya_s_shikotsumyaku_danse_du_dernier_squelette": Shikotsumyaku,
}

const DENSITE := "densite"
const DENSITE_MAX: float = 100.0
const DENSITE_REGEN: float = 3.0
const ECLAT := "eclat"
const ECLAT_LIFE: float = 14.0
const ECLAT_GAIN: float = 12.0
const SHIKOTSU := "shikotsumyaku"
const BONE := Color(0.95, 0.93, 0.85)


## Densité: slow regeneration (none while the bone armor is up) and Éclat
## pick-up when the Kaguya walks over one.
class KaguyaSignature extends KitSignature:
	func setup(f: CombatCharacter) -> void:
		f.kit.define_resource(DENSITE, DENSITE_MAX, "Densité", BONE)
		f.kit.add_res(DENSITE, DENSITE_MAX)

	func tick(f: CombatCharacter, delta: float) -> void:
		if not f.kit.has_modifier(SHIKOTSU) and f.kit.res(DENSITE) < DENSITE_MAX:
			f.kit.add_res(DENSITE, DENSITE_REGEN * delta)
		for o: KitObject in KitObject.find(f.get_tree(), f, &"", ECLAT):
			if HitQuery.flat(o.global_position - f.global_position).length() <= 1.1:
				f.kit.add_res(DENSITE, ECLAT_GAIN)
				o.destroy("picked")


## Shared Kaguya rules.
class K:
	static func eclat(t: Tk, at: Vector3) -> KitObject:
		return t.object(at, {"kind": ECLAT, "radius": 0.45, "lifetime": ECLAT_LIFE, "look": KitObject.Look.ORB,
			"targetable": false, "color": BONE})

	static func spend(t: Tk, amount: float) -> bool:
		return t.spend_res(DENSITE, amount)

	static func is_melee(hit: HitData, victim: CombatCharacter) -> bool:
		if hit == null or not is_instance_valid(hit.source) or hit.source == victim:
			return false
		if hit.ability != null and (hit.ability.kind == AbilityData.Kind.MELEE_ARC or hit.source.abilities.is_basic_attack(hit.ability)):
			return true
		return hit.ability != null and hit.ability.kind != AbilityData.Kind.PROJECTILE \
			and HitQuery.flat(hit.source.global_position - victim.global_position).length() <= 2.8


## D — Mêlée, Extension, Ressource. Quick bone-blade cut. Recast within
## 0.7 s ("hold"): the bone extends into a long thrust for 15 Densité, with a
## heavier recovery; if the thrust is guarded / countered the blade breaks
## and falls as an Éclat.
class LamePhalangienne extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.1
		a.active_time = 0.05
		a.recovery_time = 0.2
		a.max_range = 2.4
		a.anim = &"slash"

	func cast(t: Tk) -> void:
		t.melee(2.3, 100.0, t.dmg(0.7))
		t.recast(0.7, func(rt: Tk) -> void:
			if not K.spend(rt, 15.0):
				rt.text(rt.caster, "DENSITÉ")
				return
			rt.buff("lame_longue", 0.45, {"speed": 0.4})  # heavier recovery, readable arm
			rt.fx("spikes", rt.origin + rt.dir * 2.5, 1.0, BONE)
			for e: CombatCharacter in rt.enemies_in_line(rt.origin, rt.dir, 4.8, 0.9):
				var guarded: bool = e.guarding
				var r: HitData.Result = rt.hit(e, rt.dmg(0.85))
				if guarded or r == HitData.Result.COUNTERED:
					rt.text(e, "LAME BRISÉE")
					K.eclat(rt, e.global_position - rt.dir * 0.8)
					return
			rt.line(4.8, 0.9, 0.0))


## C — Parade corporelle, Pointes, Recast. Ribs burst out for 0.8 s: a melee
## hit taken is cushioned (-70 %) and the attacker is spiked and pushed.
## Recast without having blocked: two ribs fly forward, leaving Éclats where
## they land.
class DanseDesCotes extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.05
		a.active_time = 0.05
		a.recovery_time = 0.15
		a.max_range = 9.0
		a.anim = &"guard"

	func cast(t: Tk) -> void:
		var state := {"blocked": false}
		t.fx("spikes", t.origin, 1.2, BONE)
		t.buff("danse_cotes", 0.8, {"label": "Côtes", "color": BONE,
			"on_take": func(hit: HitData, dmg: float) -> Variant:
				if not K.is_melee(hit, t.caster):
					return null
				state["blocked"] = true
				var attacker: CombatCharacter = hit.source
				if t.is_enemy(attacker):
					t.after(0.0, func(rt: Tk) -> void:
						if rt.is_enemy(attacker):
							rt.fx("spikes", attacker.global_position, 0.8, BONE)
							rt.hit(attacker, rt.dmg(0.4), {"push": 3.0, "push_from": rt.caster.global_position})
						rt.kit().close_recast(rt.id))
				return dmg * 0.3})
		t.recast(2.0, func(rt: Tk) -> void:
			if state.blocked:
				return
			rt.kit().remove_modifier("danse_cotes")
			for i in 2:
				var d: Vector3 = rt.dir.rotated(Vector3.UP, deg_to_rad(-7.0 + 14.0 * i))
				rt.projectile({"dir": d, "speed": 22.0, "range": 9.0, "size": 0.2, "color": BONE,
					"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
						rt.hit(e, rt.dmg(0.45))
						return false,
					"on_end": func(point: Vector3, _p: TkProjectile, _reason: String) -> void:
						K.eclat(rt, point)}))


## B — Salve, Charges, Terrain. Four finger bullets over 0.75 s, each aimed
## at the current cursor (caster slowed). Bullets hitting the scenery (or
## dropping at max range) leave Éclats. Recast during the volley ("hold the
## last shot"): +20 Densité spent, the last bullet bursts into 3 fragments
## after a short flight (after the volley, recast fires that bullet at once).
class BallesDigitales extends Technique:
	const SHOTS: int = 4

	func configure(a: AbilityData) -> void:
		a.startup_time = 0.15
		a.active_time = 0.05
		a.recovery_time = 0.15
		a.max_range = 13.0
		a.anim = &"throw"

	func cast(t: Tk) -> void:
		var state := {"burst": false, "last_fired": false}
		t.buff("balles_digitales", 0.85, {"speed": 0.6})
		for i in SHOTS:
			t.after(0.25 * i, func(rt: Tk) -> void:
				if K.spend(rt, 4.0) or i == 0:
					var last: bool = i == SHOTS - 1
					if last:
						state["last_fired"] = true
					_bullet(rt, last and bool(state.burst)))
		t.recast(1.4, func(rt: Tk) -> void:
			if not K.spend(rt, 20.0):
				rt.text(rt.caster, "DENSITÉ")
				return
			if state.last_fired:
				_bullet(rt, true)
			else:
				state["burst"] = true)

	func _bullet(t: Tk, burst: bool) -> void:
		t.projectile({"speed": 26.0, "range": 13.0, "radius": 0.45, "size": 0.16 if not burst else 0.24,
			"color": BONE, "data": {"burst": burst},
			"on_tick": func(proj: TkProjectile, _dt: float) -> void:
				if proj.data.get("burst", false) and proj.age >= 0.3:
					var at: Vector3 = proj.ground_point()
					var d: Vector3 = proj.direction
					proj.end("recast")
					for k in 3:
						_fragment(t, at, d.rotated(Vector3.UP, deg_to_rad(-22.0 + 22.0 * k))),
			"on_hit": func(e: CombatCharacter, _proj: TkProjectile) -> bool:
				t.hit(e, t.dmg(0.45 if burst else 0.35))
				return false,
			"on_end": func(point: Vector3, _proj: TkProjectile, reason: String) -> void:
				if reason == "wall" or reason == "range":
					K.eclat(t, point)})

	func _fragment(t: Tk, at: Vector3, d: Vector3) -> void:
		t.projectile({"from": at, "dir": d, "speed": 22.0, "range": 6.0, "size": 0.12, "color": BONE,
			"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
				t.hit(e, t.dmg(0.3))
				return false,
			"on_end": func(point: Vector3, _p: TkProjectile, reason: String) -> void:
				if reason == "wall":
					K.eclat(t, point)})


## A — Terrain, Éruption, Recyclage. White cracks announce a line of bone
## spikes (30 Densité, shorter line without it). Then every Éclat within
## 15 m turns into a secondary spike shooting toward the main line (Éclats
## consumed); each target takes at most 3 secondary hits.
class ForetDeTessons extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.3
		a.active_time = 0.05
		a.recovery_time = 0.3
		a.max_range = 11.0
		a.anim = &"stomp"

	func cast(t: Tk) -> void:
		var length: float = 11.0 if K.spend(t, 30.0) else 7.0
		var from: Vector3 = t.origin + t.dir * 0.8
		var d: Vector3 = t.dir
		var end_point: Vector3 = t.clear_point(from, d, length)
		length = t.distance(from, end_point)
		var n: int = maxi(2, int(length / 1.8))
		for i in n:
			var at: Vector3 = from + d * (length * (float(i) + 0.5) / float(n))
			t.object(at, {"kind": "fissure", "radius": 0.9, "lifetime": 0.5, "look": KitObject.Look.RING,
				"targetable": false, "color": Color(1, 1, 1)})
			t.fx("cracks", at, 0.9, Color(1, 1, 1))
		t.after(0.5, func(rt: Tk) -> void:
			for i in n:
				rt.fx("spikes", from + d * (length * (float(i) + 0.5) / float(n)), 1.0, BONE)
			for e: CombatCharacter in rt.enemies_in_line(from, d, length, 1.6):
				rt.hit(e, rt.dmg(0.9), {"slow": 1.0})
			_secondary(rt, from, d, length))

	func _secondary(t: Tk, from: Vector3, d: Vector3, length: float) -> void:
		var hits: Dictionary = {}
		var shards: Array[KitObject] = t.objects(ECLAT, &"")
		for s: KitObject in shards:
			if t.distance(s.global_position, t.origin) > 15.0:
				continue
			var at: Vector3 = s.global_position
			s.destroy("recycled")
			t.fx("cracks", at, 0.6, Color(1, 1, 1))
			# Toward the closest point of the main line.
			var along: float = clampf((at - from).dot(d), 0.0, length)
			var to: Vector3 = HitQuery.flat(from + d * along - at)
			var dist: float = minf(to.length(), 6.0)
			var sd: Vector3 = to.normalized() if to.length() > 0.2 else d
			t.after(0.25, func(rt: Tk) -> void:
				rt.fx("spikes", at + sd * dist * 0.5, 0.7, BONE)
				for e: CombatCharacter in rt.enemies_in_line(at, sd, maxf(dist, 1.2), 0.9):
					var key: int = e.get_instance_id()
					if int(hits.get(key, 0)) >= 3:
						continue
					hits[key] = int(hits.get(key, 0)) + 1
					rt.hit(e, rt.dmg(0.3)))


## S — Transformation, Armure offensive, Finisher. Takes ALL Densité into an
## armor of 2..7 segments (10 s, no regen, basic attacks +25 %). Hits are
## 60 % absorbed; every 20 damage breaks a segment (falls as an Éclat).
## Recast = tear off a segment for a weapon chosen by the cursor distance:
## near = bouclier (shield), mid = fouet (whip cone + pull), far = lance
## (piercing throw). With a single segment left, recast = piercing charge
## that ends the mode.
class Shikotsumyaku extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.45
		a.active_time = 0.05
		a.max_range = 12.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var dens: float = t.take_all_res(DENSITE)
		var state := {"segments": clampi(2 + int(dens / 20.0), 2, 7), "acc": 0.0}
		t.fx("spikes", t.origin, 1.6, BONE)
		t.buff(SHIKOTSU, 10.0, {"basic_damage": 1.25, "label": _label(state), "color": BONE,
			"on_take": func(_hit: HitData, dmg: float) -> Variant:
				if int(state.segments) <= 0:
					return null
				state["acc"] = float(state.acc) + dmg
				while float(state.acc) >= 20.0 and int(state.segments) > 0:
					state["acc"] = float(state.acc) - 20.0
					_lose_segment(t, state)
					K.eclat(t, t.caster.global_position + Vector3(randf_range(-1.5, 1.5), 0.0, randf_range(-1.5, 1.5)))
				return dmg * 0.4,
			"on_end": func() -> void:
				state["segments"] = 0
				if is_instance_valid(t.caster):
					t.kit().close_recast(t.id)})
		_open(t, state)

	func _label(state: Dictionary) -> String:
		return "Squelette x%d" % int(state.segments)

	func _lose_segment(t: Tk, state: Dictionary) -> void:
		state["segments"] = int(state.segments) - 1
		if t.kit().modifiers.has(SHIKOTSU):
			t.kit().modifiers[SHIKOTSU].props["label"] = _label(state)
		if int(state.segments) <= 0:
			t.after(0.0, func(rt: Tk) -> void: rt.kit().remove_modifier(SHIKOTSU))

	func _open(t: Tk, state: Dictionary) -> void:
		var left: float = t.kit().modifier_left(SHIKOTSU)
		if left <= 0.05 or int(state.segments) <= 0:
			return
		t.recast(left, func(rt: Tk) -> void:
			if not rt.kit().has_modifier(SHIKOTSU) or int(state.segments) <= 0:
				return
			if int(state.segments) == 1:
				_charge(rt)
				return
			_weapon(rt, state)
			_open(rt, state))

	func _weapon(t: Tk, state: Dictionary) -> void:
		_lose_segment(t, state)
		var reach: float = t.distance(t.origin, t.aim)
		if reach < 2.5:
			t.text(t.caster, "BOUCLIER")
			t.fx("spheres", t.origin, 1.2, BONE)
			t.shield(t.caster, t.dmg(0.9), 3.0)
		elif reach < 6.0:
			t.text(t.caster, "FOUET")
			for e: CombatCharacter in t.cone(5.0, 70.0, t.dmg(0.6)):
				t.pull(e, t.origin, 2.5)
		else:
			t.text(t.caster, "LANCE")
			t.projectile({"speed": 30.0, "range": 13.0, "pierce": true, "size": 0.25, "color": BONE,
				"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
					t.hit(e, t.dmg(0.8))
					return true,
				"on_end": func(point: Vector3, _p: TkProjectile, _reason: String) -> void:
					K.eclat(t, point)})

	func _charge(t: Tk) -> void:
		t.kit().remove_modifier(SHIKOTSU)
		t.text(t.caster, "DERNIER SQUELETTE")
		var start: Vector3 = t.origin
		t.dash(7.0, t.dir, 0.25)
		t.fx("spikes", start + t.dir * 3.5, 2.0, BONE)
		for e: CombatCharacter in t.enemies_in_line(start, t.dir, 7.5, 1.4):
			t.hit(e, t.dmg(1.6), {"unblockable": true, "push": 3.0, "stun": 0.4})
