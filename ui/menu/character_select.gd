extends Control
## Main menu / character select, fighting-game style: roster grid of live
## 3D shinobi in idle, big showcases for you and your opponent, full kit
## sheet, mode tabs (offline / online) and a friends panel.

const MODES: Array[Dictionary] = [
	{"label": "1v1  vs  BOT", "online": "", "mode": GameSession.Mode.DUEL_VS_BOT},
	{"label": "2v2  vs  BOTS", "online": "", "mode": GameSession.Mode.TEAM_2V2_VS_BOTS},
	{"label": "BATTLE 20v20", "online": "", "mode": GameSession.Mode.BATTLE_20V20},
	{"label": "ONLINE 1v1", "online": "1v1", "mode": GameSession.Mode.DUEL_VS_BOT},
	{"label": "ONLINE 2v2", "online": "2v2", "mode": GameSession.Mode.TEAM_2V2_VS_BOTS},
]
const CARD_SIZE := Vector2(164, 204)
const P1_COLOR := Color(1.0, 0.6, 0.15)
const CPU_COLOR := Color(1.0, 0.3, 0.3)

var _player_index: int = GameSession.player_index
var _opponent_index: int = -1
var _tab: int = 0
## Which showcase a left click on a card assigns: 0 = you, 1 = opponent.
var _picking: int = 0

var _cards: Array[Dictionary] = []
var _tab_buttons: Array[Button] = []
var _p1_portrait: ShinobiPortrait
var _p1_name: Label
var _p1_frame: StyleBoxFlat
var _cpu_portrait: ShinobiPortrait
var _cpu_name: Label
var _cpu_hint: Label
var _cpu_random: Label
var _cpu_frame: StyleBoxFlat
var _cpu_panel: Control
var _online_panel: Control
var _kit_title: Label
var _kit_identity: Label
var _kit_passive: Label
var _kit_rows: Array[Dictionary] = []
var _fight_button: Button
var _name_edit: LineEdit
var _host_edit: LineEdit
var _online_status: Label
var _queue_button: Button
var _shown_player: int = -1
var _shown_opponent: int = -2

var _friends_panel: PanelContainer
var _friends_button: Button
var _friends_list: VBoxContainer
var _friend_code_edit: LineEdit
var _friends_hint: Label
var _friend_status: Dictionary = {}
var _invite_dialog: ConfirmationDialog
var _pending_party: String = ""


func _ready() -> void:
	theme = UiStyle.theme()
	_build_background()
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right"]:
		root.add_theme_constant_override("margin_" + side, 28)
	root.add_theme_constant_override("margin_top", 18)
	root.add_theme_constant_override("margin_bottom", 18)
	add_child(root)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	root.add_child(col)
	_build_header(col)
	_build_stage(col)
	_build_kit_sheet(col)
	_build_friends_panel()
	OptionsPanel.attach(self)
	Net.status_changed.connect(_on_net_status)
	Net.friends_status.connect(_on_friends_status)
	Net.invite_received.connect(_on_invite)
	var poll := Timer.new()
	poll.wait_time = 2.0
	poll.autostart = true
	poll.timeout.connect(_poll_friends)
	add_child(poll)
	if Net.is_client() and Net.is_online():
		_tab = 4 if Net.status_text.begins_with("2v2") else 3
	_on_net_status(Net.status_text)
	_refresh()


# --- Layout -------------------------------------------------------------------

