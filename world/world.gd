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
	camera.cursor_offset_strength = 0.12
	camera.max_cursor_offset = 2.5
	camera.follow_smoothing = 16.0
	camera.target = player
	add_child(camera)
	camera.current = true
	hud = WorldHud.new()
	add_child(hud)
	hud.bind(self, player)
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


## Rebuilds the player's kit after a promotion or a loadout change.
func _refresh_player_kit() -> void:
	var profile: CharacterProfile = Profiles.profile
	if profile == null or player == null:
		return
	player.data = ShinobiKit.build(profile, Profiles.db, Profiles.service())
	player.abilities.setup(player, player.data)
	player.health.setup(player.data.max_health)
	player.movement.data = player.data.movement
	hud.rebuild_slots()


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
	for event: Dictionary in result.events:
		match event.type:
			&"xp_gained":
				CombatFx.damage_number(player, player.global_position + Vector3.UP * 3.0, 0.0, Color(0.6, 0.85, 1.0), "+%d XP" % int(event.amount))
			&"promoted":
				hud.announce("PROMU %s !" % ShinobiScreen.GRADE_NAMES[int(event.grade)].to_upper())
				rebuild = true
			&"choice_required":
				hud.toast("Nouveau choix disponible dans SHINOBI (Échap).", Color(1.0, 0.85, 0.4))
			&"sub_jutsu_obtained":
				var sub: SubJutsuData = Profiles.db.get_sub_jutsu(event.sub_jutsu)
				hud.toast("Technique cachée obtenue : %s" % (sub.display_name if sub else ""), Color(0.8, 0.5, 1.0))
	if rebuild:
		_refresh_player_kit()


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
	var ground_color: Color = VILLAGE_GROUND.get(village, Color(0.42, 0.58, 0.32))
	_ground(Vector3(0, -0.02, 0), Vector2(VILLAGE_HALF * 2.0, VILLAGE_HALF * 2.0), ground_color)
	_ground(Vector3(0, -0.01, 0), Vector2(14, 14), ground_color.lerp(Color(0.7, 0.6, 0.45), 0.6))  # plaza
	_ground(Vector3(VILLAGE_HALF * 0.5, -0.01, 0), Vector2(VILLAGE_HALF, 6), Color(0.7, 0.6, 0.45))  # road to the gate
	var wall_color := Color(0.62, 0.5, 0.38) if village != &"suna" else Color(0.8, 0.7, 0.5)
	var h: float = VILLAGE_HALF
	_wall(Vector3(0, 0, -h), Vector3(h * 2.0, 3.0, 1.2), wall_color)
	_wall(Vector3(0, 0, h), Vector3(h * 2.0, 3.0, 1.2), wall_color)
	_wall(Vector3(-h, 0, 0), Vector3(1.2, 3.0, h * 2.0), wall_color)
	var side: float = (h * 2.0 - GATE_HALF_WIDTH * 2.0) / 2.0
	_wall(Vector3(h, 0, -(GATE_HALF_WIDTH + side / 2.0)), Vector3(1.2, 3.0, side), wall_color)
	_wall(Vector3(h, 0, GATE_HALF_WIDTH + side / 2.0), Vector3(1.2, 3.0, side), wall_color)
	# Gate.
	var gate_color := Color(0.25, 0.45, 0.25) if village == &"konoha" else wall_color.darkened(0.3)
	for z: float in [-GATE_HALF_WIDTH, GATE_HALF_WIDTH]:
		_solid_box(Vector3(h, 0, z), Vector3(1.6, 6.0, 1.6), gate_color)
	_box(Vector3(h, 6.2, 0), Vector3(2.0, 1.2, GATE_HALF_WIDTH * 2.0 + 1.6), gate_color)
	_label(Vector3(h + 1.1, 6.2, 0), VILLAGE_NAMES.get(village, ""), 96, Color.WHITE, Vector3(0, 90, 0))
	# Kage tower and houses.
	_solid_box(Vector3(-14, 0, -12), Vector3(9, 9, 9), Color(0.75, 0.3, 0.25) if village == &"konoha" else wall_color.lightened(0.15))
	_roof(Vector3(-14, 9, -12), 7.0, Color(0.55, 0.15, 0.12))
	_label(Vector3(-14, 11.5, -12), "Bureau du Kage", 64, Color.WHITE)
	var houses: Array = [[-16, 10], [-4, -16], [8, -16], [-6, 16], [8, 15], [17, -6], [17, 10], [-18, 1]]
	for p: Array in houses:
		var size := Vector3(_rng.randf_range(5, 7), _rng.randf_range(3.5, 5.0), _rng.randf_range(5, 7))
		_solid_box(Vector3(p[0], 0, p[1]), size, Color(0.85, 0.8, 0.7).darkened(_rng.randf_range(0.0, 0.2)))
		_roof(Vector3(p[0], size.y, p[1]), maxf(size.x, size.z) * 0.62, Color(0.3, 0.42, 0.55).darkened(_rng.randf_range(0.0, 0.3)))
	# Training posts on the plaza.
	for i in 3:
		_solid_cylinder(Vector3(-2 + i * 2.2, 0, 5), 0.3, 1.6, Color(0.5, 0.35, 0.2))
	_label(Vector3(0, 3.0, 5), "Terrain d'entraînement", 48, Color(1, 1, 0.8))
	_label(Vector3(h - 4, 3.5, 0), "→ Terrains de chasse", 56, Color(1.0, 0.85, 0.4), Vector3(0, -90, 0))


