extends RefCounted
## Kit clan_hakumei : clan assassin (jutsu Shinobi Striker).

const KIT_ID := &"clan_hakumei"
const SIGNATURE = null
const TECHNIQUES := {
	&"clan_hakumei_d_disparition": Disparition,
	&"clan_hakumei_c_estocade_fulgurante": EstocadeFulgurante,
	&"clan_hakumei_b_mille_oiseaux_d_onyx": MilleOiseauxDOnyx,
	&"clan_hakumei_a_style_uchiwa_danse_du_halo": DanseDuHalo,
	&"clan_hakumei_s_technique_des_shurikens_uchiwa_mousson": Mousson,
}


## D — Disparition (Technical) : bonus de vitesse de déplacement.
class Disparition extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.05
		a.recovery_time = 0.1
		a.max_range = 4.0
		a.anim = &"dash"

	func cast(t: Tk) -> void:
		t.fx("smoke", t.origin, 1.2)
		t.dash(3.0, t.dir, 0.12, true)
		t.buff("disparition", 5.0, {"speed": 1.45, "label": "Vitesse", "color": Color(0.7, 0.9, 1.0)})
		t.status(t.caster, StatusController.Type.HASTE, 5.0)


## C — Estocade fulgurante (Melee) : fonce, empale, puis coup vertical.
class EstocadeFulgurante extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.12
		a.recovery_time = 0.3
		a.max_range = 5.0
		a.anim = &"thrust"

	func cast(t: Tk) -> void:
		var start: Vector3 = t.origin
		t.dash(4.0, t.dir, 0.18)
		t.line(4.8, 1.2, t.dmg(0.45), {"root": 0.5}, start, t.dir)
		t.after(0.3, func(rt: Tk) -> void:
			rt.fx("bolt", rt.caster.global_position + rt.dir, 1.0)
			rt.melee(2.4, 80.0, rt.dmg(0.4), {"launch": 0.6}))


## B — Mille oiseaux d'onyx (Melee) : charge foudre noire ; dégâts et
## permutation scellée.
class MilleOiseauxDOnyx extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.2
		a.recovery_time = 0.3
		a.max_range = 7.0
		a.anim = &"chidori"

	func cast(t: Tk) -> void:
		var start: Vector3 = t.origin
		t.dash(6.0, t.dir, 0.22)
		t.after(0.22, func(rt: Tk) -> void:
			rt.fx("bolt", rt.caster.global_position, 1.8, Color(0.2, 0.1, 0.35))
			var hit: Array[CombatCharacter] = rt.line(6.5, 1.4, rt.dmg(0.8), {"seal": 3.0, "stun": 0.3}, start, rt.dir)
			for e: CombatCharacter in rt.melee(2.2, 120.0, 0.0, {}):
				if not hit.has(e):
					rt.hit(e, rt.dmg(0.8), {"seal": 3.0, "stun": 0.3}))


## A — Style Uchiwa : Danse du halo (Melee) : charge puis combo de dague
## enflammée ; téléportation dans le dos après chaque coup ; le 1er scelle.
class DanseDuHalo extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.15
		a.recovery_time = 0.3
		a.max_range = 6.0
		a.anim = &"slash"

	func cast(t: Tk) -> void:
		var target: CombatCharacter = t.target_at_aim(3.0)
		if target == null:
			target = t.nearest_enemy(t.origin, 6.0)
		if target == null:
			t.dash(5.0, t.dir, 0.2)
			t.after(0.2, func(rt: Tk) -> void:
				rt.melee(2.4, 90.0, rt.dmg(0.6), {"seal": 3.0, "burn": 2.0}))
			return
		for i in 3:
			t.after(0.25 * i, func(rt: Tk) -> void:
				if not is_instance_valid(target) or not rt.is_enemy(target):
					return
				var behind: Vector3 = target.global_position - HitQuery.flat(rt.caster.global_position - target.global_position).normalized() * 1.2
				if i > 0:
					rt.blink(behind)
				rt.fx("ember", target.global_position, 1.0)
				var opts: Dictionary = {"burn": 2.0}
				if i == 0:
					opts["seal"] = 3.0
				rt.hit(target, rt.dmg(0.35), opts))


## S — Shurikens Uchiwa : Mousson (FinishMove, Heal) : pluie de kunai
## scellés ; explosifs sur les ennemis, soin total sur les alliés touchés.
class Mousson extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.4
		a.recovery_time = 0.35
		a.max_range = 12.0
		a.anim = &"throw"

	func cast(t: Tk) -> void:
		var at: Vector3 = t.aim
		for f: CombatCharacter in t.allies_in(at, 5.0, true):
			t.heal(f, 9999.0)
			t.fx("ring", f.global_position, 1.2, Color(0.4, 1.0, 0.6))
		for i in 4:
			t.after(0.15 * i, func(rt: Tk) -> void:
				rt.fx("explosion", at, 4.5)
				rt.area(at, 4.5, rt.dmg(0.45)))
