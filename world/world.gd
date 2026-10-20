class_name World
extends Node3D
## Open world: the player's village (safe), then hunting grounds going east,
## each zone more dangerous, and a boss camp. Killing a mob reports the kill
## to the progression authority (server when online), which grants the XP.

const CHARACTER_SCENE: PackedScene = preload("res://characters/base/shinobi.tscn")
const VILLAGE_HALF: float = 26.0
const GATE_HALF_WIDTH: float = 5.0
const PLAYER_RESPAWN: float = 5.0
const MOB_RESPAWN: float = 18.0
const CORPSE_TIME: float = 3.0
## Mobs farther than this from every player sleep (no AI, hidden).
const MOB_WAKE_RANGE: float = 85.0
const VILLAGE_NAMES: Dictionary = {&"konoha": "KONOHA", &"suna": "SUNA", &"ame": "AME", &"kiri": "KIRI"}
const VILLAGE_GROUND: Dictionary = {
	&"konoha": Color(0.42, 0.58, 0.32), &"suna": Color(0.78, 0.66, 0.45),
	&"ame": Color(0.4, 0.44, 0.48), &"kiri": Color(0.45, 0.55, 0.6),
}

# --- Cross map ----------------------------------------------------------------------
## Four villages around a neutral centre, seen from above:
##            SUNA (-z)
##   KONOHA (-x)  NEUTRE  KIRI (+x)
##            AME (+z)
## Each village is built in its own frame: local +x goes from the village
## centre through its gate and its hunting arm to the neutral centre.
const VILLAGES: Array[StringName] = [&"konoha", &"suna", &"kiri", &"ame"]
const VILLAGE_YAW: Dictionary = {&"konoha": 0.0, &"kiri": 180.0, &"suna": -90.0, &"ame": 90.0}
const VILLAGE_DISTANCE: float = 170.0
const ARM_HALF: float = 30.0
const CENTRE_HALF: float = 45.0
const ARM_END: float = VILLAGE_DISTANCE - CENTRE_HALF
const BOSS_RADIUS: float = 14.0

## Hunting zones of each arm (local x from the village centre).
const ARM_ZONES: Dictionary = {
	&"konoha": [
		{"name": "Plaine des bandits", "from": 29.0, "to": 77.0, "ground": Color(0.5, 0.6, 0.34), "surface": &"grass", "props": "plain",
			"mobs": [[&"bandit", 5], [&"bandit_thrower", 3]], "level": "Facile"},
		{"name": "Forêt des déserteurs", "from": 77.0, "to": ARM_END, "ground": Color(0.3, 0.45, 0.28), "surface": &"forest_ground", "props": "forest",
			"mobs": [[&"rogue_ninja", 4], [&"rogue_kunoichi", 4]], "level": "Moyen"},
	],
	&"suna": [
		{"name": "Dunes des pillards", "from": 29.0, "to": 77.0, "ground": Color(0.78, 0.66, 0.45), "surface": &"sand", "props": "dunes",
			"mobs": [[&"bandit", 5], [&"bandit_thrower", 3]], "level": "Facile"},
		{"name": "Canyon des déserteurs", "from": 77.0, "to": ARM_END, "ground": Color(0.66, 0.5, 0.36), "surface": &"sand", "props": "canyon",
			"mobs": [[&"rogue_ninja", 4], [&"rogue_kunoichi", 4]], "level": "Moyen"},
	],
	&"kiri": [
		{"name": "Marais brumeux", "from": 29.0, "to": 77.0, "ground": Color(0.4, 0.52, 0.44), "surface": &"grass", "props": "marsh",
			"mobs": [[&"bandit", 5], [&"bandit_thrower", 3]], "level": "Facile"},
		{"name": "Forêt de la brume", "from": 77.0, "to": ARM_END, "ground": Color(0.28, 0.4, 0.34), "surface": &"forest_ground", "props": "forest",
			"mobs": [[&"rogue_ninja", 4], [&"rogue_kunoichi", 4]], "level": "Moyen"},
	],
	&"ame": [
		{"name": "Rizières détrempées", "from": 29.0, "to": 77.0, "ground": Color(0.42, 0.5, 0.36), "surface": &"grass", "props": "marsh",
			"mobs": [[&"bandit", 5], [&"bandit_thrower", 3]], "level": "Facile"},
		{"name": "Ruines sous la pluie", "from": 77.0, "to": ARM_END, "ground": Color(0.4, 0.4, 0.42), "surface": &"stone", "props": "ruins",
			"mobs": [[&"rogue_ninja", 4], [&"rogue_kunoichi", 4]], "level": "Moyen"},
	],
}
const CENTRE_ZONE: Dictionary = {"name": "Terres neutres", "level": "Difficile", "surface": &"sand",
	"mobs": [[&"elite_missing_nin", 5], [&"ronin", 4]]}
