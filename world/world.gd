class_name World
extends Node3D
## Open world: the player's village (safe), then hunting grounds going east,
## each zone more dangerous, and a boss camp. Killing a mob reports the kill
## to the progression authority (server when online), which grants the XP.

const CHARACTER_SCENE: PackedScene = preload("res://characters/base/shinobi.tscn")
const VILLAGE_HALF: float = 26.0
const GATE_HALF_WIDTH: float = 5.0
const FIELD_END_X: float = 215.0
const FIELD_HALF_Z: float = 46.0
const PLAYER_RESPAWN: float = 5.0
const MOB_RESPAWN: float = 18.0
const CORPSE_TIME: float = 3.0
const VILLAGE_NAMES: Dictionary = {&"konoha": "KONOHA", &"suna": "SUNA", &"ame": "AME", &"kiri": "KIRI"}
const VILLAGE_GROUND: Dictionary = {
	&"konoha": Color(0.42, 0.58, 0.32), &"suna": Color(0.78, 0.66, 0.45),
	&"ame": Color(0.4, 0.44, 0.48), &"kiri": Color(0.45, 0.55, 0.6),
}

## Hunting zones from the village gate eastwards.
const ZONES: Array[Dictionary] = [
	{"name": "Plaine des bandits", "from": 32.0, "to": 85.0, "ground": Color(0.5, 0.6, 0.34),
		"mobs": [[&"bandit", 7], [&"bandit_thrower", 4]], "level": "Facile"},
	{"name": "Forêt des déserteurs", "from": 85.0, "to": 140.0, "ground": Color(0.3, 0.45, 0.28),
		"mobs": [[&"rogue_ninja", 5], [&"rogue_kunoichi", 5]], "level": "Moyen"},
	{"name": "Ravin des renégats", "from": 140.0, "to": 192.0, "ground": Color(0.5, 0.42, 0.34),
		"mobs": [[&"elite_missing_nin", 4], [&"ronin", 3]], "level": "Difficile"},
	{"name": "Repaire de l'Akatsuki", "from": 192.0, "to": 215.0, "ground": Color(0.32, 0.28, 0.32),
		"mobs": [[&"boss_akatsuki", 1]], "level": "Boss"},
]

var player: CombatCharacter
var camera: ArenaCamera
var hud: WorldHud
var combat_menu: CombatMenu
var mobs: Array[CombatCharacter] = []

var _mob_ids: Dictionary = {}  # CombatCharacter -> mob id
var _mob_homes: Dictionary = {}  # CombatCharacter -> Vector3
var _timers: Dictionary = {}  # CombatCharacter -> {"t": seconds, "what": "hide" / "respawn"}
var _player_respawn: float = 0.0
var _rng := RandomNumberGenerator.new()
var _characters: Node3D


func _ready() -> void:
	var profile: CharacterProfile = Profiles.profile
	if profile == null:
		get_tree().change_scene_to_file.call_deferred(GameSession.MENU_SCENE)
		return
	_rng.seed = 7
	_build_environment(profile.village_id)
	_build_village(profile.village_id)
	_build_field()
	_characters = Node3D.new()
	_characters.name = "Characters"
	add_child(_characters)
	_spawn_player(profile)
	_spawn_mobs()
	camera = ArenaCamera.new()
	camera.fov = 40.0
	camera.distance = 28.0
	camera.cursor_offset_strength = 0.12
	camera.max_cursor_offset = 2.5
	camera.follow_smoothing = 16.0
	camera.target = player
	add_child(camera)
	camera.current = true
	hud = WorldHud.new()
	add_child(hud)
	hud.bind(self, player)
	combat_menu = CombatMenu.new()
	add_child(combat_menu)
	combat_menu.bind(player)
	if CombatFx.is_enabled():
		Sfx.warm_up()
		OptionsPanel.attach(self)
	Profiles.profile_updated.connect(_on_profile_updated)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file(GameSession.MENU_SCENE)


