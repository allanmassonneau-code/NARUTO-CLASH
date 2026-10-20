class_name MenuBackdrop
extends Control
## Live 3D backdrop for the menus: the game's own map (World in backdrop mode)
## seen by a slow cinematic camera, darkened toward the edges so the UI stays
## readable. show_place() switches village / spot (e.g. per clan).

var _container: SubViewportContainer
var _viewport: SubViewport
var _world: World
var _key: String = ""
var _tint: ColorRect


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_container = SubViewportContainer.new()
	_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_container.stretch = true
	_container.stretch_shrink = 2  # half resolution: soft and cheap behind the UI
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_container)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_container.add_child(_viewport)
	_tint = ColorRect.new()
	_tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tint.color = Color(0, 0, 0, 0.35)
	add_child(_tint)
	var vignette := TextureRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.0))
	g.set_color(1, Color(0, 0, 0, 0.75))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.45)
	tex.fill_to = Vector2(1.15, 1.15)
	vignette.texture = tex
	add_child(vignette)


## Shows `village` around `spot` (World.BACKDROP_SPOTS), tinted by `color`.
func show_place(village: StringName, spot: StringName, color: Color = Color.BLACK) -> void:
	_tint.color = Color(color.darkened(0.7), 0.38)
	var key: String = "%s/%s" % [village, spot]
	if key == _key or not CombatFx.is_enabled():
		return
	_key = key
	if is_instance_valid(_world):
		_world.queue_free()
	_world = World.backdrop(village, spot)
	_viewport.add_child(_world)