const BOSS_ZONE: Dictionary = {"name": "Repaire de l'Akatsuki", "level": "Boss", "surface": &"stone"}


## Transform of a village frame (see VILLAGES).
static func village_frame(village: StringName) -> Transform3D:
	var basis := Basis(Vector3.UP, deg_to_rad(float(VILLAGE_YAW.get(village, 0.0))))
	return Transform3D(basis, basis * Vector3(-VILLAGE_DISTANCE, 0.0, 0.0))


## Where `at` is: {"village": id or &"", "zone": zone dict ({} inside a village), "safe": bool}.
static func locate(at: Vector3) -> Dictionary:
	for v: StringName in VILLAGES:
		var l: Vector3 = village_frame(v).affine_inverse() * at
		if absf(l.z) <= VILLAGE_HALF + 0.6 and absf(l.x) <= VILLAGE_HALF + 0.6:
			return {"village": v, "zone": {}, "safe": true}
		if l.x > VILLAGE_HALF and l.x < ARM_END and absf(l.z) <= ARM_HALF + 2.0:
			for z: Dictionary in ARM_ZONES[v]:
				if l.x < float(z.to):
					return {"village": v, "zone": z, "safe": false}
	if Vector2(at.x, at.z).length() < BOSS_RADIUS:
		return {"village": &"", "zone": BOSS_ZONE, "safe": false}
	return {"village": &"", "zone": CENTRE_ZONE, "safe": false}


static func in_village(at: Vector3) -> bool:
	return bool(locate(at).safe)


var player: CombatCharacter
var camera: ArenaCamera
var hud: WorldHud
var combat_menu: CombatMenu
var shinobi_screen: ShinobiScreen
var mobs: Array[CombatCharacter] = []

var _mob_ids: Dictionary = {}  # CombatCharacter -> mob id
var _mob_homes: Dictionary = {}  # CombatCharacter -> Vector3
var _timers: Dictionary = {}  # CombatCharacter -> {"t": seconds, "what": "hide" / "respawn"}
var _player_respawn: float = 0.0
var _rng := RandomNumberGenerator.new()
var _characters: Node3D
var _rebuild_look: bool = false


## Menu backdrop: only the map of `backdrop_village` (no player, mobs, HUD,
## audio) with a slow cinematic camera around `backdrop_focus`.
var backdrop_village: StringName = &""
var backdrop_focus: Vector3 = Vector3.ZERO
var _orbit: float = 0.0
var _backdrop_camera: Camera3D
var _wake_timer: float = 0.0
## Shared world online: this client only simulates its own shinobi (WorldNet).
var online: bool = false
## Persistent server: simulates the mobs, players are puppets.
var server: bool = false

## Places of the map shown behind the menus (clan-dependent), in the village frame.
const BACKDROP_SPOTS: Dictionary = {
	&"plaza": Vector3(0, 0, 0), &"gate": Vector3(26, 0, 0), &"training": Vector3(-14, 0, 8),
	&"plain": Vector3(52, 0, 0), &"forest": Vector3(100, 0, 0), &"ravine": Vector3(150, 0, 12),
}


static func backdrop(village: StringName, spot: StringName) -> World:
	var w := (load("res://world/world.tscn") as PackedScene).instantiate() as World
	w.backdrop_village = village if village != &"" else &"konoha"
	w.backdrop_focus = village_frame(w.backdrop_village) * (BACKDROP_SPOTS.get(spot, Vector3.ZERO) as Vector3)
	return w


func _ready_backdrop() -> void:
	_rng.seed = 7
	_build_environment(backdrop_village)
	_build_map([backdrop_village])
	_backdrop_camera = Camera3D.new()
	_backdrop_camera.fov = 50.0
	add_child(_backdrop_camera)
	_backdrop_camera.current = true
	_orbit = randf() * TAU
	_place_backdrop_camera()


func _place_backdrop_camera() -> void:
	var from: Vector3 = backdrop_focus + Vector3(cos(_orbit) * 18.0, 13.0, sin(_orbit) * 18.0)
	_backdrop_camera.transform = Transform3D(Basis.looking_at(backdrop_focus + Vector3.UP * 2.0 - from, Vector3.UP), from)


func _process(delta: float) -> void:
	if _backdrop_camera != null:
		_orbit += delta * 0.05
		_place_backdrop_camera()


