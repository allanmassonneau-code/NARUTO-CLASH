class_name JutsuAbilityFactory
## Turns a progression technique (JutsuData) into a combat ability
## (AbilityData). A technique with hand-made gameplay_data uses it as is;
## otherwise its tags, rank and owner give a sensible default, so new
## content is playable before its combat tuning exists.

## Damage per rank D, C, B, A, S.
const RANK_DAMAGE: Array[float] = [12.0, 16.0, 22.0, 30.0, 42.0]
const NATURE_VFX: Dictionary = {&"katon": &"katon", &"raiton": &"chidori", &"doton": &"okasho", &"suiton": &"", &"futon": &""}


static func build(jutsu: JutsuData, db: ProgressionDatabase) -> AbilityData:
	if jutsu.gameplay_data != null:
		jutsu.gameplay_data.source_id = jutsu.id
		return jutsu.gameplay_data
	var a := AbilityData.new()
	a.source_id = jutsu.id
	a.display_name = jutsu.display_name
	a.icon = jutsu.icon
	a.color = _color(jutsu, db)
	var rank: int = jutsu.rank
	var damage: float = RANK_DAMAGE[rank]
	var tags: Array[StringName] = jutsu.tags
	a.cooldown = maxf(jutsu.cooldown, 3.0)
	a.energy_cost = jutsu.chakra_cost
	a.startup_time = 0.15 + rank * 0.06
	a.active_time = 0.05
	a.recovery_time = 0.25
	a.cast_move_multiplier = 0.4
	a.energy_gain_on_hit = 4.0 + damage * 0.3
	if tags.has(&"HEAL") and not tags.has(&"MELEE") and not tags.has(&"RANGED"):
		a.kind = AbilityData.Kind.SELF_HEAL
		a.heal_amount = 15.0 + rank * 8.0
		a.heal_allies_radius = 5.0
		a.anim = &"heal"
		a.vfx = &"heal"
	elif tags.has(&"DASH") or (tags.has(&"MOVEMENT") and not tags.has(&"BUFF")):
		a.kind = AbilityData.Kind.DASH
		a.dash_distance = 6.0 + rank * 0.5
		a.active_time = 0.18
		a.startup_time = 0.08
		a.dash_immaterial = not tags.has(&"MELEE")
		a.damage = damage * 0.8 if tags.has(&"MELEE") or tags.has(&"AOE") else 0.0
		a.hit_radius = 0.8
		a.cast_move_multiplier = 1.0
		a.anim = &"dash"
	elif tags.has(&"COUNTER") or (tags.has(&"DEFENSIVE") and not _offensive(tags)):
		a.kind = AbilityData.Kind.COUNTER
		a.startup_time = 0.02
		a.active_time = 0.7 + rank * 0.05
		a.counter_stun_attacker = 0.7
		a.grant_shield = 10.0 + rank * 8.0 if tags.has(&"DEFENSIVE") else 0.0
		a.can_cancel_during_startup = false
		a.anim = &"guard"
	elif tags.has(&"PROJECTILE") or tags.has(&"HITSCAN") or tags.has(&"RANGED"):
		a.kind = AbilityData.Kind.PROJECTILE
		a.max_range = 9.0 + rank
		a.projectile_speed = 40.0 if tags.has(&"HITSCAN") else 18.0
		a.hit_radius = 1.0 if tags.has(&"AOE") else 0.6
		a.projectile_piercing = tags.has(&"HITSCAN")
		a.damage = damage
		a.anim = &"throw"
		a.vfx = NATURE_VFX.get(jutsu.owner_id, &"")
	elif tags.has(&"AOE") or tags.has(&"CHANNELING"):
		a.kind = AbilityData.Kind.GROUND_AREA
		a.max_range = 7.0
		a.hit_radius = 2.2 + rank * 0.25
		a.area_delay = 0.5
		a.damage = damage
		a.anim = &"seal"
		a.vfx = NATURE_VFX.get(jutsu.owner_id, &"")
	elif tags.has(&"MELEE"):
		a.kind = AbilityData.Kind.MELEE_ARC
		a.max_range = 2.4
		a.arc_degrees = 110.0
		a.damage = damage
		a.lunge_distance = 0.8
		a.anim = &"palm"
	else:
		# Pure buffs / debuffs: a self cast that applies the buffs below.
		a.kind = AbilityData.Kind.SELF_HEAL
		a.anim = &"seal"
		a.buff_empower = 4.0 if tags.has(&"BUFF") else 0.0
		a.buff_haste = 3.0 if tags.has(&"BUFF") else 0.0
		a.grant_shield = 15.0 + rank * 6.0 if tags.has(&"DEFENSIVE") else 0.0
	if tags.has(&"CC"):
		if a.kind == AbilityData.Kind.GROUND_AREA:
			a.root_duration = 0.8 + rank * 0.15
		else:
			a.stun_duration = 0.5 + rank * 0.1
	if tags.has(&"DEBUFF"):
		a.slow_duration = 1.5
	if tags.has(&"DOT"):
		a.burn_duration = 2.0 + rank * 0.5
	if tags.has(&"BUFF") and a.kind != AbilityData.Kind.SELF_HEAL:
		a.buff_empower = 3.0
	return a