func _build_background() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
void fragment() {
	vec2 uv = UV;
	vec3 col = mix(vec3(0.10, 0.07, 0.13), vec3(0.03, 0.03, 0.06), uv.y);
	float glow = smoothstep(0.75, 0.0, distance(uv, vec2(0.5, 0.42)));
	col += vec3(0.55, 0.22, 0.05) * glow * 0.22;
	float lines = step(0.985, fract((uv.x + uv.y * 0.6) * 38.0 + TIME * 0.05));
	col += vec3(1.0, 0.55, 0.15) * lines * 0.035;
	col *= 1.0 - 0.55 * pow(distance(uv, vec2(0.5)), 2.0);
	COLOR = vec4(col, 1.0);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	bg.material = mat
	add_child(bg)


func _build_header(parent: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", -8)
	row.add_child(titles)
	var title := UiStyle.label(titles, "NINJA BATTLE", 44, UiStyle.ACCENT, 900)
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_outline_color", Color(0.2, 0.05, 0.0))
	UiStyle.label(titles, "SHINOBI ARENA  ·  v%s" % Net.game_version(), 13, UiStyle.MUTED, 700)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	tabs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(tabs)
	for i in MODES.size():
		var tab := Button.new()
		tab.text = MODES[i].label
		tab.toggle_mode = true
		tab.custom_minimum_size = Vector2(150, 46)
		tab.add_theme_font_override("font", UiStyle.font(800))
		tab.pressed.connect(_set_tab.bind(i))
		tabs.add_child(tab)
		_tab_buttons.append(tab)
	var spacer2 := Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer2)
	_friends_button = Button.new()
	_friends_button.text = "FRIENDS"
	_friends_button.custom_minimum_size = Vector2(140, 46)
	_friends_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_friends_button.pressed.connect(func() -> void: _friends_panel.visible = not _friends_panel.visible)
	row.add_child(_friends_button)


func _build_stage(parent: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(row)
	var roster: Array[CharacterData] = GameSession.get_roster()

	var p1 := _showcase(row, "YOU", P1_COLOR, roster[_player_index])
	_p1_portrait = p1.portrait
	_p1_name = p1.name
	_p1_frame = p1.frame
	(p1.root as Control).gui_input.connect(_on_showcase_input.bind(0))

	var grid_box := VBoxContainer.new()
	grid_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_box.alignment = BoxContainer.ALIGNMENT_CENTER
	grid_box.add_theme_constant_override("separation", 10)
	row.add_child(grid_box)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	var center := CenterContainer.new()
	grid_box.add_child(center)
	center.add_child(grid)
	for i in roster.size():
		_cards.append(_card(grid, roster[i], i))
	var hint := UiStyle.label(grid_box, "Left click: your shinobi   ·   Right click: opponent", 13, UiStyle.MUTED, 600)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var right := Control.new()
	right.custom_minimum_size = Vector2(330, 0)
	row.add_child(right)
	var cpu := _showcase(right, "OPPONENT", CPU_COLOR, roster[0])
	_cpu_panel = cpu.root
	_cpu_portrait = cpu.portrait
	_cpu_name = cpu.name
	_cpu_frame = cpu.frame
	_cpu_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cpu_panel.gui_input.connect(_on_showcase_input.bind(1))
	_cpu_random = UiStyle.label(_cpu_panel, "?", 160, Color(1.0, 0.3, 0.3, 0.8), 900)
	_cpu_random.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cpu_random.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cpu_random.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cpu_hint = UiStyle.label(cpu.info, "", 12, UiStyle.MUTED, 600)
	_cpu_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var random := Button.new()
	random.text = "RANDOM OPPONENT"
	random.pressed.connect(func() -> void:
		_opponent_index = -1
		_refresh())
	(cpu.info as Control).add_child(random)
	_online_panel = _build_online_panel(right)


func _showcase(parent: Control, caption: String, color: Color, data: CharacterData) -> Dictionary:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(330, 0)
	var frame := UiStyle.panel(Color(0.06, 0.05, 0.09, 0.9), 16, color, 12)
	frame.set_border_width_all(2)
	frame.shadow_color = Color(color, 0.25)
	frame.shadow_size = 18
	panel.add_theme_stylebox_override("panel", frame)
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	var tag := UiStyle.label(box, caption, 14, color, 900)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var portrait := ShinobiPortrait.create(data, ShinobiPortrait.Framing.FULL_BODY, Vector2i(330, 380))
	portrait.custom_minimum_size = Vector2(300, 300)
	portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(portrait)
	var name_label := UiStyle.label(box, data.display_name.to_upper(), 24, Color.WHITE, 900)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_constant_override("outline_size", 8)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 6)
	box.add_child(info)
	return {"root": panel, "portrait": portrait, "name": name_label, "frame": frame, "info": info}


func _card(parent: Control, data: CharacterData, index: int) -> Dictionary:
	var card := PanelContainer.new()
	card.custom_minimum_size = CARD_SIZE
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var style := UiStyle.panel(Color(data.body_color.darkened(0.78), 0.95), 12, Color(data.body_color, 0.45), 0)
	style.set_border_width_all(2)
	card.add_theme_stylebox_override("panel", style)
	parent.add_child(card)
	var stack := Control.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(stack)
	var backdrop := ColorRect.new()
	backdrop.color = Color(data.body_color, 0.14)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.offset_top = CARD_SIZE.y * 0.45
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(backdrop)
	var portrait := ShinobiPortrait.create(data, ShinobiPortrait.Framing.FULL_BODY, Vector2i(int(CARD_SIZE.x), int(CARD_SIZE.y)))
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_child(portrait)
	var banner := ColorRect.new()
	banner.color = Color(0, 0, 0, 0.62)
	banner.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	banner.offset_top = -28
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(banner)
	var title: String = data.short_name if data.short_name != "" else data.display_name
	var label := UiStyle.label(banner, title.to_upper(), 15, Color.WHITE, 800)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var badges := HBoxContainer.new()
	badges.position = Vector2(6, 6)
	badges.add_theme_constant_override("separation", 4)
	badges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(badges)
	var p1_badge := _badge(badges, "P1", P1_COLOR)
	var cpu_badge := _badge(badges, "VS", CPU_COLOR)
	card.gui_input.connect(_on_card_input.bind(index))
	card.mouse_entered.connect(func() -> void:
		portrait.play(&"guard:windup", 0.4)
		style.border_color = Color(data.body_color.lightened(0.4), 0.95))
	card.mouse_exited.connect(_refresh)
	return {"root": card, "style": style, "portrait": portrait, "data": data, "p1": p1_badge, "cpu": cpu_badge}


func _badge(parent: Control, text: String, color: Color, text_color: Color = Color(0.08, 0.04, 0.02)) -> PanelContainer:
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", UiStyle.panel(color, 6, Color(0, 0, 0, 0.6), 6))
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(badge)
	var label := UiStyle.label(badge, text, 12, text_color, 900)
	label.add_theme_constant_override("outline_size", 0)
	return badge


func _build_online_panel(parent: Control) -> Control:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var frame := UiStyle.panel(Color(0.06, 0.05, 0.09, 0.9), 16, UiStyle.CHAKRA, 16)
	frame.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", frame)
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	UiStyle.label(box, "ONLINE", 22, UiStyle.CHAKRA, 900)
	UiStyle.label(box, "Name", 13, UiStyle.MUTED)
	_name_edit = _line_edit(box, GameSession.player_name, "Name")
	UiStyle.label(box, "Server", 13, UiStyle.MUTED)
	_host_edit = _line_edit(box, GameSession.server_host, "Server address")
	_online_status = UiStyle.label(box, "", 14, Color(1.0, 0.85, 0.4), 700)
	_online_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_online_status.custom_minimum_size = Vector2(290, 60)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	var party_row := HBoxContainer.new()
	party_row.add_theme_constant_override("separation", 8)
	box.add_child(party_row)
	var open := _small_button(party_row, "Private party", _open_party)
	open.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var leave := _small_button(party_row, "Public queue", _leave_party)
	leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_queue_button = Button.new()
	_queue_button.custom_minimum_size = Vector2(0, 54)
	_queue_button.add_theme_font_override("font", UiStyle.font(900))
	_queue_button.add_theme_font_size_override("font_size", 20)
	_queue_button.pressed.connect(_toggle_queue)
	box.add_child(_queue_button)
	return panel


func _build_kit_sheet(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel(Color(0.06, 0.05, 0.09, 0.92), 14, Color(1, 1, 1, 0.12), 16))
	parent.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	panel.add_child(row)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	row.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	col.add_child(head)
	_kit_title = UiStyle.label(head, "", 24, Color.WHITE, 900)
	_kit_identity = UiStyle.label(head, "", 14, UiStyle.MUTED, 600)
	_kit_identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_kit_identity.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_kit_identity.clip_text = true
	_kit_passive = UiStyle.label(col, "", 14, Color(0.55, 1.0, 0.6), 700)
	UiStyle.label(col, "Everyone  ·  F hold: guard   ·   F + LMB just before an enemy basic attack: PERFECT PARRY (stuns)", 13, Color(0.6, 0.8, 1.0), 700)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 10)
	col.add_child(grid)
	for slot: StringName in AbilityController.SLOTS:
		_kit_rows.append(_kit_row(grid, slot))
	_fight_button = Button.new()
	_fight_button.text = "FIGHT!"
	_fight_button.custom_minimum_size = Vector2(230, 0)
	_fight_button.add_theme_font_override("font", UiStyle.font(900))
	_fight_button.add_theme_font_size_override("font_size", 34)
	_fight_button.pressed.connect(_start)
	row.add_child(_fight_button)