func _ready() -> void:
	if backdrop_village != &"":
		_ready_backdrop()
		return
	if Net.is_server():
		_ready_server()
		return
	online = Net.is_client() and Net.is_online()
	var profile: CharacterProfile = Profiles.profile
	if profile == null:
		GameSession.menu_notice = "Retour au menu : aucun personnage chargé (%s)." % (Net.status_text if Net.status_text != "" else "hors ligne")
		get_tree().change_scene_to_file.call_deferred(GameSession.MENU_SCENE)
		return
	_rng.seed = 7
	_build_environment(profile.village_id)
	_build_map(VILLAGES)
	_characters = Node3D.new()
	_characters.name = "Characters"
	add_child(_characters)
	_spawn_player(profile)
	_spawn_mobs()
	camera = ArenaCamera.new()
	camera.fov = 40.0
	camera.distance = 22.0
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
	if online:
		player.team = WorldNet.PLAYER_TEAM_BASE
		Net.get_node("World").attach(self)
		hud.attach_online(Net.get_node("World"))


func _ready_server() -> void:
	server = true
	_rng.seed = 7
	_build_map(VILLAGES)
	_characters = Node3D.new()
	_characters.name = "Characters"
	add_child(_characters)
	_spawn_mobs()
	wake_mobs([])
	Net.get_node("World").attach(self)
	print("[world] shared world up: %d mobs" % mobs.size())


## Another player (online): a puppet following its owner's states.
func add_player_puppet(profile: CharacterProfile, team: int) -> CombatCharacter:
	var puppet := CHARACTER_SCENE.instantiate() as CombatCharacter
	puppet.data = ShinobiKit.build(profile, Profiles.db, Profiles.service())
	puppet.team = team
	puppet.net_mode = CombatCharacter.NetMode.PUPPET
	puppet.replay_casts = not server
	puppet.name = "Player_" + profile.character_id
	puppet.transform = village_frame(profile.village_id if VILLAGE_YAW.has(profile.village_id) else &"konoha") * Transform3D(Basis.IDENTITY, Vector3(4, 0, 6))
	_characters.add_child(puppet)
	puppet.abilities.free_casts = true
	puppet.abilities.cooldowns_disabled = true
	puppet.presentation.set_role(CharacterPresentation.Role.ENEMY)
	return puppet


func _unhandled_input(event: InputEvent) -> void:
	if backdrop_village != &"":
		return
	if event.is_action_pressed("ui_cancel"):
		open_shinobi_menu()
		get_viewport().set_input_as_handled()


## SHINOBI menu (natures, clan, specialization, Tenketsu, loadout) as an
## in-game overlay: the world keeps running, the player stops taking input.
func open_shinobi_menu() -> void:
	if is_instance_valid(shinobi_screen):
		return
	if combat_menu != null and combat_menu.is_open():
		combat_menu.toggle()
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	shinobi_screen = ShinobiScreen.new()
	shinobi_screen.on_quit = _quit_to_menu
	layer.add_child(shinobi_screen)
	player.controls_enabled = false
	shinobi_screen.tree_exited.connect(func() -> void:
		layer.queue_free()
		if is_instance_valid(player) and not player.is_dead():
			player.controls_enabled = true)


func _quit_to_menu() -> void:
	get_tree().change_scene_to_file.call_deferred(GameSession.MENU_SCENE)


func _physics_process(delta: float) -> void:
	if backdrop_village != &"":
		return
	if not online:
		_tick_mob_timers(delta)
	if player == null:
		return
	if player.is_dead():
		_player_respawn -= delta
		if _player_respawn <= 0.0:
			_respawn_player()
	if not online:
		_wake_timer -= delta
		if _wake_timer <= 0.0:
			_wake_timer = 0.5
			wake_mobs([player.global_position])
	_update_audio()


func _tick_mob_timers(delta: float) -> void:
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


## Mobs far from every player sleep: no AI, no physics, hidden.
func wake_mobs(around: Array[Vector3]) -> void:
	for mob: CombatCharacter in mobs:
		var home: Vector3 = _mob_homes[mob]
		var awake: bool = false
		for at: Vector3 in around:
			if HitQuery.flat(at - home).length() < MOB_WAKE_RANGE or HitQuery.flat(at - mob.global_position).length() < MOB_WAKE_RANGE:
				awake = true
				break
		mob.process_mode = Node.PROCESS_MODE_INHERIT if awake else Node.PROCESS_MODE_DISABLED
		if not _timers.has(mob):
			mob.visible = awake


