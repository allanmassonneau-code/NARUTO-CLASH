class_name MobCatalog
## Enemies of the hunting grounds, built in code (look, stats, kit). The XP
## they give is not here: the server reads it from ProgressionDatabase.mob_xp.

## id -> {name, hp, speed, scale, aggro}
const MOBS: Dictionary = {
	&"bandit": {"name": "Bandit", "hp": 70.0, "speed": 5.6, "scale": 1.0, "aggro": 9.0},
	&"bandit_thrower": {"name": "Lanceur de kunai", "hp": 60.0, "speed": 5.4, "scale": 1.0, "aggro": 11.0},
	&"rogue_ninja": {"name": "Ninja déserteur", "hp": 130.0, "speed": 6.4, "scale": 1.0, "aggro": 11.0},
	&"rogue_kunoichi": {"name": "Kunoichi déserteuse", "hp": 115.0, "speed": 6.9, "scale": 1.0, "aggro": 11.0},
	&"elite_missing_nin": {"name": "Nukenin d'élite", "hp": 230.0, "speed": 6.6, "scale": 1.08, "aggro": 12.0},
	&"ronin": {"name": "Samouraï renégat", "hp": 260.0, "speed": 6.0, "scale": 1.12, "aggro": 10.0},
	&"boss_akatsuki": {"name": "Membre de l'Akatsuki", "hp": 700.0, "speed": 6.8, "scale": 1.25, "aggro": 14.0},
}


static func build(mob_id: StringName) -> CharacterData:
	var info: Dictionary = MOBS[mob_id]
	var data := CharacterData.new()
	data.display_name = info.name
	data.short_name = info.name
	data.max_health = info.hp
	var movement := MovementData.new()
	movement.move_speed = info.speed
	movement.acceleration = 260.0
	movement.deceleration = 320.0
	data.movement = movement
	data.look = _look(mob_id)
	data.body_color = data.look.top
	match mob_id:
		&"bandit":
			data.lmb = _melee("Coup de couteau", 6.0, 0.14, &"slash")
		&"bandit_thrower":
			data.lmb = _melee("Coup de poing", 4.0, 0.12, &"jab")
			data.rmb = _projectile("Kunai", 7.0, 2.5, 10.0, Color(0.8, 0.8, 0.85))
		&"rogue_ninja":
			data.lmb = _melee("Taijutsu", 8.0, 0.1, &"hook")
			data.rmb = _projectile("Katon", 14.0, 5.0, 9.0, Color(1.0, 0.45, 0.1), &"katon")
			data.space = JutsuAbilityFactory.shunshin()
		&"rogue_kunoichi":
			data.lmb = _melee("Tantō", 8.0, 0.09, &"slash")
			data.rmb = _dash("Assaut", 12.0, 6.0)
			data.q = _projectile("Senbon", 6.0, 3.0, 9.0, Color(0.7, 0.9, 1.0))
		&"elite_missing_nin":
			data.lmb = _melee("Taijutsu", 10.0, 0.1, &"hook")
			data.rmb = _projectile("Raiton", 18.0, 5.0, 10.0, Color(0.6, 0.85, 1.0), &"chidori")
			data.q = _area("Doton", 20.0, 9.0, 2.6, Color(0.65, 0.5, 0.3))
			data.space = JutsuAbilityFactory.shunshin()
		&"ronin":
			data.lmb = _melee("Katana", 13.0, 0.16, &"slash", 2.6)
			data.rmb = _dash("Iaijutsu", 22.0, 7.0)
		&"boss_akatsuki":
			data.lmb = _melee("Kunai", 12.0, 0.1, &"slash")
			data.rmb = _projectile("Grande boule de feu", 24.0, 5.0, 11.0, Color(1.0, 0.4, 0.1), &"katon")
			data.q = _area("Dragon de foudre", 30.0, 10.0, 3.2, Color(0.6, 0.85, 1.0))
			data.e = _dash("Shunshin assassin", 18.0, 7.0)
			data.space = JutsuAbilityFactory.shunshin()
			data.launch_immune = true
	return data


static func _melee(name: String, damage: float, startup: float, anim: StringName, reach: float = 2.0) -> AbilityData:
	var a := AbilityData.new()
	a.display_name = name
	a.kind = AbilityData.Kind.MELEE_ARC
	a.color = Color(1.0, 0.7, 0.5)
	a.startup_time = startup
	a.active_time = 0.05
	a.recovery_time = 0.35
	a.max_range = reach
	a.arc_degrees = 100.0
	a.damage = damage
	a.lunge_distance = 0.4
	a.cast_move_multiplier = 0.4
	a.anim = anim
	a.cooldown = 0.4
	return a


