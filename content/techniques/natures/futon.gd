extends RefCounted
## Technique kit: Futon — real Shinobi Striker wind jutsu (Rasengan family,
## Boruto's vanishing orb, wind blades, acid mist).

const KIT_ID := &"futon"
const SIGNATURE = null
const TECHNIQUES := {
	&"futon_d_orbe_tourbillonnant_evanescent": OrbeEvanescent,
	&"futon_d_bourrasque_de_konoha": BourrasqueDeKonoha,
	&"futon_c_tornade_superieure": TornadeSuperieure,
	&"futon_c_grande_percee": GrandePercee,
	&"futon_b_lame_du_vent": LameDuVent,
	&"futon_b_brouillard_ingenieux": BrouillardIngenieux,
	&"futon_a_futon_orbe_shuriken": OrbeShuriken,
	&"futon_a_orbe_tourbillonnant_evanescent_pleine_lu": PleineLune,
	&"futon_s_mega_orbe_tourbillonnant_geant": MegaOrbe,
	&"futon_s_frappe_de_boruto": FrappeDeBoruto,
}

const WIND := Color(0.7, 0.95, 1.0)


## D — Vanishing Rasengan: tiny fast orb (nearly invisible) that bursts on
## impact and hits every enemy around the impact point.
class OrbeEvanescent extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.15
		a.recovery_time = 0.2
		a.max_range = 15.0
		a.anim = &"throw"

	func cast(t: Tk) -> void:
		t.projectile({"speed": 30.0, "range": 15.0, "radius": 0.5, "size": 0.08, "color": Color(0.8, 0.95, 1.0, 0.25),
			"on_end": func(point: Vector3, _p: TkProjectile, _reason: String) -> void:
				t.fx("spheres", point, 2.0, WIND)
				t.area(point, 2.2, t.dmg(0.8), {"push": 1.5, "push_from": point})})


## D — Leaf Hurricane: dash to the target and a low spinning kick that
## breaks guard.
class BourrasqueDeKonoha extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.1
		a.recovery_time = 0.25
		a.max_range = 6.0
		a.anim = &"kick"

	func cast(t: Tk) -> void:
		var target: CombatCharacter = t.target_at_aim(3.0)
		var dist: float = 5.0 if target == null else maxf(0.0, t.distance(t.origin, target.global_position) - 1.0)
		t.dash(minf(dist, 6.0), t.dir, 0.15)
		t.after(0.16, func(rt: Tk) -> void:
			rt.fx("wave", rt.caster.global_position, 2.0, WIND)
			rt.area(rt.caster.global_position, 2.0, rt.dmg(0.8), {"unblockable": true, "stun": 0.3}))


## C — Tornado High: shadow clones knock the target up into a whirlwind
## that pulls others in; heals the caster on success.
class TornadeSuperieure extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.35
		a.recovery_time = 0.3
		a.max_range = 3.5
		a.anim = &"kick"

	func cast(t: Tk) -> void:
		var hits: Array[CombatCharacter] = t.melee(3.0, 90.0, t.dmg(0.5), {"launch": 0.8})
		if hits.is_empty():
			return
		var at: Vector3 = HitQuery.flat(hits[0].global_position)
		t.clone(at + t.dir * 1.2, 1.0)
		t.heal(t.caster, t.dmg(0.6))
		t.fx("column", at, 2.0, WIND)
		t.zone(at, 3.5, 1.5, {"kind": "tourbillon", "tick_interval": 0.5, "targetable": false, "color": WIND,
			"on_tick": func(o: KitObject) -> void:
				for e: CombatCharacter in t.enemies_in(o.global_position, 3.5):
					t.pull(e, o.global_position, 1.2)
					t.hit(e, t.dmg(0.12))})