func _kit_row(parent: Control, slot: StringName) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.custom_minimum_size = Vector2(370, 0)
	parent.add_child(row)
	var icon_box := PanelContainer.new()
	icon_box.add_theme_stylebox_override("panel", UiStyle.panel(Color(0, 0, 0, 0.5), 8, Color(1, 1, 1, 0.18), 2))
	row.add_child(icon_box)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(46, 46)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_box.add_child(icon)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	text.add_child(top)
	var key := _badge(top, MatchHud.SLOT_KEYS[slot], Color(0.16, 0.15, 0.22), Color.WHITE)
	key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var title := UiStyle.label(top, "", 15, Color.WHITE, 800)
	var cost := UiStyle.label(top, "", 13, UiStyle.ACCENT, 800)
	cost.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var desc := UiStyle.label(text, "", 12, UiStyle.MUTED, 600)
	desc.clip_text = true
	desc.custom_minimum_size = Vector2(290, 0)
	return {"slot": slot, "icon": icon, "title": title, "cost": cost, "desc": desc}


# --- State --------------------------------------------------------------------

func _set_tab(index: int) -> void:
	_tab = index
	if MODES[index].online == "" and Net.is_client():
		Net.leave()
	_refresh()


func _on_card_input(event: InputEvent, index: int) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	var side: int = _picking
	if mb.button_index == MOUSE_BUTTON_RIGHT:
		side = 1
	elif mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if side == 1 and MODES[_tab].online == "":
		_opponent_index = index
		_picking = 0
	else:
		_player_index = index
		Net.set_roster(index)
	(_cards[index].portrait as ShinobiPortrait).play(&"seal:windup", 0.6)
	_refresh()


