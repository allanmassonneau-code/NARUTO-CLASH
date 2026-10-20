class_name ShinobiModel
extends Node3D
## Builds a stylised shinobi out of primitives from a ShinobiLook and animates it
## procedurally (idle, run cycle, cast poses, hitstop). Rendered with the Shinobi Striker
## character shading (SSGraphics.character_material: BC/SC toon + M_Line outline).
## Never affects gameplay.

const HEADBAND_CLOTH := Color(0.12, 0.16, 0.3)
const HEADBAND_PLATE := Color(0.8, 0.82, 0.86)
const SANDAL := Color(0.18, 0.22, 0.4)
## SS avatars are ~6 heads tall: the primitive head is scaled down from the chibi size.
const HEAD_SCALE: float = 0.86
const LASH := Color(0.12, 0.08, 0.08)

var _parts: Array[GeometryInstance3D] = []
var _overlay := StandardMaterial3D.new()
var _look: ShinobiLook
## False while building small face details (no hull outline on them).
var _outlined: bool = true

var _hips: Node3D
var _torso: Node3D
var _head: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _knee_l: Node3D
var _knee_r: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _elbow_l: Node3D
var _elbow_r: Node3D
var _sword: Node3D
var _hand_r: Node3D
var _hand_l: Node3D
var _cycle: float = 0.0
var _time: float = 0.0
var _freeze: float = 0.0

## Real Shinobi Striker figure (local assets, SSCharacters): when present it replaces the
## primitive body and its SS animation clips replace the procedural poses.
const SS_SCALE: float = 1.12
## Pose -> SS clips to try, in order (first one the figure has wins).
const SS_POSE_CLIPS: Dictionary = {
	"chidori:windup": [&"charge"], "chidori:strike": [&"chidori", &"charge_run", &"dash"],
	"dash:windup": [&"dash"], "dash:strike": [&"dash"],
	"leap:windup": [&"leap"], "leap:strike": [&"leap", &"fall"],
	"guard:windup": [&"guard"], "guard:strike": [&"guard"],
	"seal:windup": [&"seal", &"concentrate"], "seal:strike": [&"seal"],
	"throw:windup": [&"throw", &"jab"], "throw:strike": [&"throw", &"jab"],
	"stunned:": [&"stunned", &"hit"],
}
var _ss: Node3D
var _ss_anim: AnimationPlayer
var _ss_clip: StringName = &""
var _ss_pose: String = ""


func build(look: ShinobiLook) -> void:
	_look = look
	for child: Node in get_children():
		child.queue_free()
	_parts.clear()
	_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_overlay.albedo_color = Color(1, 1, 1, 0)
	_ss = null
	_ss_anim = null
	var ss: Node3D = SSCharacters.instantiate(look)
	if ss != null:
		_build_ss(ss)
		return
	scale = Vector3.ONE * 1.12

	_hips = _pivot(self, Vector3(0, 0.82, 0))
	_box(_hips, Vector3(0, 0.02, 0), Vector3(0.42, 0.16, 0.26), look.pants)
	_build_legs(look)
	_torso = _pivot(_hips, Vector3(0, 0.06, 0))
	_build_torso(look)
	_build_arms(look)
	_head = _pivot(_torso, Vector3(0, 0.7, 0))
	_head.scale = Vector3.ONE * HEAD_SCALE
	_build_head(look)
	if look.weapon == ShinobiLook.Weapon.SWORD:
		_build_sword()
	elif look.weapon == ShinobiLook.Weapon.KUNAI:
		_build_kunai()


## Short visual freeze on hits (hitstop): sells the impact.
func hitstop(duration: float) -> void:
	_freeze = maxf(_freeze, duration)


