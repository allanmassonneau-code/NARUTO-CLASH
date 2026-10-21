extends RefCounted
## Kit clan Fûma (Shinobi Striker) : shurikens géants, armes et parchemins.

const KIT_ID := &"clan_fuma"
const SIGNATURE = null
const TECHNIQUES := {
	&"clan_fuma_d_technique_des_shurikens_uchiwa_oboroguru": Oboroguruma,
	&"clan_fuma_c_bombe_du_moulin_d_ombre": BombeMoulinOmbre,
	&"clan_fuma_b_bruine_pourpre": BruinePourpre,
	&"clan_fuma_a_gardien_d_aiguilles": GardienAiguilles,
	&"clan_fuma_s_parchemins_explosifs_autorepliquants": ParcheminsAutorepliquants,
}

const STEEL := Color(0.75, 0.78, 0.85)


## D — Moulin d'ombre lancé loin (scelle les ninjutsu), rappel au recast ;
## buff de vitesse au lancer.
class Oboroguruma extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.15
		a.recovery_time = 0.2
		a.max_range = 16.0
		a.anim = &"throw"

	func cast(t: Tk) -> void:
		t.buff("oboroguruma", 4.0, {"speed": 1.2, "label": "Oboroguruma", "color": STEEL})
		var hit_once: Dictionary = {}
		var sh: TkProjectile = t.projectile({"speed": 22.0, "range": 16.0, "radius": 0.8, "pierce": true, "size": 0.45,
			"color": STEEL,
			"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
				if not hit_once.has(e.get_instance_id()):
					hit_once[e.get_instance_id()] = true
					t.hit(e, t.dmg(0.5), {"seal": 2.0})
				return true})
		t.recast(2.5, func(rt: Tk) -> void:
			if not is_instance_valid(sh) or not sh.is_alive():
				return
			var at: Vector3 = sh.ground_point()
			sh.end("recast")
			var back: Vector3 = HitQuery.flat(rt.caster.global_position - at)
			if back.length() < 0.5:
				return
			rt.projectile({"from": at, "dir": back.normalized(), "speed": 24.0, "range": back.length(), "radius": 0.8,
				"pierce": true, "size": 0.45, "color": STEEL,
				"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
					rt.hit(e, rt.dmg(0.3), {"seal": 1.5})
					return true}))


## C — Le lanceur devient un shuriken qui tournoie en avançant (dégâts
## multiples) ; recast : il reprend forme avec un coup de pied.
class BombeMoulinOmbre extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.2
		a.recovery_time = 0.25
		a.max_range = 7.0
		a.anim = &"dash"

	func cast(t: Tk) -> void:
		t.fx("ring", t.origin, 1.5, STEEL)
		t.dash(6.0, t.dir, 0.5, true)
		t.channel(4, 0.12, func(ct: Tk, _i: int) -> void:
			ct.fx("sparks", ct.caster.global_position, 1.4, STEEL)
			ct.area(ct.caster.global_position, 1.6, ct.dmg(0.15)), Callable(), 1.0)
		t.recast(2.0, func(rt: Tk) -> void:
			rt.fx("burst", rt.origin + rt.dir, 1.2)
			rt.melee(2.2, 120.0, rt.dmg(0.35), {"push": 3.0}))


## B — Frappe de shuriken : dégâts autour, l'onde de choc paralyse les
## autres cibles à portée ; buff d'attaque.
class BruinePourpre extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.2
		a.recovery_time = 0.3
		a.max_range = 3.0
		a.anim = &"slash"

	func cast(t: Tk) -> void:
		t.buff("bruine_pourpre", 6.0, {"damage_dealt": 1.15, "label": "Bruine pourpre", "color": Color(0.9, 0.2, 0.3)})
		t.fx("wave", t.origin, 4.0, Color(0.9, 0.2, 0.3))
		var direct: Array[CombatCharacter] = t.melee(2.5, 140.0, t.dmg(0.8))
		for e: CombatCharacter in t.enemies_in(t.origin, 4.5):
			if not direct.has(e):
				t.hit(e, t.dmg(0.2), {"stun": 1.0})


## A — Cheveux durcis : forte réduction des dégâts subis, les aiguilles
## frappent les ennemis proches et réduisent leurs soins.
class GardienAiguilles extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.25
		a.recovery_time = 0.2
		a.max_range = 3.0
		a.anim = &"guard"

	func cast(t: Tk) -> void:
		t.buff("gardien_aiguilles", 3.0, {"damage_taken": 0.3, "label": "Gardien d'aiguilles", "color": STEEL})
		t.channel(5, 0.5, func(ct: Tk, _i: int) -> void:
			ct.fx("spikes", ct.caster.global_position, 2.5, STEEL)
			for e: CombatCharacter in ct.area(ct.caster.global_position, 2.8, ct.dmg(0.2)):
				ct.debuff(e, "aiguilles_antisoin", 4.0, {"heal_taken": 0.5, "label": "Soins réduits", "color": STEEL}), Callable(), 0.5)


## S — Parchemin explosif piège posé au sol : à l'approche d'un ennemi il se
## réplique et explose en chaîne.
class ParcheminsAutorepliquants extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.3
		a.recovery_time = 0.3
		a.max_range = 6.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var trap: KitObject = t.object(t.aim, {"kind": "parchemin", "radius": 2.0, "lifetime": 10.0, "look": KitObject.Look.GLYPH,
			"targetable": false, "color": Color(1.0, 0.85, 0.5),
			"on_enter": func(f: CombatCharacter, o: KitObject) -> void:
				if t.is_enemy(f) and not o.data.get("fired", false):
					o.data["fired"] = true
					_chain(t.refreshed(), o.global_position)
					o.destroy("detonated")})
		trap.data["fired"] = false
		# Déjà au contact : détonation immédiate.
		if not t.enemies_in(t.aim, 2.0).is_empty():
			trap.data["fired"] = true
			_chain(t, t.aim)
			trap.destroy("detonated")

	func _chain(t: Tk, at: Vector3) -> void:
		t.fx("explosion", at, 2.2)
		t.area(at, 2.5, t.dmg(0.8), {"push": 1.5})
		for i in 4:
			var off: Vector3 = Vector3(cos(TAU * i / 4.0), 0.0, sin(TAU * i / 4.0)) * 2.2
			t.after(0.2 + 0.15 * i, func(rt: Tk) -> void:
				rt.fx("explosion", at + off, 1.6)
				rt.area(at + off, 2.0, rt.dmg(0.3)))
