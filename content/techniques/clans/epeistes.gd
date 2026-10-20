extends RefCounted
## Technique kit: clan_epeistes (design bible, Kiri). Signature: Fil — up
## to 3 charges ("fil" resource, fades after 15 s without gain or spend),
## gained by a successful parry (perfect guard parry or Iai parry), a hit
## landed at the tip of the range (sweet spot: basic attacks and the kit's
## cuts, 2.5 s internal cooldown, none inside the Duel mist) or a correct
## recall of the thrown blade. Fil buys precision, movement or guard
## (recall step, feint, spectral Forms), never raw damage.

const KIT_ID := &"clan_epeistes"
const SIGNATURE = EpeistesSignature
const TECHNIQUES := {
	&"clan_epeistes_d_iai_de_garde": IaiDeGarde,
	&"clan_epeistes_c_lame_en_rappel": LameEnRappel,
	&"clan_epeistes_b_brise_garde_du_bourreau": BriseGardeDuBourreau,
	&"clan_epeistes_a_duel_dans_la_brume_rouge": DuelBrumeRouge,
	&"clan_epeistes_s_maitrise_des_sept_lames": MaitriseSeptLames,
}

const FIL := "fil"
const FIL_COLOR := Color(0.75, 0.9, 1.0)
const STEEL := Color(0.8, 0.85, 0.95)
const MIST := Color(0.8, 0.15, 0.2)
## Sweet spot: hit beyond this fraction of the reach.
const SWEET_RATIO: float = 0.72
const SWEET_COOLDOWN: float = 2.5


## Fil: the resource, perfect-parry and basic-attack sweet-spot hooks.
class EpeistesSignature extends KitSignature:
	var _last_flash: float = 0.0

	func setup(f: CombatCharacter) -> void:
		f.kit.define_resource(FIL, 3.0, "Fil", FIL_COLOR, 15.0)

	func tick(f: CombatCharacter, _delta: float) -> void:
		if not is_instance_valid(f):
			return
		# A perfect guard parry sets parry_flash: rising edge = successful parry.
		if f.parry_flash > _last_flash + 0.01:
			K.gain(f)
		_last_flash = f.parry_flash

	func on_deal(f: CombatCharacter, target: CombatCharacter, hit: HitData, _damage: float) -> Variant:
		if hit == null or hit.ability == null or not is_instance_valid(target):
			return null
		if f.abilities.is_basic_attack(hit.ability):
			K.sweet_spot(f, target, hit.ability.max_range + HitQuery.HURTBOX_RADIUS)
		return null


## Shared Épéistes rules.
class K:
	static func fil(t: Tk) -> int:
		return int(t.res(FIL) + 0.001)

	static func gain(f: CombatCharacter, n: int = 1) -> void:
		if not is_instance_valid(f) or f.is_dead() or not f.kit.resources.has(FIL):
			return
		if f.kit.res(FIL) < f.kit.res_max(FIL) and CombatFx.is_enabled():
			CombatFx.damage_number(f, f.global_position + Vector3.UP * 2.6, 0.0, FIL_COLOR, "+FIL")
		f.kit.add_res(FIL, float(n))

	static func spend(t: Tk, n: int = 1) -> bool:
		return t.spend_res(FIL, float(n))

	static func in_duel(f: CombatCharacter) -> bool:
		return f.kit.has_modifier("duel_brume")

	## Hit at the tip of `reach`: 1 Fil (cooldown outside the Duel mist).
	static func sweet_spot(f: CombatCharacter, target: CombatCharacter, reach: float) -> bool:
		if not is_instance_valid(f) or not is_instance_valid(target):
			return false
		if HitQuery.flat(target.global_position - f.global_position).length() < reach * SWEET_RATIO:
			return false
		if not in_duel(f):
			if f.kit.has_modifier("fil_sweet_cd"):
				return false
			f.kit.add_modifier("fil_sweet_cd", SWEET_COOLDOWN, {})
		gain(f)
		return true

	static func is_melee(e: CombatCharacter, a: AbilityData) -> bool:
		if a == null:
			return false
		return a.kind == AbilityData.Kind.MELEE_ARC or e.abilities.is_basic_attack(a) \
			or (a.kind == AbilityData.Kind.SCRIPTED and a.max_range <= 4.5)