## Per-jutsu poses: rotations (x, y, z) per joint, applied over the
## locomotion pose and blended. "<anim>:windup" during startup,
## "<anim>:strike" during active/recovery. "hips" is a height offset.
const POSES: Dictionary = {
	"jab:windup": {"torso": Vector3(-0.1, 0.45, 0), "arm_r": Vector3(0.5, 0, 0.4), "elbow_r": Vector3(-1.7, 0, 0), "arm_l": Vector3(-1.1, 0, -0.3), "elbow_l": Vector3(-1.2, 0, 0)},
	"jab:strike": {"torso": Vector3(-0.3, -0.4, 0), "arm_r": Vector3(-1.6, 0, -0.1), "elbow_r": Vector3(-0.05, 0, 0), "arm_l": Vector3(0.3, 0, -0.3), "elbow_l": Vector3(-1.3, 0, 0), "leg_l": Vector3(-0.5, 0, 0), "leg_r": Vector3(0.4, 0, 0)},
	"hook:windup": {"torso": Vector3(-0.1, -0.45, 0), "arm_l": Vector3(0.5, 0, -0.4), "elbow_l": Vector3(-1.7, 0, 0), "arm_r": Vector3(-1.1, 0, 0.3), "elbow_r": Vector3(-1.2, 0, 0)},
	"hook:strike": {"torso": Vector3(-0.3, 0.45, 0), "arm_l": Vector3(-1.5, 0, 0.5), "elbow_l": Vector3(-0.3, 0, 0), "arm_r": Vector3(0.3, 0, 0.3), "elbow_r": Vector3(-1.3, 0, 0), "leg_r": Vector3(-0.5, 0, 0), "leg_l": Vector3(0.4, 0, 0)},
	"kick:windup": {"torso": Vector3(0.2, 0.5, 0), "leg_r": Vector3(0.7, 0, 0), "knee_r": Vector3(-1.5, 0, 0), "arm_l": Vector3(-0.8, 0, -0.6), "arm_r": Vector3(0.4, 0, 0.5)},
	"kick:strike": {"torso": Vector3(0.35, -0.3, 0), "leg_r": Vector3(-1.5, 0, 0), "knee_r": Vector3(0, 0, 0), "leg_l": Vector3(0.2, 0, 0), "arm_l": Vector3(0.3, 0, -1.0), "arm_r": Vector3(0.3, 0, 1.0), "hips": 0.06},
	"slash:windup": {"torso": Vector3(-0.1, 0.7, 0), "arm_r": Vector3(-1.2, 0, 1.3), "elbow_r": Vector3(-0.6, 0, 0), "arm_l": Vector3(-0.6, 0, -0.5)},
	"slash:strike": {"torso": Vector3(-0.3, -0.7, 0), "arm_r": Vector3(-1.3, 0, -0.7), "elbow_r": Vector3(-0.1, 0, 0), "arm_l": Vector3(0.4, 0, -0.6), "leg_l": Vector3(-0.5, 0, 0), "leg_r": Vector3(0.4, 0, 0)},
	"slash2:windup": {"torso": Vector3(-0.1, -0.6, 0), "arm_r": Vector3(-0.6, 0, -0.8), "elbow_r": Vector3(-1.2, 0, 0)},
	"slash2:strike": {"torso": Vector3(-0.3, 0.7, 0), "arm_r": Vector3(-1.4, 0, 1.2), "elbow_r": Vector3(-0.05, 0, 0), "arm_l": Vector3(0.3, 0, -0.5), "leg_r": Vector3(-0.5, 0, 0), "leg_l": Vector3(0.4, 0, 0)},
	"thrust:windup": {"torso": Vector3(0.05, 0.6, 0), "arm_r": Vector3(0.6, 0, 0.3), "elbow_r": Vector3(-1.8, 0, 0), "arm_l": Vector3(-1.3, 0, -0.2), "elbow_l": Vector3(-0.2, 0, 0), "hips": -0.08},
	"thrust:strike": {"torso": Vector3(-0.55, -0.2, 0), "arm_r": Vector3(-1.65, 0, 0), "elbow_r": Vector3(0, 0, 0), "arm_l": Vector3(0.6, 0, -0.4), "leg_l": Vector3(-0.9, 0, 0), "knee_l": Vector3(-0.6, 0, 0), "leg_r": Vector3(0.7, 0, 0), "hips": -0.14},
	"palm:windup": {"torso": Vector3(-0.1, 0.25, 0), "arm_r": Vector3(-1.3, 0, 0.1), "elbow_r": Vector3(-0.7, 0, 0), "arm_l": Vector3(-1.1, 0, 0.55), "elbow_l": Vector3(-1.1, 0, 0), "hips": -0.06},
	"palm:strike": {"torso": Vector3(-0.5, -0.15, 0), "arm_r": Vector3(-1.6, 0, 0), "elbow_r": Vector3(0, 0, 0), "arm_l": Vector3(0.5, 0, -0.5), "leg_l": Vector3(-0.8, 0, 0), "knee_l": Vector3(-0.5, 0, 0), "leg_r": Vector3(0.8, 0, 0), "hips": -0.12},
	"chidori:windup": {"torso": Vector3(-0.35, 0.5, 0), "arm_r": Vector3(0.6, 0, 0.35), "elbow_r": Vector3(-0.3, 0, 0), "arm_l": Vector3(-0.9, 0, 0.5), "elbow_l": Vector3(-1.4, 0, 0), "leg_l": Vector3(-0.6, 0, 0), "knee_l": Vector3(-0.7, 0, 0), "leg_r": Vector3(0.5, 0, 0), "hips": -0.18},
	"chidori:strike": {"torso": Vector3(-0.65, -0.1, 0), "arm_r": Vector3(-1.7, 0, 0), "elbow_r": Vector3(0, 0, 0), "arm_l": Vector3(0.8, 0, -0.3), "leg_l": Vector3(-1.0, 0, 0), "knee_l": Vector3(-0.4, 0, 0), "leg_r": Vector3(0.9, 0, 0), "hips": -0.16},
	"seal:windup": {"torso": Vector3(-0.05, 0, 0), "arm_r": Vector3(-1.05, 0, -0.55), "elbow_r": Vector3(-1.7, 0, 0), "arm_l": Vector3(-1.05, 0, 0.55), "elbow_l": Vector3(-1.7, 0, 0), "head": Vector3(0.15, 0, 0)},
	"seal:strike": {"torso": Vector3(-0.2, 0, 0), "arm_r": Vector3(-1.5, 0, 0.3), "elbow_r": Vector3(-0.2, 0, 0), "arm_l": Vector3(-1.5, 0, -0.3), "elbow_l": Vector3(-0.2, 0, 0)},
	"breath:windup": {"torso": Vector3(0.2, 0, 0), "arm_r": Vector3(-1.05, 0, -0.55), "elbow_r": Vector3(-1.8, 0, 0), "arm_l": Vector3(-1.05, 0, 0.55), "elbow_l": Vector3(-1.8, 0, 0), "head": Vector3(-0.2, 0, 0)},
	"breath:strike": {"torso": Vector3(-0.35, 0, 0), "arm_r": Vector3(-1.3, 0, -0.35), "elbow_r": Vector3(-2.0, 0, 0), "arm_l": Vector3(-1.3, 0, 0.35), "elbow_l": Vector3(-2.0, 0, 0), "head": Vector3(0.1, 0, 0)},
	"stomp:windup": {"torso": Vector3(0.25, 0, 0), "leg_r": Vector3(-1.7, 0, 0), "knee_r": Vector3(-0.2, 0, 0), "arm_r": Vector3(-2.4, 0, 0.2), "elbow_r": Vector3(-0.2, 0, 0), "arm_l": Vector3(0.2, 0, -0.8), "hips": 0.08},
	"stomp:strike": {"torso": Vector3(-0.6, 0, 0), "leg_r": Vector3(-0.3, 0, 0), "knee_r": Vector3(-0.4, 0, 0), "leg_l": Vector3(0.6, 0, 0), "knee_l": Vector3(-1.2, 0, 0), "arm_r": Vector3(-0.9, 0, 0), "elbow_r": Vector3(0, 0, 0), "arm_l": Vector3(0.4, 0, -0.9), "hips": -0.28},
	"throw:windup": {"torso": Vector3(0, 0.6, 0), "arm_r": Vector3(0.2, 0, 1.2), "elbow_r": Vector3(-1.0, 0, 0), "arm_l": Vector3(-1.2, 0, -0.2)},
	"throw:strike": {"torso": Vector3(-0.3, -0.5, 0), "arm_r": Vector3(-1.5, 0, -0.4), "elbow_r": Vector3(0, 0, 0), "arm_l": Vector3(0.3, 0, -0.4), "leg_l": Vector3(-0.5, 0, 0)},
	"guard:windup": {"arm_r": Vector3(-1.2, 0, -0.6), "arm_l": Vector3(-1.2, 0, 0.6), "elbow_r": Vector3(-1.3, 0, 0), "elbow_l": Vector3(-1.3, 0, 0), "hips": -0.1},
	"guard:strike": {"arm_r": Vector3(-1.2, 0, -0.6), "arm_l": Vector3(-1.2, 0, 0.6), "elbow_r": Vector3(-1.3, 0, 0), "elbow_l": Vector3(-1.3, 0, 0), "hips": -0.1},
	"heal:windup": {"torso": Vector3(-0.15, 0, 0), "arm_r": Vector3(-1.2, 0, 0.15), "elbow_r": Vector3(-0.5, 0, 0), "arm_l": Vector3(-1.2, 0, -0.15), "elbow_l": Vector3(-0.5, 0, 0), "head": Vector3(0.25, 0, 0)},
	"heal:strike": {"torso": Vector3(0.1, 0, 0), "arm_r": Vector3(-2.6, 0, -0.4), "elbow_r": Vector3(-0.1, 0, 0), "arm_l": Vector3(-2.6, 0, 0.4), "elbow_l": Vector3(-0.1, 0, 0), "head": Vector3(-0.2, 0, 0)},
	"dash:windup": {"torso": Vector3(-0.5, 0, 0), "arm_r": Vector3(0.9, 0, 0.3), "arm_l": Vector3(0.9, 0, -0.3), "hips": -0.12},
	"dash:strike": {"torso": Vector3(-0.7, 0, 0), "arm_r": Vector3(1.2, 0, 0.2), "arm_l": Vector3(1.2, 0, -0.2), "elbow_r": Vector3(-0.2, 0, 0), "elbow_l": Vector3(-0.2, 0, 0), "leg_l": Vector3(-0.8, 0, 0), "leg_r": Vector3(0.9, 0, 0)},
	"leap:windup": {"torso": Vector3(-0.3, 0, 0), "knee_l": Vector3(-1.2, 0, 0), "knee_r": Vector3(-1.2, 0, 0), "leg_l": Vector3(-0.6, 0, 0), "leg_r": Vector3(-0.6, 0, 0), "hips": -0.25},
	"leap:strike": {"torso": Vector3(-0.2, 0, 0), "leg_l": Vector3(-1.1, 0, 0), "knee_l": Vector3(-1.6, 0, 0), "leg_r": Vector3(-0.4, 0, 0), "knee_r": Vector3(-1.4, 0, 0), "arm_r": Vector3(-2.6, 0, 0.3), "arm_l": Vector3(-2.6, 0, -0.3), "hips": 0.6},
	"stunned:": {"torso": Vector3(0.2, 0, 0.15), "head": Vector3(0.4, 0, 0), "arm_l": Vector3(0.2, 0, -0.6), "arm_r": Vector3(0.2, 0, 0.6), "knee_l": Vector3(-0.4, 0, 0), "knee_r": Vector3(-0.4, 0, 0), "hips": -0.08},
}

