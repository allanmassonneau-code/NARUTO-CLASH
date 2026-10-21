class_name SSChakraFx
## Shinobi Striker chakra effects on a fighter, rebuilt from SS's particle systems with their own
## textures (_ss_local/vfx):
##  - recovery (P_EFF_ChakraRecovery_A): ground aura plane, glow sphere, chakra flames rising from
##    the body and the arms (T_EFF_Smoke_19 flipbook, T_EFF_Sphere_04 / _06);
##  - chakra run (P_EFF_ChakraMove_A): soft spheres and a blur ribbon left behind (T_EFF_Sphere_01).
## Visual only, driven by observed state (works for every fighter, online too).

const CHAKRA := Color(0.35, 0.7, 1.0)
## Additive flames stack up on the body: each one is dim.
const FLAME := Color(0.35, 0.7, 1.0, 0.22)
const FLAME_EVERY: float = 0.05
const RUN_EVERY: float = 0.035

var _host: Node3D
var _aura: Node3D
var _flame_t: float = 0.0
var _run_t: float = 0.0
var _last_run_pos: Vector3 = Vector3.INF


func _init(host: Node3D) -> void:
	_host = host


## Per frame: `recovering` while concentrating chakra, `running` while chakra sprinting.
func update(delta: float, recovering: bool, running: bool) -> void:
	if not SSVfx.available() or _host == null or not _host.is_inside_tree():
		return
	_recovery(delta, recovering)
	_run(delta, running)


func _recovery(delta: float, on: bool) -> void:
	if not on:
		if is_instance_valid(_aura):
			_aura.queue_free()
		_aura = null
		return
	if not is_instance_valid(_aura):
		# Aura_Plane (ground) + sphere (around the body), looping while the state lasts.
		_aura = Node3D.new()
		_aura.name = "SSChakraRecovery"
		_host.add_child(_aura)
		SSVfx.loop(_aura, &"glow_soft", Vector3(0, 0.03, 0), 2.6, CHAKRA, true)
		SSVfx.loop(_aura, &"glow_soft", Vector3(0, 0.8, 0), 1.6, Color(CHAKRA, 0.12))
		SSVfx.sprite(_host, &"ring", _host.global_position + Vector3.UP * 0.05, 1.2, CHAKRA, 0.45, true, 0.0, 2.4)
	_flame_t -= delta
	while _flame_t <= 0.0:
		_flame_t += FLAME_EVERY
		# Aura_Body / Aura_Arms: chakra flames licking up the body and from the hands.
		var arms: bool = randf() < 0.35
		var a: float = randf() * TAU
		var r: float = randf_range(0.12, 0.3) if arms else randf_range(0.2, 0.42)
		var h: float = randf_range(0.95, 1.3) if arms else randf_range(0.05, 1.2)
		var at: Vector3 = _host.global_position + Vector3(cos(a) * r, h, sin(a) * r)
		SSVfx.sprite(_host, &"chakra_flame", at, randf_range(0.55, 0.95), FLAME, randf_range(0.45, 0.65), false, randf_range(0.6, 1.0), 1.3)


func _run(delta: float, on: bool) -> void:
	var pos: Vector3 = _host.global_position
	if not on:
		_last_run_pos = Vector3.INF
		return
	_run_t -= delta
	if _run_t > 0.0:
		return
	_run_t = RUN_EVERY
	# Spheres left at the feet and the back, fading out.
	for k in 2:
		var at: Vector3 = pos + Vector3(randf_range(-0.25, 0.25), randf_range(0.1, 1.1), randf_range(-0.25, 0.25))
		SSVfx.sprite(_host, &"orb_soft", at, randf_range(0.18, 0.34), CHAKRA, 0.35, false, 0.15, 0.4)
	# Blur ribbon: a streak along the path since the last sample.
	if _last_run_pos != Vector3.INF and _last_run_pos.distance_to(pos) > 0.05:
		var mid: Vector3 = (_last_run_pos + pos) * 0.5 + Vector3.UP * 0.75
		SSVfx.sprite(_host, &"blur", mid, 1.1, Color(CHAKRA, 0.55), 0.22, false, 0.0, 1.0)
	_last_run_pos = pos