func _on_showcase_input(event: InputEvent, side: int) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_picking = side
		_refresh()


func _refresh() -> void:
	var roster: Array[CharacterData] = GameSession.get_roster()
	var online: bool = MODES[_tab].online != ""
	for i in _tab_buttons.size():
		_tab_buttons[i].button_pressed = i == _tab
	for i in _cards.size():
		var card: Dictionary = _cards[i]
		var data: CharacterData = card.data
		var mine: bool = i == _player_index
		var theirs: bool = not online and i == _opponent_index
		var style := card.style as StyleBoxFlat
		style.border_color = P1_COLOR if mine else (CPU_COLOR if theirs else Color(data.body_color, 0.45))
		style.set_border_width_all(4 if mine or theirs else 2)
		(card.p1 as Control).visible = mine
		(card.cpu as Control).visible = theirs
	var me: CharacterData = roster[_player_index]
	if _shown_player != _player_index:
		_shown_player = _player_index
		_p1_portrait.set_character(me)
	_p1_name.text = me.display_name.to_upper()
	_p1_frame.set_border_width_all(4 if _picking == 0 else 2)
	_cpu_panel.visible = not online
	_online_panel.visible = online
	if _shown_opponent != _opponent_index and _opponent_index >= 0:
		_cpu_portrait.set_character(roster[_opponent_index])
	_shown_opponent = _opponent_index
	_cpu_name.text = roster[_opponent_index].display_name.to_upper() if _opponent_index >= 0 else "RANDOM"
	_cpu_portrait.modulate = Color.WHITE if _opponent_index >= 0 else Color(0.08, 0.08, 0.12)
	_cpu_random.visible = _opponent_index < 0
	_cpu_frame.set_border_width_all(4 if _picking == 1 else 2)
	_cpu_hint.text = "Picking the opponent: click a shinobi" if _picking == 1 else "Click this panel, then a shinobi, to pick the opponent"
	_fight_button.visible = not online
	_refresh_kit(me)
	_refresh_queue_button()


