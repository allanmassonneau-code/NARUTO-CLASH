class_name ShinobiPortrait
extends SubViewportContainer
## Live 3D portrait of a shinobi (idle animation + occasional flourish),
## rendered in its own small world. Used by the character select and HUD.

enum Framing { FULL_BODY, BUST, FACE }

## Poses played now and then so the roster feels alive.
const FLOURISHES: Array[StringName] = [&"seal:windup", &"guard:windup", &"palm:windup", &"jab:strike", &"chidori:windup"]

var _model: ShinobiModel
var _camera: Camera3D
var _pivot: Node3D
var _pose: StringName = &""
var _pose_left: float = 0.0
var _next_flourish: float = 0.0
var _turn: float = 0.0
var _framing: Framing = Framing.FULL_BODY
var _tint := Color(1, 1, 1, 0)
## Fighter whose state (casting / stun / dead) the HUD portrait mirrors.
var mirror: CombatCharacter
var flourishes: bool = true


static func create(data: CharacterData, framing: Framing, pixel_size: Vector2i) -> ShinobiPortrait:
	var portrait := ShinobiPortrait.new()
	portrait.stretch = true
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait._framing = framing
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.size = pixel_size
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	portrait.add_child(viewport)
	portrait._build_scene(viewport, data)
	return portrait


func set_character(data: CharacterData) -> void:
	if _model == null:
		return
	_model.build(data.look if data.look != null else ShinobiLook.new())
	_pose = &"seal:windup"
	_pose_left = 0.5


## Strike a pose for a moment (selection feedback).
func play(pose: StringName, duration: float) -> void:
	if _model == null:
		return
	_pose = pose
	_pose_left = duration


func _build_scene(viewport: SubViewport, data: CharacterData) -> void:
	if not CombatFx.is_enabled():
		return  # headless (dedicated server boot, tests): no 3D
	# Shinobi Striker character lighting: one white key over the SS bluish indirect
	# light, plus a weak warm back light that draws a second toon band on the edges.
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = SSEnvPresets.get_preset(SSEnvPresets.KONOHA_DAY).ambient
	env.ambient_light_energy = 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	viewport.add_child(world_env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 30, 0)
	key.light_energy = 1.0
	key.light_color = Color8(246, 250, 251)
	viewport.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 200, 0)
	rim.light_energy = 0.35
	rim.light_color = Color(1.0, 0.8, 0.6)
	viewport.add_child(rim)
	_pivot = Node3D.new()
	viewport.add_child(_pivot)
	_model = ShinobiModel.new()
	_pivot.add_child(_model)
	_model.build(data.look if data.look != null else ShinobiLook.new())
	_camera = Camera3D.new()
	_camera.fov = 30.0
	match _framing:
		Framing.FULL_BODY:
			_aim_camera(Vector3(0, 1.15, 5.4), Vector3(0, 1.0, 0))
		Framing.BUST:
			_aim_camera(Vector3(0, 1.75, 2.9), Vector3(0, 1.55, 0))
		Framing.FACE:
			_camera.fov = 24.0
			_aim_camera(Vector3(0.15, 1.9, 2.4), Vector3(0, 1.74, 0))
	viewport.add_child(_camera)
	_pivot.rotation_degrees.y = 18.0
	_next_flourish = randf_range(2.0, 7.0)


func _aim_camera(from: Vector3, target: Vector3) -> void:
	_camera.transform = Transform3D(Basis.looking_at(target - from, Vector3.UP), from)


func _process(delta: float) -> void:
	if _model == null or not is_visible_in_tree():
		return
	var pose: StringName = &""
	var tint := Color(1, 1, 1, 0)
	if mirror != null:
		pose = _mirror_pose()
		if mirror.is_dead():
			tint = Color(0.05, 0.05, 0.08, 0.7)
		elif mirror.status.has_status(StatusController.Type.STUN):
			tint = Color(1.0, 0.9, 0.2, 0.35)
	elif _pose_left > 0.0:
		_pose_left -= delta
		pose = _pose
	elif flourishes:
		_next_flourish -= delta
		if _next_flourish <= 0.0:
			_next_flourish = randf_range(4.0, 9.0)
			play(FLOURISHES.pick_random(), 0.7)
	_tint = _tint.lerp(tint, 1.0 - exp(-10.0 * delta))
	_model.animate(delta, 0.0, pose, _tint, 0.0)
	_turn += delta
	if _framing == Framing.FULL_BODY:
		_pivot.rotation_degrees.y = 18.0 + sin(_turn * 0.5) * 10.0


func _mirror_pose() -> StringName:
	if mirror.is_dead():
		return &"stunned:"
	if mirror.status.has_status(StatusController.Type.STUN):
		return &"stunned:"
	var abilities: AbilityController = mirror.abilities
	if abilities.is_casting() and abilities.current.anim != &"":
		return StringName(String(abilities.current.anim) + (":windup" if abilities.phase == AbilityController.Phase.STARTUP else ":strike"))
	return &""