## D — Parade, Draw attack, Ressource. Short sheathed guard window
## (0.32 s): a melee attack coming in during it is parried (negated), the
## draw comes out at once toward the attacker (stun) and grants 1 Fil.
## Otherwise a slower normal cut at the end of the window; a whiff leaves
## the swordsman slowed (long recovery). No protection vs ranged / AOE.
class IaiDeGarde extends Technique:
	const WINDOW: float = 0.32
	const REACH: float = 3.0

	func configure(a: AbilityData) -> void:
		a.startup_time = 0.06
		a.recovery_time = 0.5
		a.cast_move_multiplier = 0.3
		a.max_range = REACH
		a.anim = &"slash"

	func cast(t: Tk) -> void:
		var st: Dictionary = {"parried": false}
		var caster: CombatCharacter = t.caster
		var on_counter := func(hit: HitData) -> void:
			_parry(t, st, hit)
		st["cb"] = on_counter
		caster.counter_triggered.connect(on_counter, CONNECT_ONE_SHOT)
		t.buff("iai_garde", WINDOW, {"label": "Iai", "color": STEEL,
			"on_tick": func(_dt: float) -> void:
				_watch(t, st),
			"on_end": func() -> void:
				if is_instance_valid(caster):
					caster.status.remove_status(StatusController.Type.COUNTER)})
		t.after(WINDOW + 0.16, func(rt: Tk) -> void:
			if rt.caster.counter_triggered.is_connected(on_counter):
				rt.caster.counter_triggered.disconnect(on_counter)
			if not st.parried:
				_cut(rt))

	## A melee attacker winding up within reach: the guard catches it.
	func _watch(t: Tk, st: Dictionary) -> void:
		if st.parried or not t.alive():
			return
		for e: CombatCharacter in t.enemies_in(t.caster.global_position, REACH + 0.4):
			if e.abilities.is_casting() and K.is_melee(e, e.abilities.current):
				t.caster.status.apply_status(StatusController.Type.COUNTER, 0.12)
				return

	func _parry(t: Tk, st: Dictionary, hit: HitData) -> void:
		if st.parried or not t.alive():
			return
		st.parried = true
		t.caster.status.remove_status(StatusController.Type.COUNTER)
		t.kit().remove_modifier("iai_garde")
		var rt: Tk = t.refreshed()
		var d: Vector3 = rt.dir
		if hit != null and is_instance_valid(hit.source):
			var to: Vector3 = HitQuery.flat(hit.source.global_position - rt.origin)
			if to.length() > 0.1:
				d = to.normalized()
		rt.text(rt.caster, "PARADE")
		rt.fx("sparks", rt.origin + d, 1.2, STEEL)
		K.gain(rt.caster)
		rt.cone(REACH, 150.0, rt.dmg(1.0), {"stun": 0.5}, rt.origin, d)

	func _cut(t: Tk) -> void:
		var hits: Array[CombatCharacter] = t.cone(REACH, 120.0, t.dmg(0.75))
		for e: CombatCharacter in hits:
			K.sweet_spot(t.caster, e, REACH + HitQuery.HURTBOX_RADIUS)
		if hits.is_empty():
			t.buff("iai_ouvert", 0.6, {"speed": 0.4, "label": "Ouvert", "color": Color(0.7, 0.7, 0.7)})