func _physics_process(delta: float) -> void:
	if player == null:
		return
	for mob: CombatCharacter in _timers.keys():
		var entry: Dictionary = _timers[mob]
		entry.t -= delta
		if entry.t > 0.0:
			continue
		if entry.what == "hide":
			mob.visible = false
			_timers[mob] = {"t": MOB_RESPAWN, "what": "respawn"}
		else:
			_timers.erase(mob)
			mob.visible = true
			mob.reset_for_round(Transform3D(Basis.IDENTITY, _mob_homes[mob]))
			mob.controls_enabled = true
	if player.is_dead():
		_player_respawn -= delta
		if _player_respawn <= 0.0:
			_respawn_player()


## Zone the player stands in ("Village" inside the walls).
func zone_name(at: Vector3) -> String:
	if absf(at.x) <= VILLAGE_HALF and absf(at.z) <= VILLAGE_HALF:
		return "Village de " + VILLAGE_NAMES.get(Profiles.profile.village_id, "").capitalize() if Profiles.profile else "Village"
	for zone: Dictionary in ZONES:
		if at.x >= zone.from and at.x < zone.to:
			return "%s  ·  %s" % [zone.name, zone.level]
	return "Abords du village"


func respawn_left() -> float:
	return maxf(_player_respawn, 0.0) if player != null and player.is_dead() else 0.0


# --- Characters --------------------------------------------------------------------

func _spawn_player(profile: CharacterProfile) -> void:
	player = CHARACTER_SCENE.instantiate() as CombatCharacter
	player.data = ShinobiKit.build(profile, Profiles.db, Profiles.service())
	player.team = 0
	player.name = "Player"
	var controller := PlayerInputController.new()
	controller.name = "Controller"
	player.add_child(controller)
	player.controller = controller
	player.transform = _village_spawn()
	_characters.add_child(player)
	player.presentation.set_role(CharacterPresentation.Role.LOCAL_PLAYER)
	player.died.connect(func(_c: CombatCharacter) -> void: _player_respawn = PLAYER_RESPAWN)


func _village_spawn() -> Transform3D:
	return Transform3D(Basis.looking_at(Vector3.RIGHT, Vector3.UP), Vector3(4, 0, 6))


func _respawn_player() -> void:
	player.reset_for_round(_village_spawn())
	player.controls_enabled = true
	hud.toast("Tu reprends connaissance au village.", Color(0.8, 0.9, 1.0))


## Rebuilds the player's kit after a promotion (full heal, new pools) or a
## loadout change from the combat menu (cooldowns, HP and chakra kept).
func _refresh_player_kit(promotion: bool = false) -> void:
	var profile: CharacterProfile = Profiles.profile
	if profile == null or player == null:
		return
	player.abilities.interrupt()
	player.data = ShinobiKit.build(profile, Profiles.db, Profiles.service())
	player.abilities.setup(player, player.data)
	player.movement.data = player.data.movement
	if promotion:
		player.health.setup(player.data.max_health)
		player.energy.configure_chakra(player.data.max_chakra, player.data.chakra_regen)
	hud.rebuild_slots()
	if combat_menu != null:
		combat_menu.refresh()


func _spawn_mobs() -> void:
	for zone: Dictionary in ZONES:
		for entry: Array in zone.mobs:
			for i in int(entry[1]):
				var at := Vector3(_rng.randf_range(zone.from + 4.0, zone.to - 4.0), 0.0, _rng.randf_range(-FIELD_HALF_Z + 6.0, FIELD_HALF_Z - 6.0))
				if entry[0] == &"boss_akatsuki":
					at = Vector3(zone.from + 12.0, 0.0, 0.0)
				_spawn_mob(entry[0], at)


