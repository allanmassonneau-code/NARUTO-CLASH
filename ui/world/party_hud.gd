class_name PartyHud
extends Control
## Shared world online: party frame (members' HP and distance), arrows at the
## screen edge toward members out of view, the online players list (P) with
## invitations, and the invitation prompt.

const LIST_KEY: Key = KEY_P
const INVITE_TIMEOUT: float = 20.0

var _net: WorldNet
var _hud: WorldHud
var _frame: VBoxContainer
var _list: PanelContainer
var _invite: PanelContainer
var _invite_left: float = 0.0
var _rows: Dictionary = {}  # peer -> {"hp": ProgressBar, "info": Label}


func _init(net: WorldNet, hud: WorldHud) -> void:
	_net = net
	_hud = hud


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame = VBoxContainer.new()
	_frame.position = Vector2(24, 230)
	_frame.add_theme_constant_override("separation", 6)
	add_child(_frame)
	var hint := UiStyle.label(self, "P : joueurs en ligne / groupe", 13, UiStyle.MUTED, 700)
	hint.position = Vector2(24, 204)
	_net.party_changed.connect(_rebuild_frame)
	_net.players_changed.connect(func() -> void:
		_rebuild_frame()
		if _list != null and _list.visible:
			_show_list())
	_net.invited.connect(_on_invited)
	_net.notice.connect(func(text: String) -> void: _hud.toast(text, Color(0.75, 0.9, 1.0)))
	_rebuild_frame()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.physical_keycode == LIST_KEY:
		if _list != null and _list.visible:
			_list.visible = false
		else:
			_show_list()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _invite != null and _invite.visible:
		_invite_left -= delta
		if _invite_left <= 0.0:
			_invite.visible = false
	var me: CombatCharacter = _net.world.player if _net.world != null else null
	for peer: int in _rows:
		var puppet: CombatCharacter = _net.players.get(peer, {}).get("puppet")
		var row: Dictionary = _rows[peer]
		if not is_instance_valid(puppet) or me == null:
			continue
		(row.hp as ProgressBar).value = puppet.health.current_health / maxf(puppet.health.max_health, 1.0) * 100.0
		var dist: float = HitQuery.flat(puppet.global_position - me.global_position).length()
		(row.info as Label).text = "%s  ·  %d m%s" % [_net.players[peer].name, roundi(dist), "  ·  K.O." if puppet.is_dead() else ""]
	queue_redraw()


## Arrows at the screen edge toward party members out of view.
func _draw() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	var rect := Rect2(Vector2(40, 40), size - Vector2(80, 80))
	var center: Vector2 = size / 2.0
	for peer: int in _net.party:
		var puppet: CombatCharacter = _net.players.get(peer, {}).get("puppet")
		if not is_instance_valid(puppet):
			continue
		var world_at: Vector3 = puppet.global_position + Vector3.UP * 1.0
		var at: Vector2 = camera.unproject_position(world_at)
		if not camera.is_position_behind(world_at) and rect.has_point(at):
			continue
		var dir: Vector2 = (at - center).normalized()
		if camera.is_position_behind(world_at):
			dir = -dir
		var t: float = minf(absf((rect.size.x / 2.0) / dir.x) if absf(dir.x) > 0.001 else INF,
			absf((rect.size.y / 2.0) / dir.y) if absf(dir.y) > 0.001 else INF)
		var tip: Vector2 = center + dir * t
		var side := Vector2(-dir.y, dir.x)
		var color := Color(0.45, 0.9, 1.0, 0.95)
		draw_colored_polygon(PackedVector2Array([tip, tip - dir * 22.0 + side * 11.0, tip - dir * 22.0 - side * 11.0]), color)
		draw_string(UiStyle.font(700), tip - dir * 30.0 - Vector2(40, -5), str(_net.players[peer].name), HORIZONTAL_ALIGNMENT_CENTER, 80, 14, color)