const ZONE_SURFACE: Dictionary = {&"grass": &"grass", &"forest_ground": &"grass", &"sand": &"sand", &"stone": &"rock"}


## Shinobi Striker music, ambience and footstep surface for the zone the player is in.
func _update_audio() -> void:
	var where: Dictionary = locate(player.global_position)
	if where.safe:
		SSAudio.music(&"village")
		SSAudio.ambience(&"amb_village")
		SSAudio.surface = &"sand" if where.village == &"suna" else &"dirt"
		return
	var zone: Dictionary = where.zone
	SSAudio.surface = ZONE_SURFACE.get(zone.get("surface", &"grass"), &"dirt")
	SSAudio.ambience(&"amb_forest")
	match str(zone.get("level", "")):
		"Boss":
			SSAudio.music(&"boss")
		"Difficile":
			SSAudio.music(&"forest_battle")
		_:
			SSAudio.music(&"forest")


func _exit_tree() -> void:
	if backdrop_village != &"":
		return
	if online or server:
		Net.get_node("World").detach()
	SSAudio.music(&"")
	SSAudio.ambience(&"")


## Zone the player stands in ("Village de ..." inside the walls).
func zone_name(at: Vector3) -> String:
	var where: Dictionary = locate(at)
	if where.safe:
		return "Village de " + str(VILLAGE_NAMES.get(where.village, "")).capitalize() + "  ·  zone sûre"
	return "%s  ·  %s" % [where.zone.name, where.zone.level]


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


## Spawn point in the player's own village (its frame), facing the gate.
func _village_spawn() -> Transform3D:
	var village: StringName = Profiles.profile.village_id if Profiles.profile != null else &"konoha"
	return village_frame(village if VILLAGE_YAW.has(village) else &"konoha") * Transform3D(Basis.looking_at(Vector3.RIGHT, Vector3.UP), Vector3(4, 0, 6))


func _respawn_player() -> void:
	player.reset_for_round(_village_spawn())
	player.controls_enabled = not is_instance_valid(shinobi_screen)
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
	player.setup_kits()
	player.movement.data = player.data.movement
	if promotion:
		player.health.setup(player.data.max_health)
		player.energy.configure_chakra(player.data.max_chakra, player.data.chakra_regen)
	hud.rebuild_slots()
	if combat_menu != null:
		combat_menu.refresh()


func _spawn_mobs() -> void:
	for v: StringName in VILLAGES:
		var frame: Transform3D = village_frame(v)
		for zone: Dictionary in ARM_ZONES[v]:
			for entry: Array in zone.mobs:
				for i in int(entry[1]):
					var local := Vector3(_rng.randf_range(float(zone.from) + 4.0, float(zone.to) - 4.0), 0.0, _rng.randf_range(-ARM_HALF + 5.0, ARM_HALF - 5.0))
					_spawn_mob(entry[0], frame * local)
	for entry: Array in CENTRE_ZONE.mobs:
		for i in int(entry[1]):
			var at := Vector3(_rng.randf_range(-CENTRE_HALF + 5.0, CENTRE_HALF - 5.0), 0.0, _rng.randf_range(-CENTRE_HALF + 5.0, CENTRE_HALF - 5.0))
			if Vector2(at.x, at.z).length() < BOSS_RADIUS + 3.0:
				at = Vector3(at.x, 0.0, at.z).normalized() * (BOSS_RADIUS + 6.0) if Vector2(at.x, at.z).length() > 0.1 else Vector3(BOSS_RADIUS + 6.0, 0, 0)
			_spawn_mob(entry[0], at)
	_spawn_mob(&"boss_akatsuki", Vector3.ZERO)


func _spawn_mob(mob_id: StringName, at: Vector3) -> CombatCharacter:
	var info: Dictionary = MobCatalog.MOBS[mob_id]
	var mob := CHARACTER_SCENE.instantiate() as CombatCharacter
	mob.data = MobCatalog.build(mob_id)
	mob.team = 1
	mob.name = "Mob_%s_%d" % [mob_id, mobs.size()]
	if online:   # the server simulates the mobs: here a puppet replaying its casts
		mob.net_mode = CombatCharacter.NetMode.PUPPET
		mob.replay_casts = true
	var bot := BotController.new()
	bot.name = "Controller"
	bot.aggro_range = info.aggro
	bot.leash_range = 26.0 if mob_id != &"boss_akatsuki" else 18.0
	bot.home = at
	bot.defend_chance = 0.2
	bot.reaction_time = 0.3
	if not online:
		mob.add_child(bot)
		mob.controller = bot
	var face: Vector3 = HitQuery.flat(-at).normalized() if HitQuery.flat(at).length() > 0.5 else Vector3.BACK
	mob.transform = Transform3D(Basis.looking_at(face, Vector3.UP), at)
	_characters.add_child(mob)
	var pivot := mob.get_node_or_null("VisualPivot") as Node3D
	if pivot != null:
		pivot.scale = Vector3.ONE * float(info.scale)
	mob.presentation.set_role(CharacterPresentation.Role.ENEMY)
	if online:
		mob.abilities.free_casts = true
		mob.abilities.cooldowns_disabled = true
	mob.died.connect(_on_mob_died)
	mobs.append(mob)
	_mob_ids[mob] = mob_id
	_mob_homes[mob] = at
	return mob


