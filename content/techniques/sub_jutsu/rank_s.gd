extends RefCounted
## Sub-jutsu rang S — ultimes universels de Shinobi Striker.

const KIT_ID := &"sub_rank_s"
const SIGNATURE = null
const TECHNIQUES := {
	&"sub_s_sept_cieux": SeptCieux,
	&"sub_s_ouverture_des_verrous_psychiques_porte_d": PorteRetention,
	&"sub_s_la_creation_et_le_renouveau": CreationRenouveau,
	&"sub_s_garuda_c4": GarudaC4,
	&"sub_s_paumes_jumelles_des_lions_agiles": PaumesJumelles,
	&"sub_s_brouillage_par_insectes": BrouillageInsectes,
	&"sub_s_128_poings_du_hakke": CentVingtHuitPoings,
	&"sub_s_formation_des_verrous_psychiques": HuitPortes,
}

const GATE := Color(0.4, 1.0, 0.4)
const HAKKE := Color(0.7, 0.8, 1.0)


## Sept cieux : respiration contrôlée — soigne, booste attaque et vitesse.
class SeptCieux extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.4
		a.anim = &"breath"

	func cast(t: Tk) -> void:
		t.fx("wave", t.origin, 2.0, Color(1.0, 0.9, 0.5))
		t.heal(t.caster, t.dmg(1.5))
		t.buff("sept_cieux", 12.0, {"damage_dealt": 1.3, "speed": 1.25, "label": "Sept cieux", "color": Color(1.0, 0.9, 0.5)})


## Porte de la Rétention : retire une limite — PV (bouclier), attaque, vitesse.
class PorteRetention extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.3
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		t.fx("column", t.origin, 1.5, GATE)
		t.shield(t.caster, t.dmg(1.5), 12.0)
		t.buff("porte_retention", 12.0, {"damage_dealt": 1.35, "speed": 1.3, "label": "Porte ouverte", "color": GATE})


## Création et Renouveau : régénération totale de la cible alliée (ou soi) + purge.
class CreationRenouveau extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.35
		a.max_range = 8.0
		a.anim = &"heal"

	func cast(t: Tk) -> void:
		var target: CombatCharacter = t.caster
		for ally: CombatCharacter in t.allies_in(t.aim, 3.0, false):
			target = ally
			break
		t.fx("spheres", target.global_position, 2.0, Color(0.6, 0.4, 1.0))
		t.cleanse(target, true)
		t.heal(target, target.health.max_health)
		t.buff("creation_renouveau", 3.0, {"label": "Renouveau", "color": Color(0.6, 0.4, 1.0)})


## Garuda C4 : clone d'argile qui explose au bout d'un moment, assommant toute la zone.
class GarudaC4 extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.5
		a.max_range = 10.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var at: Vector3 = t.aim
		t.object(at, {"kind": "garuda_c4", "radius": 1.0, "lifetime": 2.0, "look": KitObject.Look.DECOY,
			"color": Color(0.95, 0.9, 0.75), "targetable": false,
			"on_expire": func(o: KitObject) -> void:
				var rt: Tk = t.refreshed()
				rt.fx("explosion", o.global_position, 6.0, Color(0.95, 0.9, 0.75))
				rt.area(o.global_position, 6.0, rt.dmg(1.8), {"stun": 2.0})})


## Paumes jumelles : bras de chakra, projection en avant, rafale de paumes qui scelle le chakra.
class PaumesJumelles extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.3
		a.recovery_time = 0.4
		a.max_range = 8.0
		a.anim = &"palm"

	func cast(t: Tk) -> void:
		var from: Vector3 = t.origin
		t.dash(6.0, t.dir, 0.2)
		var hits: Array[CombatCharacter] = t.line(7.5, 1.6, t.dmg(0.7), {"stun": 0.6}, from, t.dir)
		t.after(0.25, func(rt: Tk) -> void:
			for e: CombatCharacter in hits:
				if is_instance_valid(e) and rt.is_enemy(e):
					rt.fx("spheres", e.global_position, 1.5, HAKKE)
					rt.hit(e, rt.dmg(1.1), {"seal": 4.0, "push": 4.0, "push_from": rt.caster.global_position}))


