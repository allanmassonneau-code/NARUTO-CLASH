extends Control
## Placeholder main menu: pick mode, your shinobi and your opponent.

var _player_index: int = GameSession.player_index
var _opponent_index: int = -1
var _mode: int = GameSession.Mode.DUEL_VS_BOT
var _player_buttons: Array[Button] = []
var _opponent_buttons: Array[Button] = []
var _mode_buttons: Array[Button] = []
var _info: Label
var _host_edit: LineEdit
var _name_edit: LineEdit
var _online_status: Label
var _online_mode: String = "2v2"
## Friends panel.
var _friends_parent: Control
var _friends_list: VBoxContainer
var _friend_code_edit: LineEdit
var _friends_hint: Label
var _friend_status: Dictionary = {}
var _invite_dialog: ConfirmationDialog
var _pending_party: String = ""


func _ready() -> void:
	theme = UiStyle.theme()
	var bg := ColorRect.new()
	bg.color = UiStyle.BG_SOLID
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	center.add_child(columns)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	columns.add_child(box)
	_friends_parent = columns

	var title := _title(box, "NARUTO CLASH", 56)
	title.add_theme_color_override("font_color", UiStyle.ACCENT)
	title.add_theme_font_override("font", UiStyle.font(900))
	_title(box, "SHINOBI ARENA", 14).add_theme_color_override("font_color", UiStyle.MUTED)
	_title(box, "Mode", 20)
	var mode_row := _row(box)
	_mode_buttons.append(_button(mode_row, "1v1 vs Bot", func() -> void: _set_mode(GameSession.Mode.DUEL_VS_BOT)))
	_mode_buttons.append(_button(mode_row, "2v2 (you + bot) vs 2 Bots", func() -> void: _set_mode(GameSession.Mode.TEAM_2V2_VS_BOTS)))

	var roster: Array[CharacterData] = GameSession.get_roster()
	_title(box, "Your shinobi", 20)
	var player_row := _grid(box)
	for i in roster.size():
		_player_buttons.append(_character_button(player_row, roster[i], _select_player.bind(i)))
	_title(box, "Opponent", 20)
	var opponent_row := _grid(box)
	for i in roster.size():
		_opponent_buttons.append(_character_button(opponent_row, roster[i], _select_opponent.bind(i)))
	_opponent_buttons.append(_button(opponent_row, "Random", _select_opponent.bind(-1)))

	_info = Label.new()
	_info.custom_minimum_size = Vector2(780, 120)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_info)
	var start := _button(box, "FIGHT (offline)", _start)
	start.custom_minimum_size = Vector2(0, 56)

	_title(box, "Online", 20)
	var online_row := _row(box)
	_name_edit = _line_edit(online_row, GameSession.player_name, "Name", 160)
	_host_edit = _line_edit(online_row, GameSession.server_host, "Server address", 220)
	_button(online_row, "Online 1v1", _join_online.bind("1v1")).toggle_mode = false
	_button(online_row, "Online 2v2", _join_online.bind("2v2")).toggle_mode = false
	_button(online_row, "Leave queue", _leave_online).toggle_mode = false
	_online_status = Label.new()
	_online_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_online_status.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	box.add_child(_online_status)
	Net.status_changed.connect(_on_net_status)
	_on_net_status(Net.status_text)
	_build_friends_panel()
	Net.friends_status.connect(_on_friends_status)
	Net.invite_received.connect(_on_invite)
	var poll := Timer.new()
	poll.wait_time = 2.0
	poll.autostart = true
	poll.timeout.connect(_poll_friends)
	add_child(poll)
	_title(box, "WASD/ZQSD move · Mouse aim · LMB/RMB/Space/Q(A)/E/F jutsu · X cancel (feint) · F1-F3 debug · F5 restart · Esc menu", 13)
	_refresh()


func _start() -> void:
	GameSession.mode = _mode
	GameSession.player_index = _player_index
	GameSession.prepare_lineup(_opponent_index)
	get_tree().change_scene_to_file(GameSession.ARENA_SCENE)


func _join_online(mode: String, party_code: String = "") -> void:
	_online_mode = mode
	GameSession.player_name = _name_edit.text.strip_edges() if _name_edit.text.strip_edges() != "" else "Shinobi"
	GameSession.server_host = _host_edit.text.strip_edges()
	GameSession.player_index = _player_index
	GameSession.save_settings()
	Net.join(GameSession.server_host, mode, GameSession.player_name, _player_index, party_code)


func _leave_online() -> void:
	Net.leave()


func _on_net_status(text: String) -> void:
	_online_status.text = text
	if _friends_list != null:
		_refresh_friends()


# --- Friends ------------------------------------------------------------------