var _rig: Dictionary = {}


## Per-frame visual state from CharacterPresentation.
## `pose` is "" (locomotion), "<anim>:windup", "<anim>:strike" or "stunned:".
func animate(delta: float, planar_speed: float, pose: StringName, tint: Color, fade: float) -> void:
	_overlay.albedo_color = tint
	for part: GeometryInstance3D in _parts:
		part.transparency = fade
	if _ss != null:
		_animate_ss(delta, planar_speed, pose)
		return
	if _freeze > 0.0:
		_freeze -= delta
		return
	_time += delta
	if _rig.is_empty():
		_rig = {"hips": _hips, "torso": _torso, "head": _head, "leg_l": _leg_l, "leg_r": _leg_r, "knee_l": _knee_l,
			"knee_r": _knee_r, "arm_l": _arm_l, "arm_r": _arm_r, "elbow_l": _elbow_l, "elbow_r": _elbow_r}
	var run: float = clampf(planar_speed / 7.0, 0.0, 1.0)
	var casting: bool = pose != &""
	if casting:
		run *= 0.35
	_cycle += delta * (3.0 + 9.5 * run)
	var swing: float = sin(_cycle) * 0.85 * run
	var breathe: float = sin(_time * 2.2) * 0.015 * (1.0 - run)

	# Locomotion targets.
	var target: Dictionary = {
		"leg_l": Vector3(swing, 0, 0),
		"leg_r": Vector3(-swing, 0, 0),
		"knee_l": Vector3(-maxf(0.0, -sin(_cycle)) * 1.1 * run - 0.05, 0, 0),
		"knee_r": Vector3(-maxf(0.0, sin(_cycle)) * 1.1 * run - 0.05, 0, 0),
		"torso": Vector3(-0.32 * run, sin(_cycle) * 0.12 * run, 0),
		"arm_l": Vector3(-swing * 0.6 + 0.35 * run, 0, -0.18),
		"arm_r": Vector3(swing * 0.6 + 0.35 * run, 0, 0.18),
		"elbow_l": Vector3(-0.35 - 0.5 * run, 0, 0),
		"elbow_r": Vector3(-0.35 - 0.5 * run, 0, 0),
		"head": Vector3(0.22 * run, 0, 0),
	}
	var hips_y: float = 0.82 + absf(sin(_cycle)) * 0.05 * run + breathe
	var overrides: Dictionary = POSES.get(String(pose), {})
	for key: String in overrides:
		if key == "hips":
			hips_y += overrides[key]
		else:
			target[key] = overrides[key]
	if pose == &"stunned:":
		target["torso"] = Vector3(0.2, 0, sin(_time * 9.0) * 0.15)
	# Strikes snap fast, wind-ups and locomotion blend smoothly.
	var speed: float = 40.0 if String(pose).ends_with(":strike") else 16.0
	var k: float = 1.0 - exp(-speed * delta)
	for key: String in target:
		var node: Node3D = _rig[key]
		node.rotation = node.rotation.lerp(target[key], k)
	_hips.position.y = lerpf(_hips.position.y, hips_y, k)
	if _sword != null:
		var striking: bool = String(pose).ends_with(":strike")
		_sword.rotation.x = lerpf(_sword.rotation.x, -1.5 if striking else (-0.4 if casting else -0.9), k)