func _spawn_mob(mob_id: StringName, at: Vector3) -> void:
	var info: Dictionary = MobCatalog.MOBS[mob_id]
	var mob := CHARACTER_SCENE.instantiate() as CombatCharacter
	mob.data = MobCatalog.build(mob_id)
	mob.team = 1
	mob.name = "Mob_%s_%d" % [mob_id, mobs.size()]
	var bot := BotController.new()
	bot.name = "Controller"
	bot.aggro_range = info.aggro
	bot.leash_range = 26.0 if mob_id != &"boss_akatsuki" else 18.0
	bot.home = at
	bot.defend_chance = 0.2
	bot.reaction_time = 0.3
	mob.add_child(bot)
	mob.controller = bot
	mob.transform = Transform3D(Basis.looking_at(Vector3.LEFT, Vector3.UP), at)
	_characters.add_child(mob)
	var pivot := mob.get_node_or_null("VisualPivot") as Node3D
	if pivot != null:
		pivot.scale = Vector3.ONE * float(info.scale)
	mob.presentation.set_role(CharacterPresentation.Role.ENEMY)
	mob.died.connect(_on_mob_died)
	mobs.append(mob)
	_mob_ids[mob] = mob_id
	_mob_homes[mob] = at


func _on_mob_died(mob: CombatCharacter) -> void:
	_timers[mob] = {"t": CORPSE_TIME, "what": "hide"}
	var killer: CombatCharacter = mob.last_attacker
	if killer == player:
		Profiles.request({"action": "report_kill", "mob": _mob_ids[mob]})


func _on_profile_updated(_profile: CharacterProfile, result: ProgressionResult) -> void:
	var rebuild: bool = false
	var promotion: bool = false
	for event: Dictionary in result.events:
		match event.type:
			&"xp_gained":
				CombatFx.damage_number(player, player.global_position + Vector3.UP * 3.0, 0.0, Color(0.6, 0.85, 1.0), "+%d XP" % int(event.amount))
			&"promoted":
				hud.announce("PROMU %s !" % ShinobiScreen.GRADE_NAMES[int(event.grade)].to_upper())
				rebuild = true
				promotion = true
			&"loadout_changed", &"jutsu_equipped":
				rebuild = true
			&"choice_required":
				hud.toast("Nouveau choix disponible dans SHINOBI (Échap).", Color(1.0, 0.85, 0.4))
			&"sub_jutsu_obtained":
				var sub: SubJutsuData = Profiles.db.get_sub_jutsu(event.sub_jutsu)
				hud.toast("Technique cachée obtenue : %s" % (sub.display_name if sub else ""), Color(0.8, 0.5, 1.0))
	if rebuild:
		_refresh_player_kit(promotion)


# --- Map ---------------------------------------------------------------------------

func _build_environment(village: StringName) -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.32, 0.52, 0.82)
	sky_mat.sky_horizon_color = Color(0.72, 0.78, 0.84)
	sky_mat.ground_bottom_color = Color(0.2, 0.25, 0.18)
	sky_mat.ground_horizon_color = Color(0.72, 0.78, 0.84)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color(0.75, 0.8, 0.9)
	env.ambient_light_sky_contribution = 0.6
	env.ambient_light_energy = 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.85
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.glow_bloom = 0.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.7, 0.76, 0.82)
	env.fog_density = 0.0025 if village == &"ame" or village == &"kiri" else 0.0008
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_color = Color(1, 0.95, 0.86)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)