func _build_friends_panel() -> void:
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.custom_minimum_size = Vector2(340, 0)
	panel.add_theme_stylebox_override("panel", UiStyle.panel(UiStyle.BG, 12, UiStyle.BORDER, 14))
	_friends_parent.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	UiStyle.label(col, "FRIENDS", 18, UiStyle.ACCENT, 800)
	var code_row := HBoxContainer.new()
	col.add_child(code_row)
	var code_label := UiStyle.label(code_row, "Your code:  %s" % GameSession.friend_code, 15, Color.WHITE, 700)
	code_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_small_button(code_row, "Copy", func() -> void: DisplayServer.clipboard_set(GameSession.friend_code))
	var add_row := HBoxContainer.new()
	col.add_child(add_row)
	_friend_code_edit = _line_edit(add_row, "", "Friend code", 150)
	_friend_code_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_friend_code_edit.text_submitted.connect(func(_t: String) -> void: _add_friend())
	_small_button(add_row, "Add", _add_friend)
	_friends_list = VBoxContainer.new()
	_friends_list.add_theme_constant_override("separation", 6)
	col.add_child(_friends_list)
	var party_row := HBoxContainer.new()
	col.add_child(party_row)
	_small_button(party_row, "Private party", _open_party)
	_small_button(party_row, "Leave party", _leave_party)
	_friends_hint = UiStyle.label(col, "", 12, UiStyle.MUTED, 500)
	_friends_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_friends_hint.custom_minimum_size = Vector2(300, 0)
	_invite_dialog = ConfirmationDialog.new()
	_invite_dialog.ok_button_text = "Join"
	_invite_dialog.cancel_button_text = "Decline"
	_invite_dialog.confirmed.connect(func() -> void:
		Net.set_party(_pending_party)
		_refresh_friends())
	add_child(_invite_dialog)
	_refresh_friends()


func _refresh_friends() -> void:
	for child: Node in _friends_list.get_children():
		child.queue_free()
	var connected: bool = Net.is_client() and Net.is_online()
	if GameSession.friends.is_empty():
		UiStyle.label(_friends_list, "No friends yet: exchange codes and add each other.", 12, UiStyle.MUTED, 500) \
			.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for friend: Dictionary in GameSession.friends:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_friends_list.add_child(row)
		var info: Dictionary = _friend_status.get(friend.code, {})
		var state: String = info.get("state", "offline") if connected else "?"
		var colors: Dictionary = {"lobby": Color(0.4, 1.0, 0.5), "party": Color(0.4, 0.8, 1.0), "match": Color(1.0, 0.75, 0.3)}
		var dot := UiStyle.label(row, "●", 14, colors.get(state, Color(0.45, 0.45, 0.5)), 700)
		dot.tooltip_text = state
		var name_label := UiStyle.label(row, friend.name, 14, Color.WHITE, 600)
		name_label.tooltip_text = friend.code
		name_label.mouse_filter = Control.MOUSE_FILTER_PASS
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.clip_text = true
		var invite := _small_button(row, "Invite", Net.invite.bind(friend.code))
		invite.disabled = not connected or state == "offline" or state == "match"
		_small_button(row, "Join", _join_friend.bind(friend.code))
		_small_button(row, "✕", func() -> void:
			GameSession.remove_friend(friend.code)
			_refresh_friends())
	if not connected:
		_friends_hint.text = "Join Online 1v1 or 2v2 to see which friends are online and invite them. " \
			+ "Join = enter a friend's private party (same mode)."
	elif Net.party != "":
		_friends_hint.text = "Private party %s: you will only be matched with its members (2v2: the free spots are filled with queued players, then bots)." % Net.party
	else:
		_friends_hint.text = "Public queue. Invite a friend (opens your private party) or join theirs."


func _leave_party() -> void:
	Net.set_party("")
	_refresh_friends()


func _add_friend() -> void:
	if GameSession.add_friend(_friend_code_edit.text, ""):
		_friend_code_edit.text = ""
		_poll_friends()
	_refresh_friends()


func _open_party() -> void:
	if Net.is_client() and Net.is_online():
		Net.set_party(GameSession.friend_code)
	else:
		_join_online(_online_mode, GameSession.friend_code)
	_refresh_friends()


## Enter a friend's private party (their party code is their friend code).
func _join_friend(code: String) -> void:
	if Net.is_client() and Net.is_online():
		Net.set_party(code)
	else:
		_join_online(_online_mode, code)
	_refresh_friends()


func _poll_friends() -> void:
	if GameSession.friends.is_empty() or not Net.is_client():
		return
	var codes := PackedStringArray()
	for friend: Dictionary in GameSession.friends:
		codes.append(friend.code)
	Net.query_friends(codes)


func _on_friends_status(status: Dictionary) -> void:
	_friend_status = status
	for code: String in status:
		GameSession.update_friend_name(code, status[code].get("name", ""))
	_refresh_friends()


func _on_invite(from_name: String, party_code: String) -> void:
	_pending_party = party_code
	_invite_dialog.dialog_text = "%s invites you to their party." % from_name
	_invite_dialog.popup_centered()


func _small_button(parent: Control, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 32)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _select_player(index: int) -> void:
	_player_index = index
	Net.set_roster(index)
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
	if data.passive_description != "":
		lines.append("Passive: " + data.passive_description)
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
	button.custom_minimum_size = Vector2(150, 38)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _line_edit(parent: Control, text: String, placeholder: String, width: float) -> LineEdit:
	var edit := LineEdit.new()
	edit.text = text
	edit.placeholder_text = placeholder
	edit.custom_minimum_size = Vector2(width, 40)
	parent.add_child(edit)
	return edit


func _grid(parent: Control) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	var center := CenterContainer.new()
	parent.add_child(center)
	center.add_child(grid)
	return grid


func _row(parent: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(row)
	return row


func _title(parent: Control, text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)
	return label