## Right hand anchor (held jutsu: Rasengan, Chidori...).
func hand_r() -> Node3D:
	return _hand_r


func hand_l() -> Node3D:
	return _hand_l


func _build_legs(look: ShinobiLook) -> void:
	_leg_l = _pivot(_hips, Vector3(-0.12, -0.02, 0))
	_leg_r = _pivot(_hips, Vector3(0.12, -0.02, 0))
	for leg: Node3D in [_leg_l, _leg_r]:
		var thigh_color: Color = look.skin if look.shorts else look.pants
		_capsule(leg, Vector3(0, -0.2, 0), 0.105, 0.44, look.pants if not look.shorts else look.pants)
		var knee := _pivot(leg, Vector3(0, -0.4, 0))
		_capsule(knee, Vector3(0, -0.17, 0), 0.085, 0.4, thigh_color if look.shorts else look.pants)
		if look.leg_warmers.a > 0.0:
			_cylinder(knee, Vector3(0, -0.2, 0), 0.095, 0.22, look.leg_warmers)
		elif not look.shorts:
			_cylinder(knee, Vector3(0, -0.24, 0), 0.075, 0.12, Color(0.92, 0.92, 0.9))  # leg wrap
		_box(knee, Vector3(0, -0.37, -0.04), Vector3(0.15, 0.06, 0.28), SANDAL)
		_box(knee, Vector3(0, -0.34, -0.15), Vector3(0.11, 0.05, 0.07), look.skin)  # toes
		if leg == _leg_l:
			_knee_l = knee
		else:
			_knee_r = knee


