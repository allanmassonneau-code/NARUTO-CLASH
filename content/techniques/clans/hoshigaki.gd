extends RefCounted
## Kit clan_hoshigaki (requins) — jutsu Shinobi Striker de Kisame : Requin
## élémentaire aqueux, Voyage souterrain, Pilier d'eau, Déploiement aqueux fatal,
## Grand requin aqueux.

const KIT_ID := &"clan_hoshigaki"
const SIGNATURE = null
const TECHNIQUES := {
	&"clan_hoshigaki_d_requin_elementaire_aqueux": RequinElementaire,
	&"clan_hoshigaki_c_voyage_souterrain": VoyageSouterrain,
	&"clan_hoshigaki_b_pilier_d_eau": PilierDEau,
	&"clan_hoshigaki_a_jutsu_secret_deploiement_aqueux_fatal": DeploiementAqueuxFatal,
	&"clan_hoshigaki_s_grand_requin_aqueux": GrandRequin,
}

const WATER := Color(0.25, 0.55, 1.0)
const ICE := Color(0.75, 0.92, 1.0)


## D — Ranged (SS 1/5). Trois requins d'eau tournent autour du lanceur puis
## filent vers la cible ; à l'impact, réduisent les ninjutsu (silence).
class RequinElementaire extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.2
		a.recovery_time = 0.25
		a.max_range = 16.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		t.fx("ring", t.origin, 1.5, WATER)
		var target: CombatCharacter = t.target_at_aim(4.0)
		for i in 3:
			t.after(0.15 + 0.12 * i, func(rt: Tk) -> void:
				var side: Vector3 = rt.dir.rotated(Vector3.UP, deg_to_rad(-90.0 + 90.0 * i))
				var opts: Dictionary = {"from": rt.origin + side * 1.2, "dir": rt.dir, "speed": 22.0, "range": 17.0,
					"radius": 0.55, "size": 0.3, "homing": 3.0, "color": WATER,
					"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
						rt.hit(e, rt.dmg(0.2), {"silence": 1.0})
						rt.fx("burst", e.global_position, 0.6, WATER)
						return false}
				if is_instance_valid(target) and rt.is_enemy(target):
					opts["homing_target"] = target
				rt.projectile(opts))


## C — Technical (SS 0/0). Liquéfie le sol et s'y glisse : intouchable et
## régénère, mais ne peut pas attaquer (silence sur soi) ; ressort plus loin.
class VoyageSouterrain extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.15
		a.recovery_time = 0.2
		a.max_range = 8.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		t.fx("cracks", t.origin, 1.5, WATER)
		var max_hp: float = t.dmg(1.0)
		t.buff("voyage_souterrain", 2.5, {"untargetable": true, "speed": 1.35, "label": "Sous terre", "color": WATER,
			"on_take": func(_hit: HitData, _d: float) -> float: return 0.0})
		t.status(t.caster, StatusController.Type.SILENCE, 2.5)
		t.channel(5, 0.5, func(ct: Tk, _i: int) -> void:
			ct.heal(ct.caster, max_hp * 0.3), func(ct: Tk, _done: bool) -> void:
				ct.fx("burst", ct.caster.global_position, 1.2, WATER), 1.3)


## B — Technical (SS 2/1). Colonne d'eau sur soi : bloque les projectiles,
## soulève les ennemis touchés à l'apparition ; recast → Dragon aqueux.
class PilierDEau extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.2
		a.recovery_time = 0.25
		a.max_range = 3.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		t.fx("column", t.origin, 2.0, WATER)
		t.area(t.origin, 2.2, t.dmg(0.8), {"launch": 0.8})
		t.object(t.origin, {"kind": "pilier_eau", "radius": 2.0, "lifetime": 3.0, "look": KitObject.Look.PILLAR,
			"color": WATER, "health": -1, "targetable": false, "blocks_projectiles": true})
		t.buff("pilier_eau", 3.0, {"damage_taken": 0.5, "label": "Pilier d'eau", "color": WATER})
		t.recast(3.0, func(rt: Tk) -> void:
			for o: KitObject in rt.objects("pilier_eau"):
				o.destroy("recast")
			rt.projectile({"speed": 20.0, "range": 16.0, "radius": 1.1, "size": 0.7, "pierce": true, "color": WATER,
				"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
					rt.hit(e, rt.dmg(0.6), {"slow": 2.0})
					return true}))


## A — Ranged (SS 2/1). Flaque d'eau sous soi : emprisonne les ennemis proches,
## éclats de glace, scelle les ninjutsu et augmente les dégâts subis.
class DeploiementAqueuxFatal extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.3
		a.recovery_time = 0.3
		a.max_range = 4.0
		a.anim = &"stomp"

	func cast(t: Tk) -> void:
		t.fx("wave", t.origin, 3.5, WATER)
		t.zone(t.origin, 3.5, 1.5, {"kind": "flaque", "color": WATER, "targetable": false})
		for e: CombatCharacter in t.area(t.origin, 3.5, t.dmg(0.4), {"root": 1.5}):
			t.debuff(e, "deploiement_fatal", 4.0, {"damage_taken": 1.2, "label": "Vulnérable", "color": ICE})
		t.after(0.6, func(rt: Tk) -> void:
			rt.fx("spikes", rt.origin, 3.5, ICE)
			rt.area(rt.origin, 3.5, rt.dmg(0.45), {"seal": 3.0}))


## S — Ranged / FinishMove (SS 5/5). Gigantesque requin d'eau : traverse tout,
## lourds dégâts, explosion à l'arrivée, scelle les ninjutsu.
class GrandRequin extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.55
		a.recovery_time = 0.4
		a.cast_move_multiplier = 0.1
		a.max_range = 20.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		t.projectile({"speed": 15.0, "range": 20.0, "radius": 2.0, "size": 1.4, "pierce": true, "color": WATER,
			"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
				t.hit(e, t.dmg(1.3), {"seal": 3.0, "push": 3.0, "push_from": t.origin})
				t.fx("explosion", e.global_position, 1.5, WATER)
				return true,
			"on_end": func(point: Vector3, _p: TkProjectile, _reason: String) -> void:
				t.fx("wave", point, 3.5, WATER)
				t.area(point, 3.5, t.dmg(0.5), {"slow": 2.0})})