func _on_mob_died(mob: CombatCharacter) -> void:
	if online:
		return
	_timers[mob] = {"t": CORPSE_TIME, "what": "hide"}
	if server:
		Net.get_node("World").on_mob_killed(_mob_ids[mob], mob)
		return
	var killer: CombatCharacter = mob.last_attacker
	if killer == player:
		Profiles.request({"action": "report_kill", "mob": _mob_ids[mob]})


func _on_profile_updated(_profile: CharacterProfile, result: ProgressionResult) -> void:
	if Profiles.profile == null:
		# Character deleted, or the connection dropped (the online profile is gone).
		GameSession.menu_notice = "Retour au menu : personnage perdu (%s)." % (Net.status_text if Net.status_text != "" else "connexion perdue")
		_quit_to_menu()
		return
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
			&"appearance_changed":
				rebuild = true
				_rebuild_look = true
			&"choice_required":
				hud.toast("Nouveau choix disponible dans SHINOBI (Échap).", Color(1.0, 0.85, 0.4))
			&"sub_jutsu_obtained":
				var sub: SubJutsuData = Profiles.db.get_sub_jutsu(event.sub_jutsu)
				hud.toast("Technique cachée obtenue : %s" % (sub.display_name if sub else ""), Color(0.8, 0.5, 1.0))
	if rebuild:
		_refresh_player_kit(promotion)
		if online:
			Net.get_node("World").profile_changed()
		if _rebuild_look and CombatFx.is_enabled() and player.presentation.model != null:
			player.presentation.model.build(player.data.look)
		_rebuild_look = false


# --- Map ---------------------------------------------------------------------------

func _build_environment(village: StringName) -> void:
	# Shinobi Striker lighting presets (see core/graphics/ss_env_presets.gd).
	var preset: StringName = SSEnvPresets.for_village(village)
	var world_env := WorldEnvironment.new()
	world_env.environment = SSGraphics.build_environment(preset)
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	SSGraphics.configure_sun(sun, preset)
	add_child(sun)


## The whole map: `villages` (each with its hunting arm, in its frame) and the neutral centre.
func _build_map(villages: Array[StringName]) -> void:
	var d := WorldDecor.new(self, 5)
	d.ground(Vector3(0, -0.05, 0), Vector2(1000, 1000), Color(0.22, 0.32, 0.2))  # beyond the borders
	for v: StringName in villages:
		var frame := Node3D.new()
		frame.name = "Village_" + String(v)
		frame.transform = village_frame(v)
		add_child(frame)
		_build_village(v, frame)
		_build_arm(v, frame)
	_build_centre()