## Brouillage par insectes : nuée qui confond les ennemis, réduit attaque et défense.
class BrouillageInsectes extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.35
		a.max_range = 12.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		t.fx("crows", t.aim, 5.0, Color(0.3, 0.35, 0.25))
		for e: CombatCharacter in t.area(t.aim, 5.0, t.dmg(0.4), {"genjutsu": 3.0}):
			t.debuff(e, "insectes", 8.0, {"damage_dealt": 0.7, "damage_taken": 1.3, "label": "Insectes",
				"color": Color(0.3, 0.35, 0.25)})
		t.buff("insectes_furtif", 6.0, {"label": "Indétectable", "color": Color(0.3, 0.35, 0.25)})


## 128 poings du Hakke : champ du Byakugan, enchaînement de frappes, scelle le chakra.
class CentVingtHuitPoings extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.3
		a.max_range = 5.0
		a.anim = &"palm"

	func cast(t: Tk) -> void:
		t.fx("ring", t.origin, 5.0, HAKKE)
		var trapped: Array[CombatCharacter] = t.area(t.origin, 5.0, t.dmg(0.2), {"stun": 2.2})
		t.channel(6, 0.3, func(ct: Tk, _i: int) -> void:
			for e: CombatCharacter in trapped:
				if is_instance_valid(e) and ct.is_enemy(e):
					ct.fx("sparks", e.global_position, 0.8, HAKKE)
					ct.hit(e, ct.dmg(0.22), {"stun": 0.4}),
			func(dt: Tk, _completed: bool) -> void:
				for e: CombatCharacter in trapped:
					if is_instance_valid(e) and dt.is_enemy(e):
						dt.hit(e, dt.dmg(0.4), {"seal": 4.0, "push": 4.0, "push_from": dt.origin}), 0.0)


## Huit portes : puissance immense (Éléphant du soir ×5 via recast, puis Gaï de la nuit),
## mais le lanceur s'effondre ensuite (épuisé).
class HuitPortes extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.5
		a.max_range = 12.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		t.fx("column", t.origin, 2.5, Color(1.0, 0.2, 0.2))
		t.buff("huit_portes", 10.0, {"damage_dealt": 1.6, "speed": 1.4, "tenacity": true, "label": "Huit portes",
			"color": Color(1.0, 0.2, 0.2),
			"on_end": func() -> void:
				if is_instance_valid(t.caster):
					var et: Tk = t.refreshed()
					et.status(et.caster, StatusController.Type.STUN, 3.0)
					et.text(et.caster, "ÉPUISÉ")})
		_elephant(t)
		_open(t, 4)

	func _open(t: Tk, left: int) -> void:
		t.recast(3.0, func(rt: Tk) -> void:
			if left > 0:
				_elephant(rt)
				_open(rt, left - 1)
			else:
				_gai(rt))

	## Éléphant du soir : poing à pression d'air en ligne.
	func _elephant(t: Tk) -> void:
		t.fx("wave", t.origin + t.dir * 3.0, 2.0, Color(1.0, 0.3, 0.3))
		t.line(10.0, 2.0, t.dmg(0.5), {"push": 3.0})

	## Gaï de la nuit : coup de pied dévastateur en ruée.
	func _gai(t: Tk) -> void:
		var from: Vector3 = t.origin
		t.dash(10.0, t.dir, 0.25)
		t.fx("explosion", t.caster.global_position, 2.5, Color(1.0, 0.2, 0.2))
		t.line(11.0, 2.0, t.dmg(2.2), {"push": 6.0, "unblockable": true}, from, t.dir)