static func _projectile(name: String, damage: float, cooldown: float, reach: float, color: Color, vfx: StringName = &"") -> AbilityData:
	var a := AbilityData.new()
	a.display_name = name
	a.kind = AbilityData.Kind.PROJECTILE
	a.color = color
	a.startup_time = 0.35
	a.recovery_time = 0.3
	a.cooldown = cooldown
	a.max_range = reach
	a.projectile_speed = 15.0
	a.hit_radius = 0.6
	a.damage = damage
	a.anim = &"throw"
	a.vfx = vfx
	a.cast_move_multiplier = 0.3
	return a


static func _dash(name: String, damage: float, distance: float) -> AbilityData:
	var a := AbilityData.new()
	a.display_name = name
	a.kind = AbilityData.Kind.DASH
	a.color = Color(1.0, 0.4, 0.4)
	a.startup_time = 0.35
	a.active_time = 0.2
	a.recovery_time = 0.35
	a.cooldown = 7.0
	a.dash_distance = distance
	a.hit_radius = 0.8
	a.damage = damage
	a.stun_duration = 0.3
	a.anim = &"dash"
	a.cast_move_multiplier = 0.3
	return a


static func _area(name: String, damage: float, cooldown: float, radius: float, color: Color) -> AbilityData:
	var a := AbilityData.new()
	a.display_name = name
	a.kind = AbilityData.Kind.GROUND_AREA
	a.color = color
	a.startup_time = 0.4
	a.recovery_time = 0.3
	a.cooldown = cooldown
	a.max_range = 8.0
	a.hit_radius = radius
	a.area_delay = 0.8
	a.damage = damage
	a.stun_duration = 0.4
	a.anim = &"seal"
	a.cast_move_multiplier = 0.3
	return a


static func _look(mob_id: StringName) -> ShinobiLook:
	var look := ShinobiLook.new()
	# SS creator avatar per mob type (same seed -> same outfit for every bandit, ronin...).
	look.ss_avatar = {"seed": absi(hash(String(mob_id))), "sex": "Female" if mob_id == &"rogue_kunoichi" else "Male"}
	look.headband = false
	match mob_id:
		&"bandit", &"bandit_thrower":
			look.top = Color(0.45, 0.32, 0.2)
			look.sleeves = Color(0.45, 0.32, 0.2)
			look.pants = Color(0.3, 0.25, 0.2)
			look.accent = Color(0.2, 0.15, 0.1)
			look.hair_color = Color(0.2, 0.15, 0.1)
			look.hair = ShinobiLook.Hair.SHORT
			look.mask = mob_id == &"bandit"
			look.weapon = ShinobiLook.Weapon.KUNAI
		&"rogue_ninja", &"rogue_kunoichi", &"elite_missing_nin":
			look.top = Color(0.18, 0.18, 0.22)
			look.sleeves = Color(0.18, 0.18, 0.22)
			look.pants = Color(0.12, 0.12, 0.15)
			look.accent = Color(0.5, 0.1, 0.1)
			look.headband = true
			look.mask = mob_id != &"rogue_kunoichi"
			look.hair = ShinobiLook.Hair.LONG if mob_id == &"rogue_kunoichi" else ShinobiLook.Hair.SPIKY
			look.hair_color = Color(0.5, 0.1, 0.4) if mob_id == &"rogue_kunoichi" else Color(0.15, 0.15, 0.2)
			look.flak_vest = mob_id == &"elite_missing_nin"
		&"ronin":
			look.top = Color(0.35, 0.15, 0.15)
			look.sleeves = Color(0.35, 0.15, 0.15)
			look.pants = Color(0.15, 0.12, 0.12)
			look.hair = ShinobiLook.Hair.PONYTAIL
			look.hair_color = Color(0.1, 0.1, 0.1)
			look.weapon = ShinobiLook.Weapon.SWORD
		&"boss_akatsuki":
			look.cloak = Color(0.08, 0.08, 0.1)
			look.cloak_pattern = &"clouds"
			look.hair = ShinobiLook.Hair.LONG
			look.hair_color = Color(0.1, 0.1, 0.12)
			look.eye_color = Color(0.85, 0.05, 0.05)
			look.headband = true
	return look
