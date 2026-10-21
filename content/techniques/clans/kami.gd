extends RefCounted
## Kit clan Kami (Shinobi Striker) : papier de Konan et encre de Sai.

const KIT_ID := &"clan_kami"
const SIGNATURE = null
const TECHNIQUES := {
	&"clan_kami_d_toile_aux_monstres_fantomatiques_lion": ToileLion,
	&"clan_kami_c_danse_du_shikigami_bouclier": ShikigamiBouclier,
	&"clan_kami_b_toile_aux_monstres_fantomatiques_oiseau": ToileOiseau,
	&"clan_kami_a_apparition_angelique": ApparitionAngelique,
	&"clan_kami_s_danse_du_shikigami_tempete": ShikigamiTempete,
}

const INK := Color(0.1, 0.1, 0.15)
const PAPER := Color(0.95, 0.93, 0.85)


## D — Deux lions d'encre chargent la cible : dégâts et ralentissement.
class ToileLion extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.25
		a.recovery_time = 0.25
		a.max_range = 15.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var target: CombatCharacter = t.target_at_aim(3.0)
		for i in 2:
			t.projectile({"dir": t.dir.rotated(Vector3.UP, deg_to_rad(-10.0 + 20.0 * i)), "speed": 17.0, "range": 15.0,
				"radius": 0.7, "size": 0.4, "color": INK, "homing": 2.5, "homing_target": target,
				"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
					t.hit(e, t.dmg(0.4), {"slow": 2.0})
					t.fx("smoke", e.global_position, 0.8, INK)
					return false})


## C — Mur de papier qui avance : bloque les projectiles, paralyse les
## cibles touchées et réduit leurs soins.
class ShikigamiBouclier extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.2
		a.recovery_time = 0.25
		a.max_range = 9.0
		a.anim = &"palm"

	func cast(t: Tk) -> void:
		var side: Vector3 = t.dir.rotated(Vector3.UP, PI / 2.0)
		var wall: KitObject = t.wall(t.origin + t.dir * 1.5, side, 4.0, 2.5, {"kind": "mur_papier", "color": PAPER,
			"blocks_projectiles": true, "health": 80.0})
		var struck: Dictionary = {}
		t.channel(6, 0.15, func(ct: Tk, i: int) -> void:
			var at: Vector3 = ct.origin + ct.dir * (1.5 + 1.3 * (i + 1))
			if is_instance_valid(wall) and wall.is_alive():
				wall.global_position = at
			ct.fx("burst", at, 1.0, PAPER)
			for e: CombatCharacter in ct.enemies_in_line(at - side * 2.0, side, 4.0, 1.2):
				if not struck.has(e.get_instance_id()):
					struck[e.get_instance_id()] = true
					ct.hit(e, ct.dmg(0.5), {"stun": 1.0})
					ct.debuff(e, "papier_antisoin", 4.0, {"heal_taken": 0.5, "label": "Soins réduits", "color": PAPER}), Callable(), 0.6)


## B — Oiseau d'encre : capture la cible et l'emporte dans les airs,
## obstruction d'encre (sceau).
class ToileOiseau extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.25
		a.recovery_time = 0.3
		a.max_range = 11.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		t.projectile({"speed": 20.0, "range": 11.0, "radius": 0.8, "size": 0.45, "color": INK, "homing": 2.0,
			"homing_target": t.target_at_aim(3.0),
			"on_hit": func(e: CombatCharacter, _p: TkProjectile) -> bool:
				t.hit(e, t.dmg(0.8), {"launch": 1.2, "seal": 2.5})
				t.debuff(e, "obstruction_encre", 3.0, {"speed": 0.8, "label": "Encre", "color": INK})
				t.fx("crows", e.global_position, 1.2, INK)
				return false})


## A — Ailes de papier : lévitation (vitesse, insaisissable au sol) et
## recharge des outils ninja (un bouclier de papier symbolise le regain).
class ApparitionAngelique extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.2
		a.recovery_time = 0.2
		a.max_range = 1.0
		a.anim = &"leap"

	func cast(t: Tk) -> void:
		t.fx("burst", t.origin, 2.0, PAPER)
		t.text(t.caster, "ENVOL")
		t.buff("ailes_papier", 6.0, {"speed": 1.35, "tenacity": true, "label": "Ailes de papier", "color": PAPER})
		t.shield(t.caster, t.dmg(1.0), 6.0)


## S — Tempête de papier sur une large zone : scelle ninjutsu et techniques
## secrètes, entaille les cibles en continu.
class ShikigamiTempete extends Technique:
	func configure(a: AbilityData) -> void:
		a.startup_time = 0.4
		a.recovery_time = 0.4
		a.max_range = 12.0
		a.anim = &"seal"

	func cast(t: Tk) -> void:
		var at: Vector3 = t.aim
		t.fx("wave", at, 7.0, PAPER)
		t.area(at, 7.0, t.dmg(0.5), {"seal": 4.0, "silence": 2.0})
		t.zone(at, 7.0, 4.0, {"kind": "tempete_papier", "look": KitObject.Look.RING, "tick_interval": 0.5,
			"targetable": false, "color": PAPER,
			"on_tick": func(o: KitObject) -> void:
				t.fx("sparks", o.global_position, 6.0, PAPER)
				for e: CombatCharacter in o.enemies_inside():
					t.hit(e, t.dmg(0.15), {"seal": 1.0})})