func _build_village(village: StringName, parent: Node3D) -> void:
	var d := WorldDecor.new(parent, 11)
	var h: float = VILLAGE_HALF
	var grass: Color = VILLAGE_GROUND.get(village, Color(0.42, 0.58, 0.32))
	var stone := Color(0.5, 0.47, 0.43)
	var wall_color := Color(0.55, 0.42, 0.3) if village != &"suna" else Color(0.8, 0.7, 0.5)
	var roof_color: Color = {&"konoha": Color(0.25, 0.35, 0.5), &"suna": Color(0.72, 0.6, 0.42),
		&"ame": Color(0.3, 0.3, 0.38), &"kiri": Color(0.28, 0.42, 0.55)}.get(village, Color(0.3, 0.35, 0.5))
	d.ground(Vector3(0, -0.02, 0), Vector2(h * 2.0, h * 2.0), grass.darkened(0.12), &"sand" if village == &"suna" or d.ss_kit else &"grass")
	# Roads (main street to the gate, cross street) and the round plaza.
	d.ground(Vector3(h * 0.5, -0.01, 0), Vector2(h, 5.0), stone.darkened(0.15), &"slabs")
	d.ground(Vector3(0, -0.012, 0), Vector2(4.0, h * 2.0), stone.darkened(0.15), &"slabs")
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
		if d.ss_kit:   # real SS Konoha wall (64 m piece) stretched over the same collider
			var shape := BoxShape3D.new()
			shape.size = wall[1]
			d.collider(wall[0], shape, (wall[1] as Vector3).y)
			var along_x: bool = (wall[1] as Vector3).x > (wall[1] as Vector3).z
			var length: float = maxf((wall[1] as Vector3).x, (wall[1] as Vector3).z)
			d.ss_visual("SM_ENV_KNVLLG_Wall_03", wall[0], 90.0 if along_x else 0.0, Vector2.ZERO, 1.0, Vector3(1.4, 0.55, length / 64.25))
			continue
		d.solid_box(wall[0], wall[1], wall_color, 0.0, &"stone")
		d.box(wall[0] + Vector3.UP * 3.1, wall[1] + Vector3(0.3, -2.8, 0.3), wall_color.darkened(0.35), 0.0, 0.0, &"roof")
	d.torii(Vector3(h, 0, 0), GATE_HALF_WIDTH * 2.0, Color(0.75, 0.15, 0.12) if village == &"konoha" else wall_color.darkened(0.2))
	d.label(Vector3(h + 0.8, 15.5 if d.ss_kit else 7.6, 0), VILLAGE_NAMES.get(village, ""), 110, Color.WHITE)
	# Kage building, statue, houses.
	d.kage_tower(Vector3(-15, 0, -13), Color(0.85, 0.35, 0.28) if village == &"konoha" else wall_color.lightened(0.25), Color(0.7, 0.15, 0.12), "火" if village == &"konoha" else VILLAGE_NAMES.get(village, "").left(1))
	d.label(Vector3(-15, 20.0 if d.ss_kit else 14.0, -13), "Bureau du Kage", 64, Color.WHITE)
	d.statue(Vector3(-3, 0, 2), Color(0.55, 0.55, 0.6))
	if d.ss_kit:   # Konoha street props (visual only, off the walkways)
		for prop: Array in [["SM_ENV_KNVLLG_Stall_A", Vector3(5.5, 0, -6.0), 200.0], ["SM_ENV_KNVLLG_Stall_C", Vector3(-6.0, 0, 6.5), 30.0],
				["SM_ENV_KNVLLG_Stall_B", Vector3(6.0, 0, 6.2), 150.0], ["SM_ENV_Props_Bench_01", Vector3(-6.8, 0, -4.5), 60.0],
				["SM_ENV_Props_Bench_01", Vector3(4.0, 0, 7.6), 0.0], ["SM_ENV_Props_Barrel_01", Vector3(13.0, 0, -5.2), 0.0],
				["SM_ENV_Props_Barrel_02", Vector3(13.8, 0, -4.4), 0.0], ["SM_ENV_Props_Crate_01", Vector3(12.2, 0, 5.0), 15.0],
				["SM_ENV_Props_Crate_02", Vector3(12.9, 0, 6.0), 40.0], ["SM_ENV_Props_CardboardBox", Vector3(-12.0, 0, -5.0), 10.0],
				["SM_ENV_KNVLLG_WaterTank_A", Vector3(-20.0, 0, -3.5), 0.0], ["SM_ENV_Manhole", Vector3(14.0, 0.01, 0.0), 0.0]]:
			d.ss_visual(prop[0], prop[1], prop[2], Vector2.ZERO)
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
		d.cylinder(Vector3(-9 + i * 2.2, 0.8, 7), 0.28, 0.3, 1.6, Color(0.55, 0.38, 0.22), 8, 0.0, &"wood")
	d.label(Vector3(-7, 3.0, 7), "Terrain d'entraînement", 46, Color(1, 1, 0.8))
	d.label(Vector3(h - 4, 3.5, 0), "→ Terrains de chasse", 56, Color(1.0, 0.85, 0.4))
	# Mountains around the village.
	for i in 9:
		var a: float = PI * 0.55 + i * PI * 0.11
		d.mountain(Vector3(cos(a), 0, sin(a)) * 62.0, d.rng.randf_range(14.0, 22.0), d.rng.randf_range(16.0, 28.0), Color(0.42, 0.45, 0.42))


