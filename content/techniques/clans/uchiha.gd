extends RefCounted
## Technique kit: clan Uchiha — Sharingan, Katon shuriken and Amaterasu /
## Enton black flames from Shinobi Striker.

const KIT_ID := &"clan_uchiha"
const SIGNATURE = null
const TECHNIQUES := {
	&"clan_uchiha_d_sharingan": Sharingan,
	&"clan_uchiha_c_balsamine_pourpre": BalsaminePourpre,
	&"clan_uchiha_b_lumiere_celeste": LumiereCeleste,
	&"clan_uchiha_a_kagutsuchi": Kagutsuchi,
	&"clan_uchiha_s_feu_noir_de_susano": FeuNoirDeSusano,
}

const RED := Color(0.9, 0.1, 0.1)
const BLACK_FIRE := Color(0.15, 0.05, 0.2)


## Shared: Amaterasu black flames on a target.
class K:
	static func black_flames(t: Tk, e: CombatCharacter, seconds: float) -> void:
		if not t.is_enemy(e):
			return
		t.status(e, StatusController.Type.BURN, seconds)
		t.fx("ember", e.global_position, 1.0, BLACK_FIRE)


## D — Sharingan: mode that reads the enemy: the next incoming attack is
## completely negated (once), and enemies around are briefly hypnotised.
class Sharingan extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.1
		a.recovery_time = 0.15
		a.max_range = 0.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var kit: KitState = t.kit()
		t.fx("ring", t.origin, 3.0, RED)
		t.text(t.caster, "SHARINGAN", RED)
		t.buff("sharingan", 8.0, {"label": "Sharingan", "color": RED,
			"on_take": func(_hit: HitData, _dmg: float) -> Variant:
				kit.remove_modifier("sharingan")
				return 0.0})
		for e: CombatCharacter in t.enemies_in(t.origin, 4.0):
			t.hit(e, 0.0, {"genjutsu": 0.8})


## C — Katon Phoenix Flower (shuriken): a fan of fire-imbued shuriken.
class BalsaminePourpre extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.2
		a.recovery_time = 0.25
		a.max_range = 15.0
		a.anim = &"throw"

	func cast(t: Tk) -> void:
		for i in 6:
			var d: Vector3 = t.dir.rotated(Vector3.UP, deg_to_rad(-20.0 + 8.0 * i))
			t.after(0.04 * i, func(rt: Tk) -> void:
				rt.projectile({"dir": d, "speed": 26.0, "range": 15.0, "radius": 0.4, "size": 0.15, "homing": 0.8,
					"color": Color(1.0, 0.45, 0.1),
					"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
						rt.hit(e, rt.dmg(0.17), {"burn": 1.5})
						return false}))


## B — Amaterasu: black flames erupt at the target's feet and stay on the
## field, burning anyone touching them.
class LumiereCeleste extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.35
		a.recovery_time = 0.3
		a.max_range = 12.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var target: CombatCharacter = t.target_at_aim(3.0)
		var at: Vector3 = t.aim if target == null else HitQuery.flat(target.global_position)
		t.fx("column", at, 1.5, BLACK_FIRE)
		for e: CombatCharacter in t.area(at, 1.8, t.dmg(0.5)):
			K.black_flames(t, e, 3.0)
		t.zone(at, 2.0, 6.0, {"kind": "amaterasu", "tick_interval": 0.5, "targetable": false, "color": BLACK_FIRE,
			"on_tick": func(o: KitObject) -> void:
				for e: CombatCharacter in o.enemies_inside():
					t.hit(e, t.dmg(0.1))
					K.black_flames(t, e, 1.5)})


## A — Enton Kagutsuchi: black flames shaped into blades, several thrown at
## the target: impact damage then lasting burn.
class Kagutsuchi extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.3
		a.recovery_time = 0.3
		a.max_range = 13.0
		a.anim = &"throw"

	func cast(t: Tk) -> void:
		var target: CombatCharacter = t.target_at_aim(3.0)
		for i in 4:
			var d: Vector3 = t.dir.rotated(Vector3.UP, deg_to_rad(-15.0 + 10.0 * i))
			t.after(0.08 * i, func(rt: Tk) -> void:
				var opts: Dictionary = {"dir": d, "speed": 24.0, "range": 13.0, "radius": 0.5, "size": 0.25,
					"homing": 3.0, "color": BLACK_FIRE,
					"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
						rt.hit(e, rt.dmg(0.25))
						K.black_flames(rt, e, 3.0)
						return false}
				if target != null and is_instance_valid(target):
					opts["homing_target"] = target
				rt.projectile(opts))


## S (ultime SS) — Enton Susano'o black-flame arrow: the Susano'o draws and
## looses a huge piercing arrow; the blast leaves black flames.
class FeuNoirDeSusano extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.6
		a.recovery_time = 0.4
		a.cast_move_multiplier = 0.2
		a.max_range = 20.0
		a.anim = &"throw"

	func cast(t: Tk) -> void:
		t.buff("susano", 1.5, {"damage_taken": 0.5, "label": "Susanô", "color": Color(0.5, 0.2, 0.7)})
		t.projectile({"speed": 34.0, "range": 20.0, "radius": 1.0, "pierce": true, "size": 0.5, "color": BLACK_FIRE,
			"on_hit": func(e: CombatCharacter, p: TkProjectile) -> bool:
				t.hit(e, t.dmg(1.2), {"push": 3.0, "push_from": p.global_position})
				K.black_flames(t, e, 4.0)
				return true,
			"on_end": func(point: Vector3, _p: TkProjectile, _reason: String) -> void:
				t.fx("explosion", point, 3.0, BLACK_FIRE)
				for e: CombatCharacter in t.area(point, 3.0, t.dmg(0.6)):
					K.black_flames(t, e, 3.0)
				t.zone(point, 2.5, 5.0, {"kind": "feu_noir", "tick_interval": 0.5, "targetable": false, "color": BLACK_FIRE,
					"on_tick": func(o: KitObject) -> void:
						for e: CombatCharacter in o.enemies_inside():
							t.hit(e, t.dmg(0.1))})})