func _rebuild_frame() -> void:
	for child: Node in _frame.get_children():
		child.queue_free()
	_rows.clear()
	if _net.party.is_empty():
		return
	UiStyle.label(_frame, "GROUPE", 14, UiStyle.ACCENT, 900)
	for peer: int in _net.party:
		if not _net.players.has(peer):
			continue
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		_frame.add_child(box)
		var info := UiStyle.label(box, str(_net.players[peer].name), 14, Color.WHITE, 700)
		var hp := UiStyle.bar(box, Color(0.35, 0.9, 0.45), 8.0)
		hp.custom_minimum_size = Vector2(200, 8)
		_rows[peer] = {"hp": hp, "info": info}


func _show_list() -> void:
	if _list == null:
		_list = PanelContainer.new()
		_list.add_theme_stylebox_override("panel", UiStyle.panel(UiStyle.BG, 10, UiStyle.BORDER, 14.0))
		_list.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
		_list.offset_left = -440
		_list.offset_right = -24
		_list.offset_top = -220
		_list.offset_bottom = 220
		add_child(_list)
	for child: Node in _list.get_children():
		child.queue_free()
	_list.visible = true
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_list.add_child(col)
	UiStyle.label(col, "JOUEURS EN LIGNE  %d / %d" % [_net.players.size() + 1, WorldNet.MAX_PLAYERS], 16, UiStyle.ACCENT, 900)
	UiStyle.label(col, "PvP partout hors des villages. Ton groupe ne peut pas te blesser.", 12, UiStyle.MUTED, 600)
	if _net.players.is_empty():
		UiStyle.label(col, "Personne d'autre pour l'instant.", 14, Color.WHITE, 600)
	var me: CombatCharacter = _net.world.player if _net.world != null else null
	for peer: int in _net.players:
		var entry: Dictionary = _net.players[peer]
		var row := HBoxContainer.new()
		col.add_child(row)
		var dist: String = ""
		if me != null and is_instance_valid(entry.puppet):
			dist = "  ·  %d m" % roundi(HitQuery.flat((entry.puppet as CombatCharacter).global_position - me.global_position).length())
		var l := UiStyle.label(row, "%s  ·  %s%s" % [entry.name, str(World.VILLAGE_NAMES.get(entry.get("village", &""), "")).capitalize(), dist], 14, Color.WHITE, 600)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if _net.party.has(peer):
			UiStyle.label(row, "groupe", 13, Color(0.45, 0.9, 1.0), 800)
		else:
			var b := Button.new()
			b.text = "Inviter"
			b.focus_mode = Control.FOCUS_NONE
			b.pressed.connect(func() -> void: _net.invite(peer))
			row.add_child(b)
	if not _net.party.is_empty():
		var leave := Button.new()
		leave.text = "Quitter le groupe"
		leave.focus_mode = Control.FOCUS_NONE
		leave.pressed.connect(func() -> void:
			_net.leave_party()
			_list.visible = false)
		col.add_child(leave)
	var close := Button.new()
	close.text = "Fermer (P)"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func() -> void: _list.visible = false)
	col.add_child(close)


func _on_invited(from_peer: int, from_name: String) -> void:
	if _invite == null:
		_invite = PanelContainer.new()
		_invite.add_theme_stylebox_override("panel", UiStyle.panel(UiStyle.BG, 10, UiStyle.ACCENT, 14.0))
		_invite.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		_invite.offset_left = -220
		_invite.offset_right = 220
		_invite.offset_top = 90
		_invite.offset_bottom = 190
		add_child(_invite)
	for child: Node in _invite.get_children():
		child.queue_free()
	_invite.visible = true
	_invite_left = INVITE_TIMEOUT
	var col := VBoxContainer.new()
	_invite.add_child(col)
	UiStyle.label(col, "%s t'invite dans son groupe" % from_name, 16, Color.WHITE, 800)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	for choice: Array in [["Accepter", true], ["Refuser", false]]:
		var b := Button.new()
		b.text = choice[0]
		b.focus_mode = Control.FOCUS_NONE
		var accept: bool = choice[1]
		b.pressed.connect(func() -> void:
			_net.answer(from_peer, accept)
			_invite.visible = false)
		row.add_child(b)