## Hunting arm of a village, in its frame: from the gate (x = VILLAGE_HALF) to the centre.
func _build_arm(village: StringName, parent: Node3D) -> void:
	var d := WorldDecor.new(parent, 23 + VILLAGES.find(village))
	var zones: Array = ARM_ZONES[village]
	var length: float = ARM_END - VILLAGE_HALF
	var center_x: float = VILLAGE_HALF + length / 2.0
	for zone: Dictionary in zones:
		var w: float = float(zone.to) - float(zone.from)
		d.ground(Vector3(float(zone.from) + w / 2.0, -0.03, 0), Vector2(w + 0.5, ARM_HALF * 2.0), (zone.ground as Color).darkened(0.18), zone.surface)
		d.label(Vector3(float(zone.from) + 2.0, 4.5, -8.0), "%s\n%s" % [zone.name, zone.level], 72, Color(1, 0.95, 0.8))
	var first: Dictionary = zones[0]
	d.ground(Vector3(VILLAGE_HALF + 1.5, -0.04, 0), Vector2(5.0, VILLAGE_HALF * 2.0), (first.ground as Color).darkened(0.2))
	# Winding dirt path with stepping stones, toward the centre.
	var path_color := Color(0.6, 0.5, 0.36).darkened(0.25)
	for i in 34:
		var x: float = VILLAGE_HALF + 2.0 + i * (length + 4.0) / 34.0
		d.disk(Vector3(x, -0.015, sin(x * 0.05) * 5.0), 3.0, path_color, &"sand")
	var on_path := func(p: Vector3) -> bool: return absf(p.z - sin(p.x * 0.05) * 5.0) < 3.2
	var grass_color: Color = (first.ground as Color).lightened(0.05)
	d.grass(Vector2(VILLAGE_HALF + 1, -ARM_HALF + 1), Vector2(ARM_END, ARM_HALF - 1), 1500 if village != &"suna" else 300, grass_color, on_path)
	if village != &"suna":
		d.flowers(Vector2(32, -ARM_HALF + 1), Vector2(float(first.to), ARM_HALF - 1), 160, on_path)
	# Borders: invisible walls behind a line of trees / rocks; the gate corners close the arm.
	var corner: float = ARM_HALF - VILLAGE_HALF
	for wall: Array in [[Vector3(center_x, 0, -ARM_HALF), Vector3(length, 3.0, 1.2)], [Vector3(center_x, 0, ARM_HALF), Vector3(length, 3.0, 1.2)],
			[Vector3(VILLAGE_HALF, 0, -(VILLAGE_HALF + corner / 2.0)), Vector3(1.2, 3.0, corner)],
			[Vector3(VILLAGE_HALF, 0, VILLAGE_HALF + corner / 2.0), Vector3(1.2, 3.0, corner)]]:
		var shape := BoxShape3D.new()
		shape.size = wall[1]
		d.collider(wall[0], shape, 3.0)
	var rocky: bool = village == &"suna" or village == &"ame"
	for x in range(int(VILLAGE_HALF) + 4, int(ARM_END), 5):
		for z: float in [-ARM_HALF - 1.5, ARM_HALF + 1.5]:
			if rocky:
				d.rock(Vector3(x, 0, z), d.rng.randf_range(1.5, 2.6), Color(0.62, 0.52, 0.4) if village == &"suna" else Color(0.45, 0.45, 0.48))
			else:
				d.pine(Vector3(x + d.rng.randf_range(-1, 1), 0, z), d.rng.randf_range(1.0, 1.4))
	for i in 5:
		for side: float in [-1.0, 1.0]:
			d.mountain(Vector3(VILLAGE_HALF + 12.0 + i * 18.0, 0, side * (ARM_HALF + 24.0)), d.rng.randf_range(14, 20), d.rng.randf_range(16, 26),
				Color(0.6, 0.5, 0.38) if village == &"suna" else Color(0.4, 0.42, 0.4))
	# Zone props.
	for zone: Dictionary in zones:
		var count: int = int((float(zone.to) - float(zone.from)) * 1.1)
		for i in count:
			var at := Vector3(d.rng.randf_range(float(zone.from) + 3.0, float(zone.to) - 2.0), 0, d.rng.randf_range(-ARM_HALF + 3.0, ARM_HALF - 3.0))
			if on_path.call(at):
				continue
			var roll: float = d.rng.randf()
			match str(zone.props):
				"plain":
					if roll < 0.35:
						d.round_tree(at, Color(0.3, 0.55, 0.28))
					else:
						d.bush(at, Color(0.28, 0.5, 0.25))
				"forest":
					if roll < 0.65:
						d.pine(at, d.rng.randf_range(1.0, 1.5))
					else:
						d.bush(at, Color(0.2, 0.42, 0.22))
				"marsh":
					if roll < 0.3:
						d.round_tree(at, Color(0.32, 0.5, 0.38), 0.8)
					else:
						d.bush(at, Color(0.3, 0.46, 0.34))
				"dunes":
					if roll < 0.3:
						d.rock(at, d.rng.randf_range(0.8, 1.8), Color(0.7, 0.58, 0.42))
					elif roll < 0.4:
						d.bush(at, Color(0.5, 0.48, 0.3))
				"canyon":
					if roll < 0.6:
						d.rock(at, d.rng.randf_range(1.2, 2.6), Color(0.62, 0.46, 0.34))
				"ruins":
					if roll < 0.45:
						d.ruin_pillar(at)
					else:
						d.rock(at, d.rng.randf_range(1.0, 2.2), Color(0.45, 0.45, 0.48))
	# Bandit camps and the deserters' hideout.
	for camp: Vector3 in [Vector3(48, 0, -16), Vector3(66, 0, 15)]:
		d.campfire(camp)
		d.tent(camp + Vector3(-3.5, 0, -2.5), Color(0.6, 0.48, 0.3), 30.0)
		d.tent(camp + Vector3(3.0, 0, -3.0), Color(0.55, 0.42, 0.28), -20.0)
		d.fence(camp + Vector3(-6, 0, 4), camp + Vector3(6, 0, 4))
	d.campfire(Vector3(104, 0, -14))
	d.tent(Vector3(100, 0, -17), Color(0.2, 0.2, 0.25), 10.0)
	d.label(Vector3(ARM_END - 4.0, 3.5, 0), "→ Terres neutres", 56, Color(1.0, 0.6, 0.4))


