extends Control
## Placeholder main menu: pick mode, your shinobi and your opponent.

var _player_index: int = 0
var _opponent_index: int = -1
var _mode: int = GameSession.Mode.DUEL_VS_BOT
var _player_buttons: Array[Button] = []
var _opponent_buttons: Array[Button] = []
var _mode_buttons: Array[Button] = []
var _info: Label


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.11, 0.14)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)

	_title(box, "NARUTO CLASH — Shinobi Arena", 40)
	_title(box, "Mode", 20)
	var mode_row := _row(box)
	_mode_buttons.append(_button(mode_row, "1v1 vs Bot", func() -> void: _set_mode(GameSession.Mode.DUEL_VS_BOT)))
	_mode_buttons.append(_button(mode_row, "2v2 (you + bot) vs 2 Bots", func() -> void: _set_mode(GameSession.Mode.TEAM_2V2_VS_BOTS)))
	var online := _button(mode_row, "Online (soon)", func() -> void: pass)
	online.disabled = true

	var roster: Array[CharacterData] = GameSession.get_roster()
	_title(box, "Your shinobi", 20)
	var player_row := _row(box)
	for i in roster.size():
		_player_buttons.append(_character_button(player_row, roster[i], _select_player.bind(i)))
	_title(box, "Opponent", 20)
	var opponent_row := _row(box)
	for i in roster.size():
		_opponent_buttons.append(_character_button(opponent_row, roster[i], _select_opponent.bind(i)))
	_opponent_buttons.append(_button(opponent_row, "Random", _select_opponent.bind(-1)))

	_info = Label.new()
	_info.custom_minimum_size = Vector2(900, 120)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_info)
	var start := _button(box, "FIGHT", _start)
	start.custom_minimum_size = Vector2(0, 56)
	_title(box, "WASD/ZQSD move · Mouse aim · LMB/RMB/Space/Q(A)/E/F jutsu · X cancel (feint) · F1-F3 debug · F5 restart · Esc menu", 13)
	_refresh()


func _start() -> void:
	GameSession.mode = _mode
	GameSession.player_index = _player_index
	GameSession.prepare_lineup(_opponent_index)
	get_tree().change_scene_to_file(GameSession.ARENA_SCENE)


func _select_player(index: int) -> void:
	_player_index = index
	_refresh()


func _select_opponent(index: int) -> void:
	_opponent_index = index
	_refresh()


func _set_mode(mode: int) -> void:
	_mode = mode
	_refresh()


func _refresh() -> void:
	for i in _player_buttons.size():
		_player_buttons[i].button_pressed = i == _player_index
	for i in _opponent_buttons.size():
		_opponent_buttons[i].button_pressed = (i == _opponent_index) or (_opponent_index < 0 and i == _opponent_buttons.size() - 1)
	_mode_buttons[0].button_pressed = _mode == GameSession.Mode.DUEL_VS_BOT
	_mode_buttons[1].button_pressed = _mode == GameSession.Mode.TEAM_2V2_VS_BOTS
	var data: CharacterData = GameSession.get_roster()[_player_index]
	var lines: PackedStringArray = ["%s — %s" % [data.display_name, data.identity]]
	for slot: StringName in AbilityController.SLOTS:
		var a: AbilityData = data.get(slot)
		if a != null:
			lines.append("%s: %s" % [MatchHud.SLOT_KEYS[slot], a.display_name])
	_info.text = "\n".join(lines)


func _character_button(parent: Control, data: CharacterData, callback: Callable) -> Button:
	var button := _button(parent, data.display_name, callback)
	button.add_theme_color_override("font_color", data.body_color)
	button.add_theme_color_override("font_pressed_color", data.body_color.lightened(0.4))
	return button


func _button(parent: Control, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.custom_minimum_size = Vector2(160, 40)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _row(parent: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(row)
	return row


func _title(parent: Control, text: String, size: int) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)