func _build_torso(look: ShinobiLook) -> void:
	var chest := _capsule(_torso, Vector3(0, 0.3, 0), 0.25, 0.7, look.top)
	chest.scale = Vector3(1.05, 1.0, 0.72)
	# Shoulder / collar panel.
	var yoke := _capsule(_torso, Vector3(0, 0.5, 0), 0.24, 0.5, look.top_accent)
	yoke.rotation_degrees.z = 90.0
	yoke.scale = Vector3(0.6, 1.0, 0.72)
	_cylinder(_torso, Vector3(0, 0.6, 0), 0.13, 0.12, look.top_accent)  # collar
	_box(_torso, Vector3(0, 0.3, -0.18), Vector3(0.025, 0.42, 0.02), Color(0.95, 0.95, 0.95))  # zip / seam
	_box(_torso, Vector3(0, 0.04, 0), Vector3(0.48, 0.07, 0.36), look.accent)  # belt
	if look.flak_vest:
		var vest := _capsule(_torso, Vector3(0, 0.34, 0), 0.28, 0.6, look.top_accent)
		vest.scale = Vector3(1.05, 1.0, 0.82)
		for x: float in [-0.12, 0.12]:
			_box(_torso, Vector3(x, 0.24, -0.21), Vector3(0.1, 0.13, 0.06), look.top_accent.darkened(0.25))  # scroll pouches
	if look.weapon == ShinobiLook.Weapon.SWORD:
		var rope := _cylinder(_torso, Vector3(0, 0.02, 0), 0.27, 0.06, look.accent)
		rope.scale = Vector3(1.0, 1.0, 0.8)
	if look.cloak.a > 0.0:
		var coat := _capsule(_torso, Vector3(0, 0.3, 0.01), 0.29, 0.78, look.cloak)
		coat.scale = Vector3(1.08, 1.0, 0.8)
		var collar := _cylinder(_torso, Vector3(0, 0.66, 0), 0.17, 0.2, look.cloak)
		collar.scale = Vector3(1.0, 1.0, 0.9)
		var skirt := CylinderMesh.new()
		skirt.top_radius = 0.3
		skirt.bottom_radius = 0.45
		skirt.height = 0.62
		skirt.radial_segments = 16
		_add(_hips, skirt, Vector3(0, -0.32, 0.02), look.cloak)
		if look.cloak_pattern == &"clouds":
			for p: Vector3 in [Vector3(-0.15, 0.35, -0.22), Vector3(0.14, 0.15, -0.22), Vector3(0.1, 0.45, 0.24), Vector3(-0.12, 0.1, 0.24)]:
				var cloud := _sphere(_torso, p, 0.07, Color(0.85, 0.1, 0.12))
				cloud.scale = Vector3(1.5, 0.8, 0.3)
		elif look.cloak_pattern == &"flames":
			var hem := CylinderMesh.new()
			hem.top_radius = 0.43
			hem.bottom_radius = 0.46
			hem.height = 0.12
			hem.radial_segments = 16
			_add(_hips, hem, Vector3(0, -0.58, 0.02), Color(0.95, 0.3, 0.1))
	if look.gourd:
		_sphere(_torso, Vector3(0, 0.15, 0.3), 0.2, Color(0.72, 0.55, 0.38))
		_sphere(_torso, Vector3(0, 0.45, 0.28), 0.14, Color(0.72, 0.55, 0.38))
		var strap := _box(_torso, Vector3(0, 0.35, 0), Vector3(0.06, 0.75, 0.42), Color(0.55, 0.4, 0.3))
		strap.rotation_degrees.z = 35.0


func _build_arms(look: ShinobiLook) -> void:
	_arm_l = _pivot(_torso, Vector3(-0.33, 0.55, 0))
	_arm_r = _pivot(_torso, Vector3(0.33, 0.55, 0))
	for arm: Node3D in [_arm_l, _arm_r]:
		_sphere(arm, Vector3.ZERO, 0.1, look.top_accent)  # shoulder
		_capsule(arm, Vector3(0, -0.15, 0), 0.075, 0.34, look.sleeves)
		var elbow := _pivot(arm, Vector3(0, -0.3, 0))
		_capsule(elbow, Vector3(0, -0.13, 0), 0.068, 0.3, look.sleeves)
		var hand_color: Color = look.gloves if look.gloves.a > 0.0 else look.skin
		_sphere(elbow, Vector3(0, -0.3, 0), 0.075, hand_color)
		var hand := _pivot(elbow, Vector3(0, -0.36, 0))
		if arm == _arm_l:
			_elbow_l = elbow
			_hand_l = hand
		else:
			_elbow_r = elbow
			_hand_r = hand