func _build_field() -> void:
	var length: float = FIELD_END_X - VILLAGE_HALF
	_ground(Vector3(VILLAGE_HALF + length / 2.0, -0.03, 0), Vector2(length, FIELD_HALF_Z * 2.0), Color(0.45, 0.58, 0.32))
	_ground(Vector3(VILLAGE_HALF + length / 2.0, -0.04, 0), Vector2(600, 400), Color(0.3, 0.42, 0.25))  # outside
	for zone: Dictionary in ZONES:
		var w: float = zone.to - zone.from
		_ground(Vector3(zone.from + w / 2.0, -0.02, 0), Vector2(w, FIELD_HALF_Z * 2.0 - 2.0), zone.ground)
		_label(Vector3(zone.from + 2.0, 4.0, -FIELD_HALF_Z + 4.0), "%s\n%s" % [zone.name, zone.level], 72, Color(1, 0.95, 0.8), Vector3(0, -90, 0))
	# Field borders (the village wall closes the west side).
	var center_x: float = VILLAGE_HALF + length / 2.0
	_wall(Vector3(center_x, 0, -FIELD_HALF_Z), Vector3(length, 3.0, 1.2), Color(0.4, 0.33, 0.25))
	_wall(Vector3(center_x, 0, FIELD_HALF_Z), Vector3(length, 3.0, 1.2), Color(0.4, 0.33, 0.25))
	_wall(Vector3(FIELD_END_X, 0, 0), Vector3(1.2, 3.0, FIELD_HALF_Z * 2.0), Color(0.4, 0.33, 0.25))
	_wall(Vector3(VILLAGE_HALF + 3.0, 0, -(VILLAGE_HALF + FIELD_HALF_Z) / 2.0 - 0.0), Vector3(1.2, 3.0, FIELD_HALF_Z - VILLAGE_HALF), Color(0.4, 0.33, 0.25))
	_wall(Vector3(VILLAGE_HALF + 3.0, 0, (VILLAGE_HALF + FIELD_HALF_Z) / 2.0), Vector3(1.2, 3.0, FIELD_HALF_Z - VILLAGE_HALF), Color(0.4, 0.33, 0.25))
	# Cover: trees in the forest, rocks in the ravine, scattered elsewhere.
	for i in 140:
		var at := Vector3(_rng.randf_range(VILLAGE_HALF + 8.0, FIELD_END_X - 4.0), 0, _rng.randf_range(-FIELD_HALF_Z + 3.0, FIELD_HALF_Z - 3.0))
		if absf(at.z) < 4.0:
			continue  # keep the main path clear
		if at.x > 140.0 and at.x < 192.0:
			_rock(at, _rng.randf_range(1.0, 2.4))
		elif (at.x > 85.0 and at.x < 140.0) or _rng.randf() < 0.35:
			_tree(at)
	_ground(Vector3(VILLAGE_HALF + length / 2.0, -0.015, 0), Vector2(length, 6.0), Color(0.62, 0.53, 0.4))  # path