static func _offensive(tags: Array[StringName]) -> bool:
	return tags.has(&"MELEE") or tags.has(&"RANGED") or tags.has(&"AOE") or tags.has(&"PROJECTILE")


static func _color(jutsu: JutsuData, db: ProgressionDatabase) -> Color:
	var nature: ChakraNatureData = db.get_nature(jutsu.owner_id)
	if nature != null:
		return nature.color
	match jutsu.source:
		ProgressionTypes.JutsuSource.CLAN:
			return Color(0.9, 0.35, 0.35)
		ProgressionTypes.JutsuSource.SPECIALIZATION:
			return Color(0.4, 1.0, 0.6)
		ProgressionTypes.JutsuSource.SUB_JUTSU:
			return Color(0.8, 0.5, 1.0)
	return Color.WHITE


## Basic taijutsu string every shinobi has (LMB).
static func taijutsu() -> AbilityData:
	var hits: Array[AbilityData] = []
	for i in 3:
		var a := AbilityData.new()
		a.display_name = "Taijutsu"
		a.kind = AbilityData.Kind.MELEE_ARC
		a.color = Color(1.0, 0.85, 0.6)
		a.startup_time = 0.08 if i < 2 else 0.12
		a.active_time = 0.05
		a.recovery_time = 0.14 if i < 2 else 0.3
		a.max_range = 1.9 if i < 2 else 2.2
		a.arc_degrees = 100.0
		a.damage = 6.0 if i < 2 else 11.0
		a.lunge_distance = 0.5 if i < 2 else 0.9
		a.knockback_speed = 0.0 if i < 2 else 9.0
		a.cast_move_multiplier = 0.55
		a.recovery_move_multiplier = 0.85
		a.combo_window = 0.45
		a.energy_gain_on_hit = 6.0
		a.anim = [&"jab", &"hook", &"kick"][i]
		hits.append(a)
	hits[0].combo_next = hits[1]
	hits[1].combo_next = hits[2]
	return hits[0]


## Universal dash (Shift): short, brief invulnerability.
static func dash() -> AbilityData:
	var a := AbilityData.new()
	a.display_name = "Dash"
	a.kind = AbilityData.Kind.DASH
	a.color = Color(0.8, 0.9, 1.0)
	a.startup_time = 0.0
	a.active_time = 0.12
	a.recovery_time = 0.06
	a.cooldown = 3.5
	a.dash_distance = 4.5
	a.dash_immaterial = true
	a.cast_move_multiplier = 1.0
	a.recovery_move_multiplier = 1.0
	a.can_cancel_during_startup = false
	a.anim = &"dash"
	a.vfx = &"shunshin"
	return a


## Substitution (Kawarimi): one charge, 50 s recharge. Saves the position;
## while you stay in the zone, the next hit is negated and you reappear there.
static func substitution() -> AbilityData:
	var a := AbilityData.new()
	a.display_name = "Substitution"
	a.kind = AbilityData.Kind.SUBSTITUTION
	a.color = Color(1.0, 0.8, 0.35)
	a.startup_time = 0.0
	a.active_time = 0.05
	a.recovery_time = 0.1
	a.cooldown = 50.0
	a.substitution_radius = 4.0
	a.cast_move_multiplier = 1.0
	a.recovery_move_multiplier = 1.0
	a.can_cancel_during_startup = false
	a.anim = &"seal"
	return a


## Shunshin: the mobs' dash.
static func shunshin() -> AbilityData:
	var a := AbilityData.new()
	a.display_name = "Shunshin"
	a.kind = AbilityData.Kind.DASH
	a.color = Color(0.8, 0.9, 1.0)
	a.startup_time = 0.03
	a.active_time = 0.14
	a.recovery_time = 0.08
	a.cooldown = 6.0
	a.dash_distance = 6.0
	a.dash_immaterial = true
	a.cast_move_multiplier = 1.0
	a.recovery_move_multiplier = 1.0
	a.can_cancel_during_startup = false
	a.anim = &"dash"
	a.vfx = &"shunshin"
	return a