func _build_head(look: ShinobiLook) -> void:
	var skull := _sphere(_head, Vector3.ZERO, 0.23, look.skin)
	skull.scale = Vector3(1.0, 1.05, 0.98)
	_sphere(_head, Vector3(0, -0.07, -0.06), 0.17, look.skin)  # jaw
	var covered_left: bool = look.headband and look.hair == ShinobiLook.Hair.SWEPT
	_outlined = false
	for x: float in [-0.085, 0.085]:
		if covered_left and x < 0.0:
			continue
		_box(_head, Vector3(x, 0.02, -0.205), Vector3(0.085, 0.07, 0.02), Color.WHITE)
		_box(_head, Vector3(x, 0.015, -0.218), Vector3(0.045, 0.06, 0.02), Color(0.88, 0.85, 0.95) if look.eye_white else look.eye_color)
		_box(_head, Vector3(x, 0.055, -0.214), Vector3(0.095, 0.016, 0.02), LASH)  # SS anime upper lash line
		var brow := Vector3(0.1, 0.045, 0.03) if look.thick_brows else Vector3(0.09, 0.02, 0.02)
		_box(_head, Vector3(x, 0.088, -0.205), brow, look.hair_color.darkened(0.3))  # brow
	if look.forehead_mark:
		_box(_head, Vector3(-0.09, 0.15, -0.205), Vector3(0.06, 0.06, 0.015), Color(0.8, 0.1, 0.12))
	if look.whiskers:
		for side: float in [-1.0, 1.0]:
			for i in 3:
				var w := _box(_head, Vector3(side * 0.13, -0.05 + i * 0.03, -0.17), Vector3(0.07, 0.008, 0.01), Color(0.3, 0.2, 0.15))
				w.rotation.z = side * (0.15 - i * 0.15)
	if look.mask:
		_outlined = true
		var mask := _sphere(_head, Vector3(0, -0.07, -0.03), 0.2, HEADBAND_CLOTH)
		mask.scale = Vector3(1.12, 0.62, 1.05)
	else:
		_box(_head, Vector3(0, -0.1, -0.2), Vector3(0.07, 0.012, 0.02), Color(0.35, 0.18, 0.15))  # mouth
	_outlined = true
	if look.headband:
		var band := _cylinder(_head, Vector3(0, 0.1, 0), 0.24, 0.075, HEADBAND_CLOTH)
		var plate := _box(_head, Vector3(0, 0.1, -0.235), Vector3(0.19, 0.085, 0.025), HEADBAND_PLATE)
		if look.hair == ShinobiLook.Hair.SWEPT:
			band.rotation_degrees.z = -16.0
			plate.rotation_degrees.z = -16.0
			plate.position = Vector3(-0.03, 0.08, -0.235)
		_box(_head, Vector3(0, 0.1, 0.24), Vector3(0.06, 0.05, 0.05), HEADBAND_CLOTH)  # knot
	_build_hair(look)