# --- Primitives ---------------------------------------------------------------------

func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.95
	return m


func _ground(center: Vector3, size: Vector2, color: Color) -> void:
	if not CombatFx.is_enabled():
		return
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = size
	mesh.mesh = plane
	mesh.material_override = _mat(color.darkened(0.3))  # ground reads lighter than props under the sun
	mesh.position = center
	add_child(mesh)


func _box(center: Vector3, size: Vector3, color: Color) -> void:
	if not CombatFx.is_enabled():
		return
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _mat(color)
	mesh.position = center
	add_child(mesh)


## Static obstacle (collision layer 1, blocks movement and projectiles).
func _solid(center: Vector3, shape: Shape3D, height: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = center
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = height / 2.0
	body.add_child(col)
	add_child(body)
	return body


func _solid_box(base: Vector3, size: Vector3, color: Color) -> void:
	var box := BoxShape3D.new()
	box.size = size
	_solid(base, box, size.y)
	_box(base + Vector3.UP * size.y / 2.0, size, color)


func _wall(base: Vector3, size: Vector3, color: Color) -> void:
	_solid_box(base, size, color)


func _solid_cylinder(base: Vector3, radius: float, height: float, color: Color) -> void:
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	_solid(base, shape, height)
	if CombatFx.is_enabled():
		var mesh := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = radius
		cyl.bottom_radius = radius
		cyl.height = height
		mesh.mesh = cyl
		mesh.material_override = _mat(color)
		mesh.position = base + Vector3.UP * height / 2.0
		add_child(mesh)


func _roof(at: Vector3, radius: float, color: Color) -> void:
	if not CombatFx.is_enabled():
		return
	var mesh := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = radius
	cone.height = radius * 0.55
	cone.radial_segments = 4
	mesh.mesh = cone
	mesh.material_override = _mat(color)
	mesh.position = at + Vector3.UP * cone.height / 2.0
	mesh.rotation_degrees.y = 45.0
	add_child(mesh)


func _tree(at: Vector3) -> void:
	_solid_cylinder(at, 0.45, 2.4, Color(0.42, 0.28, 0.16))
	if CombatFx.is_enabled():
		for i in 2:
			var leaves := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 1.9 - i * 0.5
			sphere.height = 3.0 - i * 0.6
			leaves.mesh = sphere
			leaves.material_override = _mat(Color(0.22, 0.48, 0.22).lightened(i * 0.1))
			leaves.position = at + Vector3(0, 3.3 + i * 1.3, 0)
			add_child(leaves)


func _rock(at: Vector3, radius: float) -> void:
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = 2.0
	_solid(at, shape, 2.0)
	if CombatFx.is_enabled():
		var mesh := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = radius
		sphere.height = radius * 1.3
		mesh.mesh = sphere
		mesh.material_override = _mat(Color(0.5, 0.48, 0.47))
		mesh.position = at + Vector3.UP * radius * 0.35
		add_child(mesh)


func _label(at: Vector3, text: String, size: int, color: Color, rotation_deg: Vector3 = Vector3.ZERO) -> void:
	if not CombatFx.is_enabled():
		return
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.outline_size = 16
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.01
	label.position = at
	label.rotation_degrees = rotation_deg
	add_child(label)