## C — Throw, Retrieval, Positioning. Spinning throw: it plants in a wall
## or drops after an impact. While the blade is on the ground the swordsman
## is "Sans arme" (weaker basics, takes more damage). Recast: the blade
## flies back in a straight line toward the caster (piercing); the first
## enemy it hits grants 1 Fil. Spending 1 Fil on recall steps toward it.
class LameEnRappel extends Technique:
	const LIFE: float = 8.0

	func configure(a: AbilityData) -> void:
		a.startup_time = 0.18
		a.recovery_time = 0.25
		a.max_range = 11.0
		a.anim = &"throw"

	func cast(t: Tk) -> void:
		t.projectile({"speed": 22.0, "range": 11.0, "radius": 0.55, "size": 0.25, "color": STEEL,
			"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
				t.hit(e, t.dmg(0.6))
				return false,
			"on_end": func(point: Vector3, p: TkProjectile, reason: String) -> void:
				if t.alive():
					_land(t, point - p.direction * (0.4 if reason == "wall" else 0.0))})

	func _land(t: Tk, at: Vector3) -> void:
		t.fx("dust", at, 0.6, STEEL)
		var st: Dictionary = {}
		st["blade"] = t.object(at, {"kind": "lame", "radius": 0.6, "lifetime": LIFE, "look": KitObject.Look.PILLAR,
			"targetable": false, "color": STEEL,
			"on_expire": func(_o: KitObject) -> void:
				_rearm(t)})
		t.buff("sans_arme", LIFE, {"basic_damage": 0.6, "damage_taken": 1.15, "label": "Sans arme",
			"color": Color(0.6, 0.6, 0.65)})
		t.recast(LIFE, func(rt: Tk) -> void:
			_recall(rt, st))

	func _recall(t: Tk, st: Dictionary) -> void:
		var blade: Variant = st.get("blade")
		if blade == null or not is_instance_valid(blade) or not (blade as KitObject).is_alive():
			_rearm(t)
			return
		var from: Vector3 = HitQuery.flat((blade as KitObject).global_position)
		var to_blade: Vector3 = HitQuery.flat(from - t.origin)
		if to_blade.length() > 1.5 and K.spend(t, 1):
			t.dash(minf(3.0, to_blade.length() - 1.0), to_blade.normalized(), 0.12)
		(blade as KitObject).destroy("recalled")
		var back: Vector3 = HitQuery.flat(t.caster.global_position - from)
		var d: Vector3 = back.normalized() if back.length() > 0.1 else -t.dir
		var hit_st: Dictionary = {"fil": false}
		t.projectile({"from": from - d * 0.5, "dir": d, "speed": 26.0, "range": back.length() + 4.0, "radius": 0.6,
			"pierce": true, "size": 0.25, "color": STEEL, "homing": 4.0, "homing_target": t.caster,
			"on_tick": func(p: TkProjectile, _dt: float) -> void:
				if t.alive() and t.distance(p.global_position, t.caster.global_position) < 0.9:
					p.end("caught"),
			"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
				if t.hit(e, t.dmg(0.55)) == HitData.Result.HIT and not hit_st.fil:
					hit_st.fil = true
					K.gain(t.caster)
				return true,
			"on_end": func(_pt: Vector3, _p: TkProjectile, _r: String) -> void:
				_rearm(t)})

	func _rearm(t: Tk) -> void:
		if is_instance_valid(t.caster):
			t.kit().remove_modifier("sans_arme")


## B — Heavy attack, Guard break, Feint. Long telegraphed wind-up (0.85 s,
## slowed). The heavy blow vs a guard: unblockable posture damage, short
## stun and push; vs a shield: heavy damage into it and push; vs an open
## target: moderate damage. With 1+ Fil a recast during the wind-up
## spends 1 Fil, cancels it and throws a quick lateral cut instead.
class BriseGardeDuBourreau extends Technique:
	const CHARGE: float = 0.85
	const REACH: float = 3.4

	func configure(a: AbilityData) -> void:
		a.startup_time = 0.12
		a.recovery_time = 0.4
		a.cast_move_multiplier = 0.4
		a.max_range = REACH
		a.anim = &"slash"

	func cast(t: Tk) -> void:
		var st: Dictionary = {"feinted": false}
		var center: Vector3 = t.origin + t.dir * 1.8
		t.buff("bourreau_charge", CHARGE, {"speed": 0.35, "label": "Bourreau", "color": Color(0.9, 0.4, 0.3)})
		st["tele"] = t.telegraph(center, 1.9, CHARGE, func(rt: Tk) -> void:
			if not st.feinted and rt.caster.status.can_act():
				_heavy(rt, center))
		if K.fil(t) >= 1:
			t.recast(CHARGE - 0.05, func(rt: Tk) -> void:
				_feint(rt, st))

	func _heavy(t: Tk, center: Vector3) -> void:
		var to: Vector3 = HitQuery.flat(center - t.origin)
		var d: Vector3 = to.normalized() if to.length() > 0.2 else t.dir
		t.fx("cracks", t.origin + d * 1.8, 2.0, Color(0.9, 0.4, 0.3))
		if CombatFx.is_enabled():
			CombatFx.arc(t.caster, t.origin, d, REACH, 100.0, t.color, 0.25)
		KitObject.damage_objects_in(t.tree(), t.origin + d * REACH * 0.5, REACH * 0.5, t.caster.team, t.dmg(1.0))
		for e: CombatCharacter in t.enemies_in_cone(t.origin, d, REACH, 100.0):
			if e.guarding:
				t.text(e, "BRISE-GARDE")
				t.hit(e, t.dmg(0.45), {"unblockable": true, "stun": 0.6, "push": 3.5})
			elif e.health.shield > 0.0:
				t.hit(e, t.dmg(1.3), {"push": 3.5})
			else:
				t.hit(e, t.dmg(0.8), {"push": 1.5})
			K.sweet_spot(t.caster, e, REACH + HitQuery.HURTBOX_RADIUS)

	func _feint(t: Tk, st: Dictionary) -> void:
		if st.feinted or not K.spend(t, 1):
			return
		st.feinted = true
		var tele: Variant = st.get("tele")
		if tele != null and is_instance_valid(tele):
			(tele as KitObject).destroy("feint")
		t.kit().remove_modifier("bourreau_charge")
		t.text(t.caster, "FEINTE")
		var side: Vector3 = t.dir.cross(Vector3.UP)
		t.dash(1.2, side, 0.1)
		t.cone(2.6, 170.0, t.dmg(0.5), {"slow": 0.8})