func _build_hair(look: ShinobiLook) -> void:
	var c: Color = look.hair_color
	match look.hair:
		ShinobiLook.Hair.SPIKY:
			_sphere(_head, Vector3(0, 0.09, 0.03), 0.24, c).scale = Vector3(1.02, 0.82, 1.0)
			for i in 12:
				var a: float = TAU * i / 12.0
				var dir := Vector3(sin(a) * 0.75, 0.75, cos(a) * 0.75 + 0.2).normalized()
				_spike(_head, dir * 0.19 + Vector3(0, 0.07, 0.02), dir, 0.085, 0.3 + 0.06 * (i % 2), c)
			for x: float in [-0.12, 0.0, 0.12]:
				_spike(_head, Vector3(x, 0.14, -0.17), Vector3(x, 0.4, -1.0).normalized(), 0.06, 0.16, c)  # bangs
		ShinobiLook.Hair.DUCK_TAIL:
			_sphere(_head, Vector3(0, 0.08, 0.05), 0.245, c).scale = Vector3(1.02, 0.86, 1.0)
			for i in 9:
				var a: float = lerpf(-1.0, 1.0, i / 8.0)
				var dir := Vector3(sin(a) * 0.75, 0.5 + 0.2 * (i % 2), 1.0).normalized()
				_spike(_head, Vector3(0, 0.12, 0.14), dir, 0.09, 0.38, c)
			for x: float in [-0.2, 0.2]:
				_spike(_head, Vector3(x, 0.08, -0.1), Vector3(x * 0.4, -1.0, -0.25).normalized(), 0.06, 0.3, c)  # side bangs
			_spike(_head, Vector3(0.05, 0.16, -0.16), Vector3(0.3, -0.5, -1.0).normalized(), 0.05, 0.18, c)
		ShinobiLook.Hair.LONG:
			_sphere(_head, Vector3(0, 0.07, 0.03), 0.255, c).scale = Vector3(1.04, 0.9, 1.02)
			var back := _capsule(_head, Vector3(0, -0.2, 0.13), 0.2, 0.62, c)
			back.scale = Vector3(1.05, 1.0, 0.55)
			for x: float in [-0.18, 0.18]:
				_capsule(_head, Vector3(x, -0.13, -0.07), 0.05, 0.36, c)  # front locks
			_box(_head, Vector3(0.02, 0.15, -0.19), Vector3(0.3, 0.07, 0.06), c)  # fringe
		ShinobiLook.Hair.BOWL:
			var cap := _sphere(_head, Vector3(0, 0.07, 0.01), 0.252, c)
			cap.scale = Vector3(1.03, 0.85, 1.03)
			_box(_head, Vector3(0, 0.12, -0.2), Vector3(0.42, 0.09, 0.08), c)  # straight fringe
			for x: float in [-0.22, 0.22]:
				_box(_head, Vector3(x, 0.0, -0.02), Vector3(0.06, 0.24, 0.36), c)
		ShinobiLook.Hair.SHORT:
			_sphere(_head, Vector3(0, 0.08, 0.03), 0.24, c).scale = Vector3(1.0, 0.8, 1.0)
			for i in 10:
				var a: float = TAU * i / 10.0
				var dir := Vector3(sin(a) * 0.8, 0.6, cos(a) * 0.8).normalized()
				_spike(_head, dir * 0.18 + Vector3(0, 0.06, 0.02), dir, 0.07, 0.16, c)
		ShinobiLook.Hair.HIME:
			_sphere(_head, Vector3(0, 0.07, 0.03), 0.255, c).scale = Vector3(1.04, 0.9, 1.02)
			var back := _capsule(_head, Vector3(0, -0.32, 0.12), 0.2, 0.9, c)
			back.scale = Vector3(1.1, 1.0, 0.5)
			_box(_head, Vector3(0, 0.14, -0.2), Vector3(0.4, 0.08, 0.06), c)  # blunt bangs
			for x: float in [-0.2, 0.2]:
				_capsule(_head, Vector3(x, -0.12, -0.08), 0.045, 0.4, c)
		ShinobiLook.Hair.PINEAPPLE:
			_sphere(_head, Vector3(0, 0.07, 0.03), 0.24, c).scale = Vector3(1.0, 0.82, 1.0)
			_cylinder(_head, Vector3(0, 0.2, 0.14), 0.05, 0.06, Color(0.2, 0.2, 0.25))  # hair tie
			for i in 7:
				var a: float = lerpf(-1.2, 1.2, i / 6.0)
				var dir := Vector3(sin(a) * 0.5, 1.0, 0.35 + cos(a) * 0.2).normalized()
				_spike(_head, Vector3(0, 0.24, 0.16), dir, 0.05, 0.24, c)
		ShinobiLook.Hair.PONYTAIL:
			_sphere(_head, Vector3(0, 0.07, 0.03), 0.245, c).scale = Vector3(1.02, 0.86, 1.0)
			for x: float in [-0.19, 0.19]:
				_capsule(_head, Vector3(x, -0.08, -0.1), 0.045, 0.34, c)  # long front locks
			_cylinder(_head, Vector3(0, -0.05, 0.22), 0.04, 0.05, Color(0.2, 0.2, 0.25))
			_capsule(_head, Vector3(0, -0.28, 0.25), 0.05, 0.4, c)  # low ponytail
		ShinobiLook.Hair.SWEPT:
			_sphere(_head, Vector3(0, 0.08, 0.03), 0.24, c).scale = Vector3(1.02, 0.82, 1.0)
			for i in 9:
				var a: float = lerpf(-0.9, 0.9, i / 8.0)
				var dir := Vector3(0.8 + sin(a) * 0.3, 0.95, cos(a) * 0.45).normalized()
				_spike(_head, Vector3(-0.06, 0.15, 0.0), dir, 0.08, 0.38 + 0.05 * (i % 2), c)


func _build_sword() -> void:
	_sword = _pivot(_elbow_r, Vector3(0, -0.3, -0.02))
	_cylinder(_sword, Vector3(0, 0, 0), 0.03, 0.2, Color(0.2, 0.15, 0.3))  # grip
	_box(_sword, Vector3(0, -0.11, 0), Vector3(0.11, 0.025, 0.06), Color(0.75, 0.62, 0.3))  # guard
	var blade := _box(_sword, Vector3(0, -0.52, 0), Vector3(0.035, 0.78, 0.012), Color(0.85, 0.88, 0.95))
	(blade.mesh as PrimitiveMesh).material = SSGraphics.character_material(Color(0.85, 0.88, 0.95), true)


func _build_kunai() -> void:
	_sword = _pivot(_elbow_r, Vector3(0, -0.3, -0.02))
	_cylinder(_sword, Vector3(0, 0, 0), 0.022, 0.12, Color(0.15, 0.12, 0.2))  # wrapped grip
	var ring := _cylinder(_sword, Vector3(0, 0.08, 0), 0.03, 0.012, Color(0.6, 0.6, 0.65))
	ring.rotation_degrees.x = 90.0
	var blade := _spike(_sword, Vector3(0, -0.06, 0), Vector3.DOWN, 0.045, 0.24, Color(0.75, 0.78, 0.85))
	(blade.mesh as PrimitiveMesh).material = SSGraphics.character_material(Color(0.75, 0.78, 0.85), true)


