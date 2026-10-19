class_name OptionsPanel
extends CanvasLayer
## Options popup (O or the gear button, M mutes): volumes, spatial sound,
## fullscreen, anti-aliasing. Saved in the settings file.

var _panel: PanelContainer
var _mute_box: CheckBox


static func attach(parent: Node) -> OptionsPanel:
	var options := OptionsPanel.new()
	options.layer = 50
	parent.add_child(options)
	return options


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiStyle.theme()
	add_child(root)
	var gear := Button.new()
	gear.text = "⚙"
	gear.tooltip_text = "Options (O)"
	gear.add_theme_font_size_override("font_size", 20)
	gear.custom_minimum_size = Vector2(42, 42)
	gear.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	gear.offset_left = -54
	gear.offset_top = -54
	gear.offset_right = -12
	gear.offset_bottom = -12
	gear.focus_mode = Control.FOCUS_NONE
	gear.pressed.connect(toggle)
	root.add_child(gear)

	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.custom_minimum_size = Vector2(420, 0)
	var frame := UiStyle.panel(Color(0.07, 0.06, 0.11, 0.97), 14, UiStyle.ACCENT, 18)
	frame.shadow_color = Color(0, 0, 0, 0.6)
	frame.shadow_size = 30
	_panel.add_theme_stylebox_override("panel", frame)
	_panel.visible = false
	root.add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	_panel.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	var title := UiStyle.label(head, "OPTIONS", 22, UiStyle.ACCENT, 900)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var close := Button.new()
	close.text = "✕"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(toggle)
	head.add_child(close)

	UiStyle.label(col, "AUDIO", 13, UiStyle.MUTED, 900)
	_slider(col, "Master volume", "master_volume")
	_slider(col, "Sound effects", "sfx_volume")
	_mute_box = _check(col, "Mute (M)", "muted")
	_check(col, "Sound fades with distance", "spatial_sound")
	UiStyle.label(col, "DISPLAY", 13, UiStyle.MUTED, 900)
	_check(col, "Fullscreen", "fullscreen")
	_check(col, "Anti-aliasing (sharp edges)", "anti_aliasing")


func toggle() -> void:
	_panel.visible = not _panel.visible


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.physical_keycode == KEY_O:
		toggle()
		get_viewport().set_input_as_handled()
	elif key.physical_keycode == KEY_M and not (get_viewport().gui_get_focus_owner() is LineEdit):
		GameSession.muted = not GameSession.muted
		_mute_box.set_pressed_no_signal(GameSession.muted)
		_commit()
		get_viewport().set_input_as_handled()
	elif key.physical_keycode == KEY_ESCAPE and _panel.visible:
		toggle()
		get_viewport().set_input_as_handled()


func _slider(parent: Control, text: String, key: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var label := UiStyle.label(row, text, 15, Color.WHITE, 700)
	label.custom_minimum_size = Vector2(150, 0)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.value = GameSession.get(key)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_NONE
	row.add_child(slider)
	var value := UiStyle.label(row, str(int(slider.value)), 14, UiStyle.ACCENT, 800)
	value.custom_minimum_size = Vector2(34, 0)
	slider.value_changed.connect(func(v: float) -> void:
		GameSession.set(key, v)
		value.text = str(int(v))
		GameSession.apply_options()
		Sfx.play(&"tick", Vector3.INF, -6.0))
	slider.drag_ended.connect(func(_changed: bool) -> void: GameSession.save_settings())


func _check(parent: Control, text: String, key: String) -> CheckBox:
	var box := CheckBox.new()
	box.text = text
	box.button_pressed = GameSession.get(key)
	box.focus_mode = Control.FOCUS_NONE
	box.toggled.connect(func(on: bool) -> void:
		GameSession.set(key, on)
		_commit())
	parent.add_child(box)
	return box


func _commit() -> void:
	GameSession.apply_options()
	GameSession.save_settings()
