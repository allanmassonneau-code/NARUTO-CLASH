extends RefCounted
## Technique kit: clan Senju — Tsunade's heel drop and Mokuton (wood release)
## jutsu from Shinobi Striker.

const KIT_ID := &"clan_senju"
const SIGNATURE = null
const TECHNIQUES := {
	&"clan_senju_d_coup_de_pied_marteau": CoupDePiedMarteau,
	&"clan_senju_c_etreinte_silencieuse": EtreinteSilencieuse,
	&"clan_senju_b_enceinte_de_bois": EnceinteDeBois,
	&"clan_senju_a_dragon_de_bois": DragonDeBois,
	&"clan_senju_s_croissance_luxuriante_de_la_foret": CroissanceLuxuriante,
}

const WOOD := Color(0.55, 0.4, 0.2)


## D — Heavenly Kick of Pain: chakra heel drop; stuns enemies around,
## blocks their substitution (seal), raises the caster's defence.
class CoupDePiedMarteau extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.3
		a.recovery_time = 0.3
		a.max_range = 4.0
		a.anim = &"stomp"

	func cast(t: Tk) -> void:
		t.dash(2.0, t.dir, 0.12)
		t.after(0.13, func(rt: Tk) -> void:
			var at: Vector3 = rt.caster.global_position + rt.dir * 0.8
			rt.fx("cracks", at, 2.5)
			rt.area(at, 2.5, rt.dmg(1.0), {"stun": 0.7, "seal": 2.0})
			rt.buff("talon_defense", 5.0, {"damage_taken": 0.8, "label": "Défense +", "color": WOOD}))


## C — Mokuton Silent Strangle: branches root the target until timeout or
## until it is hit, then its attack power is lowered.
class EtreinteSilencieuse extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.25
		a.recovery_time = 0.25
		a.max_range = 10.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		t.projectile({"speed": 18.0, "range": 10.0, "radius": 0.7, "size": 0.25, "color": WOOD,
			"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
				t.hit(e, t.dmg(0.5), {"root": 2.5})
				t.fx("spikes", e.global_position, 1.2, WOOD)
				t.debuff(e, "etreinte", 6.0, {"damage_dealt": 0.75, "label": "Attaque -", "color": WOOD})
				return false})


## B — Mokuton Domed Wall: wooden wall that blocks projectiles and movement,
## breaks after some damage; enemies caught as it grows take damage.
class EnceinteDeBois extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.2
		a.recovery_time = 0.25
		a.max_range = 3.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var at: Vector3 = t.origin + t.dir * 2.0
		t.fx("spikes", at, 2.5, WOOD)
		t.area(at, 2.2, t.dmg(1.0), {"push": 2.0, "push_from": t.origin})
		t.wall(at, t.dir.cross(Vector3.UP), 5.0, 8.0, {"kind": "mur_bois", "health": 80.0, "color": WOOD,
			"blocks_projectiles": true, "blocks_movement": true})


## A — Mokuton Wood Dragon: a dragon rushes through targets, drains their
## secret gauge (chakra/silence), lifesteal, reduces its own cooldown.
class DragonDeBois extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.4
		a.recovery_time = 0.3
		a.max_range = 16.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		t.fx("rocks", t.origin + t.dir, 1.5, WOOD)
		t.projectile({"speed": 16.0, "range": 16.0, "radius": 1.3, "pierce": true, "size": 0.7, "color": WOOD,
			"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
				var d: float = t.dmg(0.8)
				t.hit(e, d, {"root": 1.0, "silence": 1.0})
				t.heal(t.caster, d * 0.5)
				t.text(e, "ABSORBÉ")
				return true})


## S (ultime SS) — Mokuton Deep Forest Emergence: trees burst out in a wide
## area; enemies hit are paralysed then have their defence lowered.
class CroissanceLuxuriante extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.45
		a.recovery_time = 0.4
		a.max_range = 10.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var at: Vector3 = t.aim
		t.telegraph(at, 5.0, 0.4, func(rt: Tk) -> void:
			rt.fx("spikes", at, 5.0, WOOD)
			for e: CombatCharacter in rt.area(at, 5.0, rt.dmg(1.4), {"stun": 2.0, "launch": 0.4}):
				rt.debuff(e, "foret", 7.0, {"damage_taken": 1.25, "label": "Défense -", "color": WOOD})
			rt.zone(at, 5.0, 4.0, {"kind": "foret", "tick_interval": 0.5, "targetable": false, "color": WOOD,
				"on_tick": func(o: KitObject) -> void:
					for e: CombatCharacter in o.enemies_inside():
						rt.hit(e, rt.dmg(0.08), {"slow": 0.6})}))