func _pivot(parent: Node3D, at: Vector3) -> Node3D:
	var node := Node3D.new()
	node.position = at
	parent.add_child(node)
	return node


func _add(parent: Node3D, mesh: PrimitiveMesh, at: Vector3, color: Color) -> MeshInstance3D:
	mesh.material = SSGraphics.character_material(color, false, _outlined)
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = at
	inst.material_overlay = _overlay
	parent.add_child(inst)
	_parts.append(inst)
	return inst


func _capsule(parent: Node3D, at: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(height, radius * 2.0)
	mesh.radial_segments = 16
	mesh.rings = 6
	return _add(parent, mesh, at, color)


func _sphere(parent: Node3D, at: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 20
	mesh.rings = 12
	return _add(parent, mesh, at, color)


func _box(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _add(parent, mesh, at, color)


func _cylinder(parent: Node3D, at: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 18
	return _add(parent, mesh, at, color)


## Cone pointing along `dir`, base centred at `at`.
func _spike(parent: Node3D, at: Vector3, dir: Vector3, radius: float, length: float, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 8
	var inst := _add(parent, mesh, at + dir * length * 0.5, color)
	var up: Vector3 = dir.normalized()
	var side: Vector3 = up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	inst.basis = Basis(side, up, side.cross(up)).orthonormalized()
	return inst


# --- Real Shinobi Striker figure ---------------------------------------------------------

func _build_ss(ss: Node3D) -> void:
	scale = Vector3.ONE * SS_SCALE
	ss.rotation.y = PI  # converted SS figures face +Z, the fighter's front is -Z
	add_child(ss)
	_ss = ss
	var players: Array[Node] = ss.find_children("*", "AnimationPlayer", true, false)
	_ss_anim = players[0] as AnimationPlayer if not players.is_empty() else null
	for node: Node in ss.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		mi.material_overlay = _overlay
		_parts.append(mi)
	var skeletons: Array[Node] = ss.find_children("*", "Skeleton3D", true, false)
	var skel: Skeleton3D = skeletons[0] as Skeleton3D if not skeletons.is_empty() else null
	_hand_r = _ss_hand(skel, ["RightHand", "Hand_R", "hand_r", "R_Hand"], Vector3(0.3, 1.0, 0))
	_hand_l = _ss_hand(skel, ["LeftHand", "Hand_L", "hand_l", "L_Hand"], Vector3(-0.3, 1.0, 0))
	_ss_clip = &""
	_ss_pose = ""


func _ss_hand(skel: Skeleton3D, names: Array, fallback: Vector3) -> Node3D:
	if skel != null:
		for n: String in names:
			if skel.find_bone(n) >= 0:
				var attach := BoneAttachment3D.new()
				attach.bone_name = n
				skel.add_child(attach)
				return attach
	return _pivot(self, fallback)


## Set by the presentation: chakra sprint uses the ninja run clip, normal
## running a distinct "jog" clip when the model has one.
var sprinting: bool = false


func _animate_ss(delta: float, planar_speed: float, pose: StringName) -> void:
	if _ss_anim == null:
		return
	if _freeze > 0.0:
		_freeze -= delta
		_ss_anim.speed_scale = 0.0
		return
	var p: String = String(pose)
	var clip: StringName = &"idle"
	var speed: float = 1.0
	if p == "":
		if planar_speed > 3.5:
			if sprinting or not _ss_anim.has_animation(&"jog"):
				clip = &"run"
				speed = clampf(planar_speed / (12.0 if sprinting else 7.0), 0.75, 1.5)
			else:
				clip = &"jog"
				speed = clampf(planar_speed / 7.0, 0.75, 1.5)
		elif planar_speed > 0.3:
			clip = &"walk"
			speed = clampf(planar_speed / 1.8, 0.6, 1.5)
	else:
		var candidates: Array = SS_POSE_CLIPS.get(p, [StringName(p.get_slice(":", 0))])
		clip = &""
		for c: StringName in candidates:
			if _ss_anim.has_animation(c):
				clip = c
				break
		if clip == &"":
			clip = &"jab" if p.ends_with(":strike") else (&"charge" if _ss_anim.has_animation(&"charge") else &"idle")
	if not _ss_anim.has_animation(clip):
		clip = &"idle"
	_ss_anim.speed_scale = speed
	# A new wind-up (next hit of a string) restarts the clip; its strike just continues it.
	var restart: bool = clip != _ss_clip or (p.ends_with(":windup") and p != _ss_pose)
	if restart:
		_ss_anim.play(clip, 0.1)
		if clip == _ss_clip:
			_ss_anim.seek(0.0, true)
	_ss_clip = clip
	_ss_pose = p