## A — Zone duel, Information, Tempo. Low red mist around the swordsman and
## a nearby target (8 s). Inside, a parry or a sweet spot grants Fil at
## once (no sweet-spot cooldown). Enemies outside see blurred silhouettes
## (readable "Silhouettes" debuff, information only). A heavy CC on the
## swordsman dissipates it. The target may leave freely but then leaves a
## red trail for 3 s; the swordsman walking on it gains speed. No immunity.
class DuelBrumeRouge extends Technique:
	const RADIUS: float = 5.0
	const LIFE: float = 8.0

	func configure(a: AbilityData) -> void:
		a.startup_time = 0.25
		a.recovery_time = 0.2
		a.max_range = 7.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var target: CombatCharacter = t.target_at_aim(3.0)
		if target == null:
			target = t.nearest_enemy(t.origin, 7.0)
		var center: Vector3 = t.origin
		if target != null:
			center = (t.origin + HitQuery.flat(target.global_position)) * 0.5
		t.fx("smoke", center, RADIUS, MIST)
		t.buff("duel_brume", 0.5, {"label": "Duel", "color": MIST})
		t.zone(center, RADIUS, LIFE, {"kind": "brume", "color": MIST, "targetable": false, "tick_interval": 0.25,
			"look": KitObject.Look.RING, "data": {"target": target},
			"on_tick": func(o: KitObject) -> void:
				_tick(t, o),
			"on_exit": func(f: CombatCharacter, o: KitObject) -> void:
				var tgt: Variant = o.data.get("target")
				if tgt != null and is_instance_valid(tgt) and f == tgt:
					_reveal(t, f),
			"on_destroy": func(_o: KitObject, _r: String) -> void:
				if is_instance_valid(t.caster):
					t.kit().remove_modifier("duel_brume")})

	func _tick(t: Tk, o: KitObject) -> void:
		if not t.alive():
			o.destroy("caster")
			return
		var c: CombatCharacter = t.caster
		if c.status.has_status(StatusController.Type.STUN) or c.status.has_status(StatusController.Type.INCAPACITATE) \
				or c.is_launched():
			t.fx("smoke", o.global_position, o.radius, MIST)
			o.destroy("dispelled")
			return
		if o.contains(c.global_position):
			t.buff("duel_brume", 0.4, {"label": "Duel", "color": MIST})
		var tgt: Variant = o.data.get("target")
		for e: CombatCharacter in t.fighters():
			if e.team == c.team:
				continue
			if o.contains(e.global_position):
				if tgt != null and is_instance_valid(tgt) and e == tgt:
					t.debuff(e, "brume_duel", 0.4, {"label": "Duel", "color": MIST})
			elif t.distance(e.global_position, o.global_position) < 16.0:
				t.debuff(e, "brume_silhouettes", 0.4, {"label": "Silhouettes", "color": MIST})

	## Leaving the mist: a red trail follows the target for 3 s.
	func _reveal(t: Tk, f: CombatCharacter) -> void:
		if not t.is_enemy(f):
			return
		t.text(f, "TRAÎNÉE")
		var st: Dictionary = {"acc": 0.0}
		t.debuff(f, "trainee_rouge", 3.0, {"label": "Traînée", "color": MIST,
			"on_tick": func(dt: float) -> void:
				st.acc = float(st.acc) + dt
				if st.acc < 0.3 or not t.alive() or not is_instance_valid(f) or f.is_dead():
					return
				st.acc = 0.0
				t.object(f.global_position, {"kind": "trainee", "radius": 0.6, "lifetime": 2.5, "targetable": false,
					"color": MIST,
					"on_enter": func(who: CombatCharacter, _o: KitObject) -> void:
						if who == t.caster:
							t.buff("traque", 1.0, {"speed": 1.2, "label": "Traque", "color": MIST})})})