func _build_village(village: StringName) -> void:
	var d := WorldDecor.new(self, 11)
	var h: float = VILLAGE_HALF
	var grass: Color = VILLAGE_GROUND.get(village, Color(0.42, 0.58, 0.32))
	var stone := Color(0.5, 0.47, 0.43)
	var wall_color := Color(0.55, 0.42, 0.3) if village != &"suna" else Color(0.8, 0.7, 0.5)
	var roof_color: Color = {&"konoha": Color(0.25, 0.35, 0.5), &"suna": Color(0.72, 0.6, 0.42),
		&"ame": Color(0.3, 0.3, 0.38), &"kiri": Color(0.28, 0.42, 0.55)}.get(village, Color(0.3, 0.35, 0.5))
	d.ground(Vector3(0, -0.02, 0), Vector2(h * 2.0, h * 2.0), grass.darkened(0.25))
	# Roads (main street to the gate, cross street) and the round plaza.
	d.ground(Vector3(h * 0.5, -0.01, 0), Vector2(h, 5.0), stone.darkened(0.15))
	d.ground(Vector3(0, -0.012, 0), Vector2(4.0, h * 2.0), stone.darkened(0.15))
	d.disk(Vector3(0, 0.0, 0), 8.0, stone)
	d.disk(Vector3(0, 0.01, 0), 7.2, stone.lightened(0.08))
	var on_road := func(p: Vector3) -> bool:
		return absf(p.z) < 3.2 and p.x > -1.0 or absf(p.x) < 2.6 or p.length() < 8.5
	d.grass(Vector2(-h + 1, -h + 1), Vector2(h - 1, h - 1), 900, grass.lightened(0.05), on_road)
	d.flowers(Vector2(-h + 1, -h + 1), Vector2(h - 1, h - 1), 240, on_road)
	# Walls with a darker cap, and the gate.
	var side: float = (h * 2.0 - GATE_HALF_WIDTH * 2.0) / 2.0
	for wall: Array in [[Vector3(0, 0, -h), Vector3(h * 2.0, 3.0, 1.2)], [Vector3(0, 0, h), Vector3(h * 2.0, 3.0, 1.2)],
			[Vector3(-h, 0, 0), Vector3(1.2, 3.0, h * 2.0)], [Vector3(h, 0, -(GATE_HALF_WIDTH + side / 2.0)), Vector3(1.2, 3.0, side)],
			[Vector3(h, 0, GATE_HALF_WIDTH + side / 2.0), Vector3(1.2, 3.0, side)]]:
		d.solid_box(wall[0], wall[1], wall_color)
		d.box(wall[0] + Vector3.UP * 3.1, wall[1] + Vector3(0.3, -2.8, 0.3), wall_color.darkened(0.35))
	d.torii(Vector3(h, 0, 0), GATE_HALF_WIDTH * 2.0, Color(0.75, 0.15, 0.12) if village == &"konoha" else wall_color.darkened(0.2))
	d.label(Vector3(h + 0.8, 7.6, 0), VILLAGE_NAMES.get(village, ""), 110, Color.WHITE)
	# Kage building, statue, houses.
	d.kage_tower(Vector3(-15, 0, -13), Color(0.85, 0.35, 0.28) if village == &"konoha" else wall_color.lightened(0.25), Color(0.7, 0.15, 0.12), "火" if village == &"konoha" else VILLAGE_NAMES.get(village, "").left(1))
	d.label(Vector3(-15, 14.0, -13), "Bureau du Kage", 64, Color.WHITE)
	d.statue(Vector3(-3, 0, 2), Color(0.55, 0.55, 0.6))
	var houses: Array = [[-15, 12, 0], [-4, -18, 0], [7, -18, 0], [-17, 1, 90], [-5, 18, 180], [8, 18, 180], [16, -10, 0], [16, 11, 180], [-8, -8, 45], [9, -8, 0], [9, 9, 180]]
	for p: Array in houses:
		var size := Vector3(d.rng.randf_range(5.0, 7.0), d.rng.randf_range(3.5, 4.8), d.rng.randf_range(4.5, 6.0))
		d.house(Vector3(p[0], 0, p[1]), size, Color(0.88, 0.83, 0.72).darkened(d.rng.randf_range(0.0, 0.15)), roof_color.darkened(d.rng.randf_range(0.0, 0.25)), p[2])
	for x in range(4, int(h) - 2, 5):
		for z: float in [-3.6, 3.6]:
			d.lantern(Vector3(x, 0, z))
	for t: Array in [[-22, -22], [-22, 22], [20, -21], [20, 21], [-10, 22], [2, -22], [-22, -6]]:
		d.round_tree(Vector3(t[0], 0, t[1]), Color(1.0, 0.68, 0.8) if village == &"konoha" else Color(0.3, 0.55, 0.3), 0.9)
	# Training ground.
	d.fence(Vector3(-12, 0, 4), Vector3(-12, 0, 10))
	for i in 3:
		d.solid_round(Vector3(-9 + i * 2.2, 0, 7), 0.3, 1.6)
		d.cylinder(Vector3(-9 + i * 2.2, 0.8, 7), 0.28, 0.3, 1.6, Color(0.55, 0.38, 0.22), 8)
	d.label(Vector3(-7, 3.0, 7), "Terrain d'entraînement", 46, Color(1, 1, 0.8))
	d.label(Vector3(h - 4, 3.5, 0), "→ Terrains de chasse", 56, Color(1.0, 0.85, 0.4))
	# Mountains around the village.
	for i in 9:
		var a: float = PI * 0.55 + i * PI * 0.11
		d.mountain(Vector3(cos(a), 0, sin(a)) * 62.0, d.rng.randf_range(14.0, 22.0), d.rng.randf_range(16.0, 28.0), Color(0.42, 0.45, 0.42))