## C — Great Breakthrough: straight gust piercing every target, reducing
## their tracking (slow) and HP recovery.
class GrandePercee extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.3
		a.recovery_time = 0.3
		a.max_range = 14.0
		a.anim = &"breath"

	func cast(t: Tk) -> void:
		t.projectile({"speed": 22.0, "range": 14.0, "radius": 1.2, "pierce": true, "size": 0.5, "color": WIND,
			"on_hit": func(e: CombatCharacter, p: TkProjectile) -> bool:
				t.hit(e, t.dmg(0.8), {"push": 2.5, "slow": 2.0, "push_from": p.global_position})
				t.debuff(e, "grande_percee", 5.0, {"speed": 0.85, "heal_taken": 0.6, "label": "Anti-soin", "color": WIND})
				return true})


## B — Wind Blade: four tornadoes close in on nearby enemies; damage,
## anti-heal and knock-up. Allies touching them are lifted (short boost).
class LameDuVent extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.3
		a.recovery_time = 0.3
		a.max_range = 11.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		for i in 4:
			var d: Vector3 = t.dir.rotated(Vector3.UP, deg_to_rad(-45.0 + 30.0 * i))
			t.projectile({"from": t.origin, "dir": d, "speed": 10.0, "range": 11.0, "radius": 1.0, "homing": 2.5,
				"size": 0.45, "color": WIND,
				"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
					t.hit(e, t.dmg(0.35), {"launch": 0.6})
					t.debuff(e, "lame_du_vent", 5.0, {"damage_taken": 1.05, "heal_taken": 0.6, "label": "Anti-soin", "color": WIND})
					return false,
				"on_end": func(point: Vector3, _p: TkProjectile, _reason: String) -> void:
					t.fx("column", point, 1.0, WIND)
					if not t.allies_in(point, 1.5).is_empty():
						t.buff("envol", 1.5, {"speed": 1.3, "label": "Envol", "color": WIND})})


## B (ultime SS) — Ingenious Mist (Futton): spits an acid mist cloud;
## defence and speed down, damage over time inside.
class BrouillardIngenieux extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.35
		a.recovery_time = 0.3
		a.max_range = 7.0
		a.anim = &"breath"

	func cast(t: Tk) -> void:
		var at: Vector3 = t.origin + t.dir * 4.0
		t.fx("smoke", at, 3.5, Color(0.8, 0.9, 0.6))
		t.cone(6.0, 70.0, t.dmg(0.4), {"slow": 1.5})
		t.zone(at, 3.5, 5.0, {"kind": "brume_acide", "tick_interval": 0.5, "targetable": false, "color": Color(0.75, 0.9, 0.55),
			"on_tick": func(o: KitObject) -> void:
				for e: CombatCharacter in o.enemies_inside():
					t.hit(e, t.dmg(0.14), {"slow": 0.6})
					t.debuff(e, "acide", 1.0, {"damage_taken": 1.2, "speed": 0.75, "label": "Acide", "color": Color(0.75, 0.9, 0.55)})})


## A — Sage Art Wind Rasenshuriken: giant fast shuriken, explodes on hit and
## lowers the target's defence.
class OrbeShuriken extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.45
		a.recovery_time = 0.3
		a.cast_move_multiplier = 0.3
		a.max_range = 16.0
		a.anim = &"throw"

	func cast(t: Tk) -> void:
		t.projectile({"speed": 24.0, "range": 16.0, "radius": 1.0, "size": 0.7, "color": WIND,
			"on_end": func(point: Vector3, _p: TkProjectile, _reason: String) -> void:
				t.fx("explosion", point, 3.0, WIND)
				for e: CombatCharacter in t.area(point, 3.0, t.dmg(1.0)):
					t.debuff(e, "defense_brisee", 6.0, {"damage_taken": 1.2, "label": "Défense -", "color": WIND})})


