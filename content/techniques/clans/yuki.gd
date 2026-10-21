extends RefCounted
## Kit clan_yuki (glace) — jutsu Shinobi Striker de Haku : Vol de glace,
## Pétrification, Déploiement aqueux fatal, Camouflage dans la brume,
## Démoniaques miroirs de glace.

const KIT_ID := &"clan_yuki"
const SIGNATURE = null
const TECHNIQUES := {
	&"clan_yuki_d_vol_de_glace": VolDeGlace,
	&"clan_yuki_c_petrification": Petrification,
	&"clan_yuki_b_jutsu_secret_deploiement_aqueux_fatal": DeploiementAqueuxFatal,
	&"clan_yuki_a_camouflage_dans_la_brume": CamouflageBrume,
	&"clan_yuki_s_jutsu_secret_demoniaques_miroirs_de_glac": MiroirsDeGlace,
}

const ICE := Color(0.75, 0.92, 1.0)
const MIST := Color(0.8, 0.85, 0.9)


## D — Ranged (SS 1/2). Éventail d'aiguilles de glace : gèle (ralentit),
## rend vulnérable ; le lanceur gagne un bonus d'esquive.
class VolDeGlace extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.15
		a.recovery_time = 0.2
		a.max_range = 9.0
		a.anim = &"throw"

	func cast(t: Tk) -> void:
		t.buff("vol_de_glace_esquive", 1.5, {"damage_taken": 0.7, "speed": 1.2, "label": "Esquive", "color": ICE})
		for i in 5:
			var d: Vector3 = t.dir.rotated(Vector3.UP, deg_to_rad(-20.0 + 10.0 * i))
			t.projectile({"dir": d, "speed": 28.0, "range": 9.0, "radius": 0.35, "size": 0.12, "color": ICE,
				"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
					t.hit(e, t.dmg(0.13), {"slow": 1.5})
					t.mark(e, "gel", 1, 4.0, 1, "Gel")
					t.debuff(e, "glace_vulnerable", 3.0, {"damage_taken": 1.1, "label": "Gelé", "color": ICE})
					return false})


## C — Technical (SS 0/4). Paralysie temporaire : la cible ne peut plus bouger ;
## sur « critique » (cible déjà ralentie / gelée) paralysie totale.
class Petrification extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.25
		a.recovery_time = 0.25
		a.max_range = 14.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var e: CombatCharacter = t.target_at_aim(3.0)
		if e == null:
			e = t.nearest_enemy(t.aim, 4.0)
		if e == null:
			t.fx("ring", t.aim, 1.5, ICE)
			return
		var crit: bool = t.consume_mark(e, "gel") > 0
		if crit or randf() < 0.25:
			t.hit(e, t.dmg(0.1), {"stun": 1.5, "seal": 1.5, "unblockable": true})
			t.text(e, "PARALYSÉ")
		else:
			t.hit(e, t.dmg(0.1), {"root": 2.0, "unblockable": true})
		t.fx("implosion", e.global_position, 1.0, ICE)


## B — Ranged (SS 2/1). Flaque sous soi qui emprisonne, éclats de glace,
## scelle les ninjutsu et augmente les dégâts subis.
class DeploiementAqueuxFatal extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.3
		a.recovery_time = 0.3
		a.max_range = 4.0
		a.anim = &"stomp"

	func cast(t: Tk) -> void:
		t.fx("wave", t.origin, 3.2, Color(0.3, 0.6, 1.0))
		for e: CombatCharacter in t.area(t.origin, 3.2, t.dmg(0.3), {"root": 1.2}):
			t.debuff(e, "yuki_deploiement", 4.0, {"damage_taken": 1.2, "label": "Vulnérable", "color": ICE})
		t.after(0.5, func(rt: Tk) -> void:
			rt.fx("spikes", rt.origin, 3.2, ICE)
			rt.area(rt.origin, 3.2, rt.dmg(0.5), {"seal": 2.5}))


## A — Technical (SS 0/5). Brume épaisse : ennemis aveuglés (ralentis, sans
## permutation), alliés plus rapides, lanceur plus puissant.
class CamouflageBrume extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.3
		a.recovery_time = 0.3
		a.max_range = 6.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		t.fx("smoke", t.origin, 7.0, MIST)
		t.buff("brume_puissance", 8.0, {"damage_dealt": 1.25, "label": "Brume", "color": MIST})
		t.zone(t.origin, 7.0, 8.0, {"kind": "brume", "color": MIST, "targetable": false, "tick_interval": 0.5,
			"on_tick": func(o: KitObject) -> void:
				for e: CombatCharacter in o.enemies_inside():
					if t.is_enemy(e):
						t.status(e, StatusController.Type.SLOW, 0.7)
						t.debuff(e, "brume_aveugle", 0.7, {"damage_dealt": 0.8, "label": "Aveuglé", "color": MIST})
				for f: CombatCharacter in o.allies_inside():
					if is_instance_valid(f):
						t.status(f, StatusController.Type.HASTE, 0.7)})
		for e: CombatCharacter in t.enemies_in(t.origin, 7.0):
			t.hit(e, 0.0, {"seal": 3.0, "slow": 2.0})


## S — Ranged / FinishMove (SS 5/1). Dôme de miroirs autour de la cible :
## l'enferme puis des frappes rapides jaillissent des miroirs ; anti-soin.
class MiroirsDeGlace extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.4
		a.recovery_time = 0.4
		a.cast_move_multiplier = 0.0
		a.max_range = 7.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var target: CombatCharacter = t.target_at_aim(3.0)
		if target == null:
			target = t.nearest_enemy(t.origin, 7.0)
		var center: Vector3 = t.aim if target == null else HitQuery.flat(target.global_position)
		t.fx("spheres", center, 3.0, ICE)
		t.object(center, {"kind": "miroirs", "radius": 3.0, "lifetime": 3.2, "look": KitObject.Look.RING,
			"color": ICE, "targetable": false, "blocks_movement": true})
		for e: CombatCharacter in t.enemies_in(center, 3.0):
			t.hit(e, t.dmg(0.1), {"root": 3.0})
			t.debuff(e, "miroirs_anti_soin", 6.0, {"damage_taken": 1.15, "heal_taken": 0.5, "label": "Anti-soin", "color": ICE})
		t.channel(8, 0.35, func(ct: Tk, i: int) -> void:
			var from: Vector3 = center + Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 8.0) * 3.0
			ct.fx("sparks", from, 0.6, ICE)
			for e: CombatCharacter in ct.enemies_in(center, 3.2):
				if is_instance_valid(e) and ct.is_enemy(e):
					ct.hit(e, ct.dmg(0.22 if i < 7 else 0.4), {"root": 0.5}), Callable(), 0.0)
