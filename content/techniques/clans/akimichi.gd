extends RefCounted
## Kit clan_akimichi — jutsu Shinobi Striker du clan Akimichi (décuplement).

const KIT_ID := &"clan_akimichi"
const SIGNATURE = null
const TECHNIQUES := {
	&"clan_akimichi_d_decuplement_partiel": DecuplementPartiel,
	&"clan_akimichi_c_boulet_humain_herisse": BouletHumainHerisse,
	&"clan_akimichi_b_choc_du_cerisier": ChocDuCerisier,
	&"clan_akimichi_a_irruption_fracassante": IrruptionFracassante,
	&"clan_akimichi_s_jumbo_decuplement": JumboDecuplement,
}

const CHAKRA := Color(1.0, 0.55, 0.3)


## D — Melee. Bras agrandis : coup large qui brise la garde ; pas de
## tressaillement pendant l'attaque (ténacité).
class DecuplementPartiel extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.3
		a.recovery_time = 0.3
		a.max_range = 3.8
		a.anim = &"hook"

	func cast(t: Tk) -> void:
		t.buff("decuplement_partiel", 1.5, {"tenacity": true, "label": "Inébranlable", "color": CHAKRA})
		t.fx("burst", t.origin + t.dir * 2.5, 1.8, CHAKRA)
		t.melee(3.8, 110.0, t.dmg(0.8), {"unblockable": true, "push": 1.5})


## C — Melee. Boulet roulant : ruée sur la durée, repousse les ennemis, ne
## recule pas sous les coups.
class BouletHumainHerisse extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.25
		a.recovery_time = 0.3
		a.max_range = 12.0
		a.anim = &"dash"

	func cast(t: Tk) -> void:
		t.buff("boulet_herisse", 2.0, {"tenacity": true, "label": "Boulet", "color": CHAKRA})
		var hit_once: Dictionary = {}
		t.channel(7, 0.22, func(ct: Tk, _i: int) -> void:
			ct.dash(1.8, ct.dir, 0.2)
			ct.fx("dust", ct.caster.global_position, 1.4)
			for e: CombatCharacter in ct.enemies_in(ct.caster.global_position, 1.8):
				var k: int = e.get_instance_id()
				var n: int = int(hit_once.get(k, 0))
				if n >= 2:
					continue
				hit_once[k] = n + 1
				ct.hit(e, ct.dmg(0.35), {"push": 3.0, "push_from": ct.caster.global_position}),
			Callable(), 1.0)


## B — Melee. Choc du cerisier : frappe la zone, paralyse, réduit l'attaque
## adverse et augmente les soins de l'utilisateur.
class ChocDuCerisier extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.35
		a.recovery_time = 0.35
		a.max_range = 3.5
		a.anim = &"stomp"

	func cast(t: Tk) -> void:
		t.fx("cracks", t.origin, 3.5, Color(1.0, 0.6, 0.75))
		for e: CombatCharacter in t.area(t.origin, 3.5, t.dmg(0.8), {"stun": 0.8}):
			t.debuff(e, "attaque_reduite", 5.0, {"damage_dealt": 0.8, "label": "Attaque -", "color": Color(1.0, 0.6, 0.75)})
		t.buff("soins_cerisier", 8.0, {"heal_taken": 1.3, "label": "Soins +", "color": Color(1.0, 0.6, 0.75)})
		t.heal(t.caster, t.dmg(0.4))


## A — Melee. Charge et coup de pied qui envoie en l'air ; défense accrue.
class IrruptionFracassante extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.25
		a.recovery_time = 0.35
		a.max_range = 6.0
		a.anim = &"kick"

	func cast(t: Tk) -> void:
		t.buff("defense_irruption", 5.0, {"damage_taken": 0.75, "label": "Défense +", "color": CHAKRA})
		t.dash(4.5, t.dir, 0.18)
		t.after(0.2, func(rt: Tk) -> void:
			rt.fx("burst", rt.caster.global_position + rt.dir * 1.5, 1.6, CHAKRA)
			rt.melee(2.8, 100.0, rt.dmg(0.8), {"launch": 0.9}))


## S — FinishMove. Corps entier décuplé : frappe colossale du sol qui blesse
## tous les ennemis à portée.
class JumboDecuplement extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.6
		a.recovery_time = 0.5
		a.cast_move_multiplier = 0.0
		a.max_range = 6.0
		a.anim = &"stomp"

	func cast(t: Tk) -> void:
		t.buff("jumbo", 2.0, {"tenacity": true, "damage_taken": 0.6, "label": "Jumbo", "color": CHAKRA})
		var at: Vector3 = t.origin + t.dir * 2.5
		t.fx("explosion", at, 4.5, CHAKRA)
		t.fx("cracks", at, 5.5)
		t.area(at, 4.5, t.dmg(1.3), {"stun": 0.7})
		t.after(0.5, func(rt: Tk) -> void:
			rt.fx("wave", at, 6.0)
			rt.area(at, 6.0, rt.dmg(0.6), {"push": 3.0, "push_from": at}))