## A — Vanishing Rasengan: Full Moon. Hold to charge (recast fires early):
## a small and a large orb; on hit they pull enemies around. Charge grows
## damage, size, pull radius and duration.
class PleineLune extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.2
		a.recovery_time = 0.25
		a.max_range = 15.0
		a.anim = &"palm"

	func cast(t: Tk) -> void:
		var state: Dictionary = {"fired": false}
		t.buff("pleine_lune_charge", 1.2, {"speed": 0.5, "label": "Charge", "color": WIND})
		t.recast(1.2, func(rt: Tk) -> void:
			_fire(rt, state, 0.0),
			func() -> void:
				_fire(t.refreshed(), state, 1.0))

	func _fire(t: Tk, state: Dictionary, charge: float) -> void:
		if state.fired:
			return
		state.fired = true
		t.kit().remove_modifier("pleine_lune_charge")
		for big in [false, true]:
			var scale: float = (1.6 if big else 1.0) * (1.0 + 0.5 * charge)
			t.after(0.12 if big else 0.0, func(rt: Tk) -> void:
				rt.projectile({"speed": 20.0, "range": 15.0, "radius": 0.5 * scale, "size": 0.25 * scale, "color": WIND,
					"on_end": func(point: Vector3, _p: TkProjectile, _reason: String) -> void:
						rt.fx("implosion", point, 2.0 * scale, WIND)
						rt.area(point, 1.2 * scale, rt.dmg((0.55 if big else 0.35) * (1.0 + 0.6 * charge)))
						rt.zone(point, 2.5 * scale, 1.0 + charge, {"kind": "attraction", "tick_interval": 0.25,
							"targetable": false, "color": WIND, "on_tick": func(o: KitObject) -> void:
								for e: CombatCharacter in rt.enemies_in(o.global_position, o.radius):
									rt.pull(e, o.global_position, 0.8)})}))


## S (ultime SS) — Massive Rasengan: short-range, fast huge orb that stays
## in place after impact, grinding everything inside.
class MegaOrbe extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.25
		a.recovery_time = 0.4
		a.max_range = 4.0
		a.anim = &"palm"

	func cast(t: Tk) -> void:
		var at: Vector3 = t.origin + t.dir * 2.5
		t.fx("spheres", at, 3.0, WIND)
		t.area(at, 3.0, t.dmg(1.0), {"stun": 0.5})
		t.zone(at, 3.0, 2.0, {"kind": "mega_orbe", "look": KitObject.Look.ORB, "tick_interval": 0.25, "targetable": false,
			"color": WIND, "on_tick": func(o: KitObject) -> void:
				for e: CombatCharacter in t.enemies_in(o.global_position, o.radius):
					t.pull(e, o.global_position, 0.6)
					t.hit(e, t.dmg(0.12)),
			"on_expire": func(o: KitObject) -> void:
				t.fx("explosion", o.global_position, 3.5, WIND)
				t.area(o.global_position, 3.5, t.dmg(0.4), {"push": 4.0, "push_from": o.global_position})})


## S (ultime SS) — Boruto Strike: a clone knocks the target up, then the
## user throws a Rasengan that pulls in and damages several enemies.
class FrappeDeBoruto extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.3
		a.recovery_time = 0.4
		a.max_range = 9.0
		a.anim = &"kick"

	func cast(t: Tk) -> void:
		var target: CombatCharacter = t.target_at_aim(3.0)
		var at: Vector3 = t.aim if target == null else HitQuery.flat(target.global_position)
		t.clone(at - t.dir * 1.0, 1.2)
		t.fx("column", at, 1.5, WIND)
		t.area(at, 2.0, t.dmg(0.6), {"launch": 1.0})
		t.after(0.45, func(rt: Tk) -> void:
			rt.fx("implosion", at, 4.0, WIND)
			for e: CombatCharacter in rt.enemies_in(at, 4.5):
				rt.pull(e, at, 3.0)
			rt.after(0.2, func(rt2: Tk) -> void:
				rt2.fx("spheres", at, 3.0, WIND)
				rt2.area(at, 3.0, rt2.dmg(1.2), {"stun": 0.4})))
