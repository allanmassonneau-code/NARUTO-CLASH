extends Node
## Local probe (not committed): overview of the open-world village from a free camera.

var _world: Node
var _frames: int = 0


func _ready() -> void:
	_world = (load("res://world/world.tscn") as PackedScene).instantiate()
	add_child(_world)


func _process(_delta: float) -> void:
	_frames += 1
	if _frames == 3:
		var cam := Camera3D.new()
		cam.fov = 50
		cam.far = 600
		add_child(cam)
		var args := OS.get_cmdline_user_args()
		if args.size() > 0 and args[0] == "forest":
			cam.position = Vector3(112, 30, 30)
			cam.look_at(Vector3(112, 0, 0))
		elif args.size() > 0 and args[0] == "ravine":
			cam.position = Vector3(166, 30, 30)
			cam.look_at(Vector3(166, 0, 0))
		elif args.size() > 0 and args[0] == "plain":
			cam.position = Vector3(58, 30, 30)
			cam.look_at(Vector3(58, 0, 0))
		elif args.size() > 0 and args[0] == "gate":
			cam.position = Vector3(48, 14, 18)
			cam.look_at(Vector3(26, 4, 0))
		else:
			cam.position = Vector3(30, 46, 44)
			cam.look_at(Vector3(-2, 0, 0))
		cam.current = true
		SSGraphics.attach_post_outline(cam)