## S — Mode, Arsenal abstrait, Choix séquencé. 8 s mode; entering it cuts
## once (base Form). Each recast spends 1 Fil to summon a spectral Form,
## each usable once per activation, chosen by the aim distance (near:
## Double, mid: Lourde, far: Longue; falls back to the next unused one).
## Lourde blocks the next frontal hit (no CC); Longue and Double ride the
## next attack or technique (long spectral cut / two crossed strikes), then
## vanish. Unused Forms vanish with the mode. No Fil = base Form only.
class MaitriseSeptLames extends Technique:
	const MODE: float = 8.0

	func configure(a: AbilityData) -> void:
		a.startup_time = 0.3
		a.recovery_time = 0.3
		a.max_range = 9.0
		a.anim = &"slash"

	func cast(t: Tk) -> void:
		var st: Dictionary = {"used": {}, "pending": []}
		var caster: CombatCharacter = t.caster
		var on_attack := func(_slot: StringName, _a: AbilityData) -> void:
			_on_attack(t, st)
		st["cb"] = on_attack
		t.buff("sept_lames", MODE, {"label": "Sept lames", "color": FIL_COLOR,
			"on_end": func() -> void:
				if is_instance_valid(caster):
					if caster.abilities.cast_activated.is_connected(on_attack):
						caster.abilities.cast_activated.disconnect(on_attack)
					for form: String in ["lourde", "longue", "double"]:
						caster.kit.remove_modifier("forme_" + form)
					caster.kit.close_recast(t.id)})
		caster.abilities.cast_activated.connect(on_attack)
		# Base Form.
		t.fx("wave", t.origin + t.dir * 1.5, 1.8, FIL_COLOR)
		t.cone(3.2, 120.0, t.dmg(0.6))
		_open(t, st)

	func _open(t: Tk, st: Dictionary) -> void:
		var left: float = t.kit().modifier_left("sept_lames")
		if left <= 0.1 or (st.used as Dictionary).size() >= 3:
			return
		t.recast(left, func(rt: Tk) -> void:
			_summon(rt, st))

	func _choose(t: Tk, st: Dictionary) -> String:
		var d: float = t.distance(t.origin, t.aim)
		var order: Array[String] = []
		if d < 3.0:
			order.append_array(["double", "lourde", "longue"])
		elif d > 6.0:
			order.append_array(["longue", "double", "lourde"])
		else:
			order.append_array(["lourde", "double", "longue"])
		for form: String in order:
			if not (st.used as Dictionary).has(form):
				return form
		return ""

	func _summon(t: Tk, st: Dictionary) -> void:
		if not t.kit().has_modifier("sept_lames"):
			return
		if K.fil(t) < 1:
			t.text(t.caster, "SANS FIL")
			_open(t, st)
			return
		var form: String = _choose(t, st)
		if form == "" or not K.spend(t, 1):
			return
		st.used[form] = true
		var left: float = t.kit().modifier_left("sept_lames")
		var caster: CombatCharacter = t.caster
		t.fx("spheres", t.origin, 1.2, FIL_COLOR)
		match form:
			"lourde":
				t.text(caster, "FORME LOURDE")
				t.buff("forme_lourde", left, {"cc_immune": true, "tenacity": true, "label": "Forme lourde", "color": FIL_COLOR,
					"on_take": func(hit: HitData, _dmg: float) -> Variant:
						if hit == null or not is_instance_valid(hit.source) or hit.source == caster:
							return null
						var to: Vector3 = HitQuery.flat(hit.source.global_position - caster.global_position)
						if to.length() > 0.05 and caster.facing.facing_direction.dot(to.normalized()) < 0.3:
							return null
						caster.kit.remove_modifier("forme_lourde")
						t.fx("sparks", caster.global_position, 1.2, FIL_COLOR)
						return 0.0})
			_:
				t.text(caster, "FORME " + form.to_upper())
				(st.pending as Array).append(form)
				t.buff("forme_" + form, left, {"label": "Forme " + form, "color": FIL_COLOR})
		_open(t, st)

	## The next attack / technique carries the pending Forms, then they vanish.
	func _on_attack(t: Tk, st: Dictionary) -> void:
		var pending: Array = st.pending
		if pending.is_empty() or not t.alive():
			return
		var rt: Tk = t.refreshed()
		for form: Variant in pending:
			rt.kit().remove_modifier("forme_" + String(form))
			if form == "longue":
				rt.fx("bolt", rt.origin + rt.dir * 3.5, 1.0, FIL_COLOR)
				for e: CombatCharacter in rt.line(7.0, 1.0, rt.dmg(0.8)):
					K.sweet_spot(rt.caster, e, 7.0)
			elif form == "double":
				rt.cone(3.2, 70.0, rt.dmg(0.5), {}, rt.origin, rt.dir.rotated(Vector3.UP, deg_to_rad(30.0)))
				rt.after(0.12, func(t2: Tk) -> void:
					t2.cone(3.2, 70.0, t2.dmg(0.5), {}, t2.origin, t2.dir.rotated(Vector3.UP, deg_to_rad(-30.0))))
		pending.clear()
