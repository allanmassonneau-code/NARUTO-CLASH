extends RefCounted
## Technique kit: Épéistes de la Brume — vrais jutsu de Shinobi Striker.

const KIT_ID := &"clan_epeistes"
const SIGNATURE = null
const TECHNIQUES := {
	&"clan_epeistes_d_chasseur_de_demons": ChasseurDeDemons,
	&"clan_epeistes_c_estocade_fulgurante": EstocadeFulgurante,
	&"clan_epeistes_b_danse_de_la_clematite": DanseDeLaClematite,
	&"clan_epeistes_a_camouflage_dans_la_brume": CamouflageDansLaBrume,
	&"clan_epeistes_s_totsukatsu": Totsukatsu,
}

const MIST := Color(0.75, 0.85, 0.95)


## D — Chasseur de démons : aura démoniaque (ténacité + vol de vie), puis
## taille ascendante chargée qui projette en l'air.
class ChasseurDeDemons extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.35
		a.recovery_time = 0.3
		a.cast_move_multiplier = 0.3
		a.max_range = 3.0
		a.anim = &"slash"

	func cast(t: Tk) -> void:
		t.buff("aura_demoniaque", 6.0, {"tenacity": true, "lifesteal": 0.3, "label": "Aura démoniaque",
			"color": Color(0.6, 0.1, 0.2)})
		t.fx("burst", t.origin, 1.5, Color(0.6, 0.1, 0.2))
		for e: CombatCharacter in t.melee(3.0, 110.0, t.dmg(0.8)):
			t.launch(e, 0.7)


## C — Estocade fulgurante : ruée qui empale, puis coup vertical.
class EstocadeFulgurante extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.15
		a.recovery_time = 0.3
		a.max_range = 5.0
		a.anim = &"thrust"

	func cast(t: Tk) -> void:
		var from: Vector3 = t.origin
		t.dash(4.5, t.dir, 0.15)
		var hits: Array[CombatCharacter] = t.line(5.0, 1.0, t.dmg(0.4), {"stun": 0.4}, from, t.dir)
		t.after(0.25, func(rt: Tk) -> void:
			for e: CombatCharacter in hits:
				if is_instance_valid(e) and rt.is_enemy(e):
					rt.fx("spikes", e.global_position, 0.8)
					rt.hit(e, rt.dmg(0.45), {"launch": 0.5}))


## B — Danse de la Clématite : fouet vertébral en zone autour du lanceur ;
## recast (sans direction) = charge en avant avec la lance osseuse.
class DanseDeLaClematite extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.25
		a.recovery_time = 0.3
		a.max_range = 6.0
		a.anim = &"slash"

	func cast(t: Tk) -> void:
		t.fx("wave", t.origin, 3.5, Color(0.95, 0.92, 0.85))
		t.area(t.origin, 3.5, t.dmg(0.7), {"push": 1.5, "push_from": t.origin})
		t.recast(2.0, func(rt: Tk) -> void:
			var from: Vector3 = rt.origin
			rt.dash(6.0, rt.dir, 0.2)
			rt.fx("spikes", rt.caster.global_position, 1.2, Color(0.95, 0.92, 0.85))
			rt.line(6.5, 1.2, rt.dmg(0.6), {"push": 2.5}, from, rt.dir))


## A — Camouflage dans la brume (ultime) : brouillard aveuglant sur une large
## zone (ralentit, scelle la permutation ~ root bref + silence) ; alliés
## accélérés, lanceur renforcé.
class CamouflageDansLaBrume extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.3
		a.max_range = 10.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var center: Vector3 = t.origin
		t.fx("smoke", center, 9.0, MIST)
		t.buff("brume_force", 8.0, {"damage_dealt": 1.3, "label": "Brume", "color": MIST})
		for ally: CombatCharacter in t.allies_in(center, 9.0, false):
			t.status(ally, StatusController.Type.HASTE, 6.0)
		t.zone(center, 9.0, 8.0, {"kind": "brume", "color": MIST, "targetable": false, "tick_interval": 0.5,
			"on_tick": func(o: KitObject) -> void:
				for e: CombatCharacter in o.enemies_inside():
					t.debuff(e, "aveugle_brume", 0.7, {"speed": 0.6, "damage_dealt": 0.85, "label": "Brouillard",
						"color": MIST})})
		for e: CombatCharacter in t.enemies_in(center, 9.0):
			t.hit(e, 0.0, {"slow": 3.0, "silence": 1.0})


## S — Totsukatsu (ultime) : Susanô abat l'épée de Totsuka, onde de choc qui
## avance et repousse tout sur son passage.
class Totsukatsu extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.6
		a.recovery_time = 0.5
		a.cast_move_multiplier = 0.0
		a.max_range = 16.0
		a.anim = &"slash"

	func cast(t: Tk) -> void:
		t.fx("column", t.origin + t.dir * 2.0, 2.0, Color(0.9, 0.3, 0.3))
		t.area(t.origin + t.dir * 2.5, 2.5, t.dmg(0.8), {"stun": 0.5})
		t.projectile({"speed": 16.0, "range": 16.0, "radius": 1.6, "pierce": true, "size": 0.9,
			"color": Color(0.9, 0.3, 0.3),
			"on_hit": func(e: CombatCharacter, p: TkProjectile) -> bool:
				t.hit(e, t.dmg(1.1), {"push": 5.0, "push_from": p.global_position - p.direction})
				return true})