func _build_field() -> void:
	var d := WorldDecor.new(self, 23)
	var length: float = FIELD_END_X - VILLAGE_HALF
	var center_x: float = VILLAGE_HALF + length / 2.0
	d.ground(Vector3(center_x, -0.05, 0), Vector2(800, 500), Color(0.22, 0.32, 0.2))  # beyond the borders
	for zone: Dictionary in ZONES:
		var w: float = zone.to - zone.from
		d.ground(Vector3(zone.from + w / 2.0, -0.03, 0), Vector2(w + 0.5, FIELD_HALF_Z * 2.0), (zone.ground as Color).darkened(0.3))
		d.label(Vector3(zone.from + 2.0, 4.5, -8.0), "%s\n%s" % [zone.name, zone.level], 72, Color(1, 0.95, 0.8))
	d.ground(Vector3(VILLAGE_HALF + 3.0, -0.04, 0), Vector2(8.0, VILLAGE_HALF * 2.0), Color(0.42, 0.55, 0.32).darkened(0.3))
	# Winding dirt path with stepping stones.
	var path_color := Color(0.6, 0.5, 0.36).darkened(0.25)
	for i in 60:
		var x: float = VILLAGE_HALF + 2.0 + i * (length - 4.0) / 60.0
		var z: float = sin(x * 0.05) * 6.0
		d.disk(Vector3(x, -0.015, z), 3.2, path_color)
	var on_path := func(p: Vector3) -> bool: return absf(p.z - sin(p.x * 0.05) * 6.0) < 3.4
	d.grass(Vector2(VILLAGE_HALF + 1, -FIELD_HALF_Z + 1), Vector2(FIELD_END_X - 1, FIELD_HALF_Z - 1), 4200, Color(0.4, 0.58, 0.3), on_path)
	d.flowers(Vector2(32, -FIELD_HALF_Z + 1), Vector2(85, FIELD_HALF_Z - 1), 450, on_path)
	# Borders: invisible walls behind a line of trees / rocks.
	for wall: Array in [[Vector3(center_x, 0, -FIELD_HALF_Z), Vector3(length, 3.0, 1.2)], [Vector3(center_x, 0, FIELD_HALF_Z), Vector3(length, 3.0, 1.2)],
			[Vector3(FIELD_END_X, 0, 0), Vector3(1.2, 3.0, FIELD_HALF_Z * 2.0)],
			[Vector3(VILLAGE_HALF + 3.0, 0, -(VILLAGE_HALF + FIELD_HALF_Z) / 2.0), Vector3(1.2, 3.0, FIELD_HALF_Z - VILLAGE_HALF)],
			[Vector3(VILLAGE_HALF + 3.0, 0, (VILLAGE_HALF + FIELD_HALF_Z) / 2.0), Vector3(1.2, 3.0, FIELD_HALF_Z - VILLAGE_HALF)]]:
		var shape := BoxShape3D.new()
		shape.size = wall[1]
		d.collider(wall[0], shape, 3.0)
	for x in range(int(VILLAGE_HALF) + 4, int(FIELD_END_X), 5):
		for z: float in [-FIELD_HALF_Z - 1.5, FIELD_HALF_Z + 1.5]:
			if x > 140 and x < 192:
				d.rock(Vector3(x, 0, z), d.rng.randf_range(1.5, 2.6), Color(0.5, 0.46, 0.42))
			else:
				d.pine(Vector3(x + d.rng.randf_range(-1, 1), 0, z), d.rng.randf_range(1.0, 1.4))
	for i in 10:
		d.mountain(Vector3(VILLAGE_HALF + 20.0 + i * 20.0, 0, (-1 if i % 2 == 0 else 1) * (FIELD_HALF_Z + 30.0)), d.rng.randf_range(16, 24), d.rng.randf_range(18, 30), Color(0.4, 0.42, 0.4))
	# Zone props.
	for i in 170:
		var at := Vector3(d.rng.randf_range(VILLAGE_HALF + 8.0, FIELD_END_X - 4.0), 0, d.rng.randf_range(-FIELD_HALF_Z + 3.0, FIELD_HALF_Z - 3.0))
		if on_path.call(at):
			continue
		if at.x < 85.0:
			if d.rng.randf() < 0.35:
				d.round_tree(at, Color(0.3, 0.55, 0.28))
			else:
				d.bush(at, Color(0.28, 0.5, 0.25))
		elif at.x < 140.0:
			if d.rng.randf() < 0.65:
				d.pine(at, d.rng.randf_range(1.0, 1.5))
			else:
				d.bush(at, Color(0.2, 0.42, 0.22))
		elif at.x < 192.0:
			if d.rng.randf() < 0.7:
				d.rock(at, d.rng.randf_range(1.0, 2.4), Color(0.55, 0.48, 0.42))
			else:
				d.ruin_pillar(at)
	# Bandit camps.
	for camp: Vector3 in [Vector3(50, 0, -24), Vector3(70, 0, 22)]:
		d.campfire(camp)
		d.tent(camp + Vector3(-3.5, 0, -2.5), Color(0.6, 0.48, 0.3), 30.0)
		d.tent(camp + Vector3(3.0, 0, -3.0), Color(0.55, 0.42, 0.28), -20.0)
		d.fence(camp + Vector3(-6, 0, 4), camp + Vector3(6, 0, 4))
	# Deserters' hideout in the forest, renegades' ruins, Akatsuki lair.
	d.campfire(Vector3(112, 0, -18))
	d.tent(Vector3(108, 0, -21), Color(0.2, 0.2, 0.25), 10.0)
	d.campfire(Vector3(165, 0, 20))
	d.ground(Vector3(203.5, -0.025, 0), Vector2(23.0, FIELD_HALF_Z * 2.0), Color(0.18, 0.15, 0.2))
	d.torii(Vector3(194.0, 0, 0), 9.0, Color(0.35, 0.08, 0.08))
	d.campfire(Vector3(206, 0, -6))
	d.campfire(Vector3(206, 0, 6))
	d.label(Vector3(204, 6.0, 0), "暁", 200, Color(0.85, 0.1, 0.1))


func _label(at: Vector3, text: String, size: int, color: Color, _rotation: Vector3 = Vector3.ZERO) -> void:
	WorldDecor.new(self, 0).label(at, text, size, color)
