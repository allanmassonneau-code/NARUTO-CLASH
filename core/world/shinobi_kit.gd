class_name ShinobiKit
## Builds the combat definition (CharacterData) of the player's shinobi from
## the progression profile: grade + Tenketsu HP and speed, look from the
## village / clan, LMB taijutsu, Space shunshin, and the equipped techniques
## on the keys 1 to 6.

const JUTSU_SLOTS: Array[StringName] = [&"j1", &"j2", &"j3", &"j4", &"j5", &"j6"]
const VILLAGE_COLORS: Dictionary = {
	&"konoha": [Color(0.32, 0.42, 0.28), Color(0.15, 0.2, 0.3)],
	&"suna": [Color(0.7, 0.6, 0.42), Color(0.45, 0.35, 0.25)],
	&"ame": [Color(0.35, 0.36, 0.42), Color(0.2, 0.18, 0.28)],
	&"kiri": [Color(0.3, 0.45, 0.6), Color(0.15, 0.2, 0.32)],
}


static func build(profile: CharacterProfile, db: ProgressionDatabase, service: ProgressionService) -> CharacterData:
	var data := CharacterData.new()
	data.display_name = profile.character_name
	data.short_name = profile.character_name
	data.max_health = service.max_resources(profile).hp
	var movement := MovementData.new()
	var bonus: Dictionary = service.tenketsu.stat_bonuses(profile)
	movement.move_speed = 7.0 * (1.0 + float(bonus.get(&"mobility", 0.0)))
	movement.acceleration = 300.0
	movement.deceleration = 360.0
	data.movement = movement
	data.look = look_for(profile)
	data.body_color = data.look.top
	data.lmb = JutsuAbilityFactory.taijutsu()
	data.space = JutsuAbilityFactory.shunshin()
	var slot: int = 0
	for id: StringName in profile.equipped_jutsu:
		var jutsu: JutsuData = db.get_jutsu(id)
		if jutsu == null or jutsu.passive or slot >= JUTSU_SLOTS.size():
			continue
		data.set(JUTSU_SLOTS[slot], JutsuAbilityFactory.build(jutsu, db))
		slot += 1
	return data


static func look_for(profile: CharacterProfile) -> ShinobiLook:
	var look := ShinobiLook.new()
	var palette: Array = VILLAGE_COLORS.get(profile.village_id, VILLAGE_COLORS[&"konoha"])
	var h: int = absi(hash(profile.character_id + profile.character_name))
	look.top = palette[0]
	look.top_accent = palette[1]
	look.sleeves = palette[1]
	look.pants = palette[1].darkened(0.2)
	look.accent = palette[0].darkened(0.3)
	look.flak_vest = profile.grade >= ProgressionTypes.Grade.CHUNIN
	look.hair = (h % ShinobiLook.Hair.size()) as ShinobiLook.Hair
	var hair_colors: Array[Color] = [Color(0.1, 0.08, 0.1), Color(0.35, 0.2, 0.1), Color(0.95, 0.8, 0.3), Color(0.85, 0.85, 0.9), Color(0.7, 0.2, 0.15)]
	look.hair_color = hair_colors[(h / 7) % hair_colors.size()]
	match profile.clan_id:
		&"clan_uchiha":
			look.hair_color = Color(0.08, 0.08, 0.14)
			look.eye_color = Color(0.85, 0.05, 0.05)
		&"clan_uzumaki":
			look.hair_color = Color(0.85, 0.2, 0.15)
		&"clan_akimichi":
			look.hair_color = Color(0.5, 0.3, 0.15)
		&"clan_sabaku":
			look.gourd = true
		&"clan_hoshigaki":
			look.skin = Color(0.45, 0.55, 0.75)
		&"clan_yuki", &"clan_hozuki":
			look.hair_color = Color(0.85, 0.9, 1.0)
		&"clan_kaguya":
			look.hair_color = Color(0.9, 0.9, 0.9)
			look.forehead_mark = true
		&"clan_epeistes":
			look.weapon = ShinobiLook.Weapon.SWORD
	return look
