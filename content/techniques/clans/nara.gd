extends RefCounted
## Kit clan_nara — jutsu Shinobi Striker du clan Nara (ombres, possession).

const KIT_ID := &"clan_nara"
const SIGNATURE = null
const TECHNIQUES := {
	&"clan_nara_d_lien_de_l_autorite_divine": LienAutoriteDivine,
	&"clan_nara_c_manipulation_des_ombres": ManipulationDesOmbres,
	&"clan_nara_b_entrelacement_des_ombres": EntrelacementDesOmbres,
	&"clan_nara_a_possession": Possession,
	&"clan_nara_s_invocation_des_ombres": InvocationDesOmbres,
}

const SHADOW := Color(0.12, 0.1, 0.18)


## D — Technical. Kaléidoscope hypnotique : tant qu'on n'attaque pas, les coups
## reçus sont annulés ; +attaque, +vitesse pendant la durée.
class LienAutoriteDivine extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.15
		a.recovery_time = 0.2
		a.max_range = 0.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		t.fx("ring", t.origin, 2.0, Color(0.9, 0.1, 0.1))
		t.text(t.caster, "SHARINGAN")
		var caster: CombatCharacter = t.caster
		t.buff("autorite_divine", 6.0, {"damage_dealt": 1.2, "speed": 1.2, "label": "Autorité divine",
			"color": Color(0.9, 0.15, 0.15),
			"on_take": func(_hit, dmg: float) -> float:
				if is_instance_valid(caster) and not caster.abilities.is_casting():
					return dmg * 0.2
				return dmg})


## C — Ranged. L'ombre file au sol et immobilise (root + silence). Recast :
## Strangulation des ombres, dégâts et ralentissement sur les cibles prises.
class ManipulationDesOmbres extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.25
		a.recovery_time = 0.25
		a.max_range = 11.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		t.projectile({"speed": 15.0, "range": 11.0, "radius": 0.7, "size": 0.3, "color": SHADOW,
			"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
				t.hit(e, t.dmg(0.3), {"root": 2.5, "silence": 2.5})
				t.mark(e, "ombre_liee", 1, 2.5, 1, "Ombre")
				t.text(e, "LIÉ")
				return false})
		t.recast(2.5, func(rt: Tk) -> void:
			for e: CombatCharacter in rt.enemies_in(rt.origin, 25.0):
				if rt.consume_mark(e, "ombre_liee") > 0:
					rt.fx("implosion", e.global_position, 1.0, SHADOW)
					rt.hit(e, rt.dmg(0.7), {"slow": 2.5}))


## B — Ranged. Aiguilles d'ombre projetées en arc : dégâts et défense réduite.
class EntrelacementDesOmbres extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.2
		a.recovery_time = 0.25
		a.max_range = 9.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		for i in 5:
			var d: Vector3 = t.dir.rotated(Vector3.UP, deg_to_rad(-30.0 + 15.0 * i))
			t.projectile({"dir": d, "speed": 22.0, "range": 9.0, "radius": 0.45, "size": 0.15, "color": SHADOW,
				"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
					t.hit(e, t.dmg(0.2))
					t.debuff(e, "defense_brisee_ombre", 4.0, {"damage_taken": 1.15, "label": "Défense -", "color": SHADOW})
					return false})


## A — Technical. Énergie mentale : paralyse à l'impact, +dégâts subis ;
## l'utilisateur est immobilisé. Recast : explosion sur les cibles possédées.
class Possession extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.3
		a.recovery_time = 0.3
		a.cast_move_multiplier = 0.0
		a.max_range = 11.0
		a.anim = &"palm"

	func cast(t: Tk) -> void:
		t.status(t.caster, StatusController.Type.ROOT, 0.6)
		t.projectile({"speed": 24.0, "range": 11.0, "radius": 0.6, "size": 0.25, "color": Color(0.6, 0.4, 1.0),
			"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
				t.hit(e, t.dmg(0.4), {"stun": 1.2})
				t.debuff(e, "possede", 4.0, {"damage_taken": 1.2, "label": "Possédé", "color": Color(0.6, 0.4, 1.0)})
				t.mark(e, "possede", 1, 4.0, 1, "Possédé")
				return false})
		t.recast(4.0, func(rt: Tk) -> void:
			for e: CombatCharacter in rt.enemies_in(rt.origin, 25.0):
				if rt.consume_mark(e, "possede") > 0:
					rt.fx("explosion", e.global_position, 1.5, Color(0.6, 0.4, 1.0))
					rt.area(e.global_position, 1.8, rt.dmg(0.7)))


## S — FinishMove. L'ombre attire les cibles, les immobilise, réduit leur
## défense puis explose.
class InvocationDesOmbres extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.4
		a.recovery_time = 0.4
		a.cast_move_multiplier = 0.0
		a.max_range = 11.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		t.fx("wave", t.origin + t.dir * 5.0, 5.0, SHADOW)
		var caught: Array[CombatCharacter] = t.line(11.0, 3.0, t.dmg(0.4), {"root": 1.6})
		for e: CombatCharacter in caught:
			t.pull(e, t.origin + t.dir * 2.0, -1.0, 0.35)
			t.debuff(e, "ombre_invoquee", 5.0, {"damage_taken": 1.2, "label": "Défense -", "color": SHADOW})
		t.after(1.0, func(rt: Tk) -> void:
			for e: CombatCharacter in caught:
				if is_instance_valid(e) and rt.is_enemy(e):
					rt.fx("explosion", e.global_position, 2.0, SHADOW)
					rt.hit(e, rt.dmg(1.4)))