func _refresh_kit(data: CharacterData) -> void:
	_kit_title.text = data.display_name
	_kit_title.add_theme_color_override("font_color", data.body_color.lightened(0.35))
	_kit_identity.text = data.identity
	_kit_passive.text = ("Passive  ·  " + data.passive_description) if data.passive_description != "" else ""
	for row: Dictionary in _kit_rows:
		var a: AbilityData = data.get(row.slot)
		(row.icon as TextureRect).texture = a.icon if a != null else null
		(row.title as Label).text = a.display_name if a != null else "—"
		(row.cost as Label).text = AbilityText.cost(a) if a != null else ""
		(row.desc as Label).text = AbilityText.summary(a) if a != null else ""


func _start() -> void:
	GameSession.mode = MODES[_tab].mode
	GameSession.player_index = _player_index
	GameSession.prepare_lineup(_opponent_index)
	get_tree().change_scene_to_file(GameSession.ARENA_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and MODES[_tab].online == "" and not _friends_panel.visible:
		_start()


# --- Online -------------------------------------------------------------------

func _toggle_queue() -> void:
	if Net.is_client() and Net.is_online():
		Net.leave()
	else:
		_join_online(MODES[_tab].online, Net.party)
	_refresh_queue_button()


func _refresh_queue_button() -> void:
	if _queue_button == null:
		return
	var queued: bool = Net.is_client() and Net.is_online()
	_queue_button.text = "LEAVE QUEUE" if queued else "FIND MATCH  (%s)" % MODES[_tab].online
	if _friends_list != null:
		_refresh_friends()


func _join_online(mode: String, party_code: String = "") -> void:
	if mode == "":
		mode = "2v2"
	for i in MODES.size():
		if MODES[i].online == mode:
			_tab = i
	GameSession.player_name = _name_edit.text.strip_edges() if _name_edit.text.strip_edges() != "" else "Shinobi"
	GameSession.server_host = _host_edit.text.strip_edges()
	GameSession.player_index = _player_index
	GameSession.save_settings()
	Net.join(GameSession.server_host, mode, GameSession.player_name, _player_index, party_code)
	_refresh()


func _on_net_status(text: String) -> void:
	_online_status.text = text if text != "" else "Not connected."
	_refresh_queue_button()


# --- Friends ------------------------------------------------------------------

func _build_friends_panel() -> void:
	_friends_panel = PanelContainer.new()
	_friends_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_friends_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_friends_panel.offset_right = -28.0
	_friends_panel.offset_top = 84.0
	_friends_panel.custom_minimum_size = Vector2(390, 0)
	var frame := UiStyle.panel(Color(0.07, 0.06, 0.11, 0.98), 14, UiStyle.ACCENT, 16)
	frame.shadow_color = Color(0, 0, 0, 0.6)
	frame.shadow_size = 24
	_friends_panel.add_theme_stylebox_override("panel", frame)
	_friends_panel.visible = false
	add_child(_friends_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_friends_panel.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	var title := UiStyle.label(head, "FRIENDS", 20, UiStyle.ACCENT, 900)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_small_button(head, "✕", func() -> void: _friends_panel.visible = false)
	var code_row := HBoxContainer.new()
	col.add_child(code_row)
	var code_label := UiStyle.label(code_row, "Your code:  %s" % GameSession.friend_code, 16, Color.WHITE, 800)
	code_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_small_button(code_row, "Copy", func() -> void: DisplayServer.clipboard_set(GameSession.friend_code))
	var add_row := HBoxContainer.new()
	add_row.add_theme_constant_override("separation", 8)
	col.add_child(add_row)
	_friend_code_edit = _line_edit(add_row, "", "Friend code")
	_friend_code_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_friend_code_edit.text_submitted.connect(func(_t: String) -> void: _add_friend())
	_small_button(add_row, "Add", _add_friend)
	_friends_list = VBoxContainer.new()
	_friends_list.add_theme_constant_override("separation", 6)
	col.add_child(_friends_list)
	_friends_hint = UiStyle.label(col, "", 12, UiStyle.MUTED, 500)
	_friends_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_friends_hint.custom_minimum_size = Vector2(350, 0)
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
	var online_count: int = 0
	if GameSession.friends.is_empty():
		UiStyle.label(_friends_list, "No friends yet: exchange codes and add each other.", 13, UiStyle.MUTED, 500)
	for friend: Dictionary in GameSession.friends:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_friends_list.add_child(row)
		var info: Dictionary = _friend_status.get(friend.code, {})
		var state: String = info.get("state", "offline") if connected else "?"
		if state in ["lobby", "party", "match"]:
			online_count += 1
		var colors: Dictionary = {"lobby": Color(0.4, 1.0, 0.5), "party": Color(0.4, 0.8, 1.0), "match": Color(1.0, 0.75, 0.3)}
		UiStyle.label(row, "●", 14, colors.get(state, Color(0.45, 0.45, 0.5)), 700)
		var name_label := UiStyle.label(row, friend.name, 15, Color.WHITE, 700)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.clip_text = true
		name_label.tooltip_text = "%s · %s" % [friend.code, state]
		name_label.mouse_filter = Control.MOUSE_FILTER_PASS
		var invite := _small_button(row, "Invite", Net.invite.bind(friend.code))
		invite.disabled = not connected or state == "offline" or state == "match"
		_small_button(row, "Join", _join_friend.bind(friend.code))
		_small_button(row, "✕", func() -> void:
			GameSession.remove_friend(friend.code)
			_refresh_friends())
	_friends_button.text = "FRIENDS (%d)" % online_count if online_count > 0 else "FRIENDS"
	if not connected:
		_friends_hint.text = "Find a match (Online 1v1 / 2v2) to see which friends are on the same server and invite them. Join = enter a friend's private party."
	elif Net.party != "":
		_friends_hint.text = "Private party %s: you only get matched with its members (2v2: free spots are filled with queued players, then bots)." % Net.party
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
		_join_online(MODES[_tab].online, GameSession.friend_code)
	_refresh_friends()


## Enter a friend's private party (their party code is their friend code).
func _join_friend(code: String) -> void:
	if Net.is_client() and Net.is_online():
		Net.set_party(code)
	else:
		_join_online(MODES[_tab].online, code)
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


# --- Widgets --------------------------------------------------------------------

func _small_button(parent: Control, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 34)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _line_edit(parent: Control, text: String, placeholder: String) -> LineEdit:
	var edit := LineEdit.new()
	edit.text = text
	edit.placeholder_text = placeholder
	edit.custom_minimum_size = Vector2(0, 40)
	parent.add_child(edit)
	return edit