## Neutral centre (world frame): hard zone, Akatsuki lair in the middle.
func _build_centre() -> void:
	var d := WorldDecor.new(self, 31)
	var h: float = CENTRE_HALF
	d.ground(Vector3(0, -0.03, 0), Vector2(h * 2.0 + 0.5, h * 2.0 + 0.5), Color(0.5, 0.42, 0.34).darkened(0.18), &"sand")
	# Walls on the four sides, open where the arms arrive.
	var side: float = h - ARM_HALF
	for s: float in [-1.0, 1.0]:
		for o: float in [-1.0, 1.0]:
			for wall: Array in [[Vector3(s * h, 0, o * (ARM_HALF + side / 2.0)), Vector3(1.2, 3.0, side)],
					[Vector3(o * (ARM_HALF + side / 2.0), 0, s * h), Vector3(side, 3.0, 1.2)]]:
				var shape := BoxShape3D.new()
				shape.size = wall[1]
				d.collider(wall[0], shape, 3.0)
			for i in 3:
				var t: float = ARM_HALF + 2.0 + i * 5.0
				d.rock(Vector3(s * (h + 1.5), 0, o * t), d.rng.randf_range(1.8, 2.8), Color(0.5, 0.46, 0.42))
				d.rock(Vector3(o * t, 0, s * (h + 1.5)), d.rng.randf_range(1.8, 2.8), Color(0.5, 0.46, 0.42))
			d.mountain(Vector3(s * (h + 30.0), 0, o * (h + 30.0)), d.rng.randf_range(22, 30), d.rng.randf_range(24, 34), Color(0.42, 0.4, 0.4))
	for i in 70:
		var at := Vector3(d.rng.randf_range(-h + 3.0, h - 3.0), 0, d.rng.randf_range(-h + 3.0, h - 3.0))
		if Vector2(at.x, at.z).length() < BOSS_RADIUS + 2.0 or absf(at.x) < 3.5 or absf(at.z) < 3.5:
			continue
		if d.rng.randf() < 0.6:
			d.rock(at, d.rng.randf_range(1.0, 2.4), Color(0.55, 0.48, 0.42))
		else:
			d.ruin_pillar(at)
	d.label(Vector3(0, 7.0, -h + 6.0), "TERRES NEUTRES\nDifficile  ·  PvP", 90, Color(1.0, 0.8, 0.6))
	# Akatsuki lair.
	d.disk(Vector3(0, -0.02, 0), BOSS_RADIUS, Color(0.24, 0.2, 0.26), &"stone")
	for a in 4:
		var dir := Vector3(cos(a * PI / 2.0), 0, sin(a * PI / 2.0))
		d.campfire(dir * (BOSS_RADIUS - 3.0))
	d.torii(Vector3(-BOSS_RADIUS, 0, 0), 8.0, Color(0.35, 0.08, 0.08), false)
	d.label(Vector3(0, 6.0, 0), "暁", 200, Color(0.85, 0.1, 0.1))


func _label(at: Vector3, text: String, size: int, color: Color, _rotation: Vector3 = Vector3.ZERO) -> void:
	WorldDecor.new(self, 0).label(at, text, size, color)
