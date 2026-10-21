extends RefCounted
## Kit clan_hoki : chimie / médecine (jutsu Shinobi Striker).

const KIT_ID := &"clan_hoki"
const SIGNATURE = null
const TECHNIQUES := {
	&"clan_hoki_d_paume_curative": PaumeCurative,
	&"clan_hoki_c_scalpel_de_chakra": ScalpelDeChakra,
	&"clan_hoki_b_rupture_du_systeme_nerveux": RuptureNerveuse,
	&"clan_hoki_a_outil_de_ninja_scientifique_ecaille_inve": EcailleInversee,
	&"clan_hoki_s_plumes_du_nirvana": PlumesDuNirvana,
}

const GREEN := Color(0.4, 1.0, 0.6)


## D — Paume curative (Heal) : soin continu des alliés autour de l'utilisateur.
class PaumeCurative extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.2
		a.recovery_time = 0.2
		a.cast_move_multiplier = 0.5
		a.max_range = 5.0
		a.anim = &"heal"

	func cast(t: Tk) -> void:
		t.buff("paume_curative", 3.0, {"label": "Soins", "color": GREEN})
		t.channel(6, 0.5, func(ct: Tk, _i: int) -> void:
			ct.fx("ring", ct.caster.global_position, 5.0, GREEN)
			for f: CombatCharacter in ct.allies_in(ct.caster.global_position, 5.0, true):
				ct.heal(f, ct.dmg(0.25)), Callable(), 0.6)


## C — Scalpel de chakra (Melee) : lames de chakra qui tranchent les nerfs ;
## la cible est ralentie et ne peut plus lancer de ninjutsu (silence).
class ScalpelDeChakra extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.12
		a.recovery_time = 0.25
		a.max_range = 2.6
		a.anim = &"slash"

	func cast(t: Tk) -> void:
		t.fx("sparks", t.origin + t.dir * 1.3, 1.2, Color(0.3, 0.8, 1.0))
		t.melee(2.6, 100.0, t.dmg(0.3), {"slow": 2.0})
		t.after(0.2, func(rt: Tk) -> void:
			for e: CombatCharacter in rt.melee(2.6, 100.0, rt.dmg(0.25), {"slow": 3.0, "silence": 3.0}):
				if is_instance_valid(e):
					rt.text(e, "NERFS"))


## B — Rupture du système nerveux (Melee) : décharge au toucher ; dégâts
## et contrôles inversés (étourdi puis désorienté / ralenti).
class RuptureNerveuse extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.2
		a.recovery_time = 0.3
		a.max_range = 2.4
		a.anim = &"palm"

	func cast(t: Tk) -> void:
		var start: Vector3 = t.origin
		t.dash(3.0, t.dir, 0.15)
		t.fx("bolt", t.origin + t.dir * 1.2, 1.2, Color(0.5, 0.8, 1.0))
		for e: CombatCharacter in t.line(5.0, 1.6, t.dmg(0.8), {"stun": 0.4}, start, t.dir):
			if is_instance_valid(e):
				t.debuff(e, "nerfs_inverses", 3.5, {"speed": 0.5, "label": "Contrôles inversés", "color": Color(0.5, 0.8, 1.0)})
				t.status(e, StatusController.Type.SLOW, 3.5)
				t.text(e, "INVERSÉ")


## A — Écaille inversée (Melee) : bras-bouclier, charge protégée qui scelle
## la permutation ; recast pour un coup de bouclier supplémentaire.
class EcailleInversee extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.2
		a.recovery_time = 0.25
		a.max_range = 7.0
		a.anim = &"dash"

	func cast(t: Tk) -> void:
		t.buff("ecaille", 1.0, {"damage_taken": 0.3, "label": "Bouclier", "color": Color(0.6, 0.9, 0.9)})
		var start: Vector3 = t.origin
		t.dash(6.0, t.dir, 0.3)
		t.after(0.3, func(rt: Tk) -> void:
			rt.fx("dust", rt.caster.global_position, 1.5)
			for e: CombatCharacter in rt.line(6.5, 1.4, rt.dmg(0.6), {"seal": 3.0, "push": 2.0}, start, rt.dir):
				if is_instance_valid(e):
					rt.text(e, "SCELLÉ"))
		t.recast(3.0, func(rt: Tk) -> void:
			rt.fx("wave", rt.origin + rt.dir, 1.5)
			rt.melee(2.8, 110.0, rt.dmg(0.4), {"push": 3.0}))


## S — Plumes du Nirvana (FinishMove, Technical) : genjutsu de plumes sur
## une large zone ; scelle ninjutsu / permutation et paralyse (endort).
class PlumesDuNirvana extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.45
		a.recovery_time = 0.3
		a.max_range = 10.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		t.fx("ring", t.aim, 6.5, Color(1.0, 1.0, 0.95))
		t.fx("smoke", t.aim, 6.5, Color(1.0, 1.0, 0.95))
		for e: CombatCharacter in t.area(t.aim, 6.5, t.dmg(0.2), {"genjutsu": 3.5, "silence": 5.0, "seal": 5.0, "unblockable": true}):
			if is_instance_valid(e):
				t.status(e, StatusController.Type.INCAPACITATE, 3.5)
				t.text(e, "NIRVANA")
