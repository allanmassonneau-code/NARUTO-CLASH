extends RefCounted
## Kit clan_hozuki (corps liquide) — jutsu Shinobi Striker : Ondulation,
## Bras serpentins, Prison aqueuse (clones), Dragon aqueux, Suiton : Prison aqueuse.

const KIT_ID := &"clan_hozuki"
const SIGNATURE = null
const TECHNIQUES := {
	&"clan_hozuki_d_ondulation": Ondulation,
	&"clan_hozuki_c_bras_serpentins": BrasSerpentins,
	&"clan_hozuki_b_prison_aqueuse": PrisonAqueuseClones,
	&"clan_hozuki_a_dragon_aqueux": DragonAqueux,
	&"clan_hozuki_s_prison_aqueuse": SuitonPrisonAqueuse,
}

const WATER := Color(0.3, 0.6, 1.0)


## D — Melee (SS 2/2). Bras liquides étirés : attire la cible et draine ses PV.
class Ondulation extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.2
		a.recovery_time = 0.25
		a.cast_move_multiplier = 0.4
		a.max_range = 6.0
		a.anim = &"thrust"

	func cast(t: Tk) -> void:
		t.fx("wave", t.origin + t.dir * 3.0, 1.2, WATER)
		var dmg: float = t.dmg(0.8)
		for e: CombatCharacter in t.line(6.0, 1.4, dmg, {"pull_to": t.origin + t.dir * 1.2}):
			t.pull(e, t.origin + t.dir * 1.2)
			t.heal(t.caster, dmg * 0.7)
			t.fx("spheres", e.global_position, 0.8, WATER)


## C — Melee (SS 2/2). Bras serpentins : repousse, ralentit, soigne des dégâts infligés.
class BrasSerpentins extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.22
		a.recovery_time = 0.25
		a.max_range = 5.0
		a.anim = &"palm"

	func cast(t: Tk) -> void:
		t.fx("wave", t.origin + t.dir * 2.5, 1.5, WATER)
		var dmg: float = t.dmg(0.8)
		for e: CombatCharacter in t.cone(5.0, 50.0, dmg, {"push": 4.0, "push_from": t.origin, "slow": 2.5}):
			t.heal(t.caster, dmg)


## B — Melee (SS 2/2). Charge projetant des clones d'eau qui enferment les
## ennemis devant dans une cage : dégâts continus, permutation bloquée, vulnérabilité.
class PrisonAqueuseClones extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.4
		a.recovery_time = 0.3
		a.cast_move_multiplier = 0.2
		a.max_range = 5.0
		a.anim = &"dash"

	func cast(t: Tk) -> void:
		t.dash(2.5)
		var center: Vector3 = t.origin + t.dir * 3.5
		t.fx("spheres", center, 2.2, WATER)
		for e: CombatCharacter in t.enemies_in(center, 2.4):
			t.hit(e, t.dmg(0.3), {"root": 2.5, "seal": 2.5})
			t.text(e, "PRISON")
			t.debuff(e, "hozuki_cage", 4.0, {"damage_taken": 1.2, "label": "Cage d'eau", "color": WATER})
			t.channel(4, 0.6, func(ct: Tk, _i: int) -> void:
				if is_instance_valid(e) and ct.is_enemy(e):
					ct.hit(e, ct.dmg(0.15))
					ct.fx("burst", e.global_position, 0.7, WATER), Callable(), 0.6)


## A — Ranged (SS 2/5). Dragon d'eau qui traverse obstacles et ennemis, ralentit.
class DragonAqueux extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.35
		a.recovery_time = 0.3
		a.cast_move_multiplier = 0.3
		a.max_range = 18.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		t.projectile({"speed": 20.0, "range": 18.0, "radius": 1.1, "size": 0.7, "pierce": true, "color": WATER,
			"homing": 1.0,
			"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
				t.hit(e, t.dmg(0.8), {"slow": 2.5, "push": 1.5, "push_from": t.origin})
				t.fx("burst", e.global_position, 1.2, WATER)
				return true})


## S — Technical / FinishMove (SS 4/5). Boule d'eau qui emprisonne la cible
## puis s'étend sur une large zone, paralysant et blessant en continu.
class SuitonPrisonAqueuse extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.4
		a.recovery_time = 0.4
		a.cast_move_multiplier = 0.2
		a.max_range = 14.0
		a.anim = &"palm"

	func cast(t: Tk) -> void:
		var target: CombatCharacter = t.target_at_aim(3.0)
		var center: Vector3 = t.aim if target == null else HitQuery.flat(target.global_position)
		t.fx("spheres", center, 1.5, WATER)
		if target != null:
			t.hit(target, t.dmg(0.4), {"stun": 1.5})
			t.text(target, "PRISON")
		var sphere: KitObject = t.zone(center, 1.5, 5.0, {"kind": "prison_eau", "look": KitObject.Look.ORB,
			"targetable": false, "color": WATER, "tick_interval": 0.5,
			"on_tick": func(o: KitObject) -> void:
				o.radius = minf(o.radius + 0.4, 5.5)
				for e: CombatCharacter in o.enemies_inside():
					if t.is_enemy(e):
						t.hit(e, t.dmg(0.13), {"stun": 0.6})})
		sphere.data["grow"] = true
