class_name MatchHud
extends CanvasLayer
## Match HUD built in code: scoreboard, team frames, local player frame
## (health, chakra energy, cast bar, jutsu bar) and round announcer.

const SLOT_KEYS: Dictionary = {
	&"lmb": "LMB", &"rmb": "RMB", &"space": "SPACE", &"q": "A/Q", &"e": "E", &"ult": "F",
}
const SLOT_SIZE: float = 62.0

var _player: CombatCharacter
var _fighters: Array[CombatCharacter] = []
var _manager: MatchManager
var _cards: Dictionary = {}  # CombatCharacter -> {hp, rec, energy}
var _slots: Dictionary = {}  # slot -> {frame, icon, shade, cd, style}
var _hp_bar: ProgressBar
var _hp_rec_bar: ProgressBar
var _hp_text: Label
var _energy_segments: Array[ProgressBar] = []
var _cast_panel: PanelContainer
var _cast_bar: ProgressBar
var _cast_label: Label
var _pips: Array = [[], []]  # per team: Array[Panel]
var _round_label: Label
var _announce: Label
var _announce_time: float = 0.0
var _time: float = 0.0


func bind(player: CombatCharacter, fighters: Array[CombatCharacter], match_manager: MatchManager) -> void:
	_player = player
	_fighters = fighters
	_manager = match_manager
	_build()
	match_manager.state_changed.connect(_on_state_changed)
	match_manager.score_changed.connect(_on_score_changed)
	_on_score_changed(match_manager.scores)


func _process(delta: float) -> void:
	if _player == null:
		return
	_time += delta
	for fighter: CombatCharacter in _fighters:
		_update_card(fighter, _cards[fighter])
	_update_player_frame()
	for slot: StringName in _slots:
		_update_slot(slot, _slots[slot])
	if _announce_time > 0.0:
		_announce_time -= delta
		_announce.modulate.a = clampf(_announce_time * 2.0, 0.0, 1.0)


# --- Updates --------------------------------------------------------------

func _update_card(fighter: CombatCharacter, card: Dictionary) -> void:
	var health: HealthComponent = fighter.health
	(card.hp as ProgressBar).max_value = health.max_health
	(card.hp as ProgressBar).value = health.current_health
	(card.rec as ProgressBar).max_value = health.max_health
	(card.rec as ProgressBar).value = health.current_health + health.recoverable_health
	(card.energy as ProgressBar).value = fighter.energy.current_energy
	(card.root as Control).modulate.a = 0.45 if fighter.is_dead() else 1.0


func _update_player_frame() -> void:
	var health: HealthComponent = _player.health
	_hp_bar.max_value = health.max_health
	_hp_bar.value = health.current_health
	_hp_rec_bar.max_value = health.max_health
	_hp_rec_bar.value = health.current_health + health.recoverable_health
	_hp_text.text = "%d / %d" % [ceili(health.current_health), roundi(health.max_health)]
	var energy: float = _player.energy.current_energy
	for i in _energy_segments.size():
		_energy_segments[i].value = clampf(energy - i * 25.0, 0.0, 25.0)
	var abilities: AbilityController = _player.abilities
	_cast_panel.visible = abilities.phase == AbilityController.Phase.STARTUP and abilities.current.startup_time >= 0.2
	if _cast_panel.visible:
		_cast_label.text = abilities.current.display_name
		_cast_bar.value = abilities.phase_elapsed / abilities.current.startup_time * 100.0
		_cast_bar.add_theme_stylebox_override("fill", UiStyle.bar_fill(abilities.current.color, 3))


func _update_slot(slot: StringName, w: Dictionary) -> void:
	var abilities: AbilityController = _player.abilities
	var a: AbilityData = abilities.get_ability(slot)
	var cd: float = abilities.get_cooldown_left(slot)
	var ratio: float = 0.0
	var text: String = ""
	if cd > 0.0:
		ratio = cd / maxf(maxf(a.cooldown, a.cancel_cooldown), 0.01)
		text = "%.1f" % cd if cd < 10.0 else str(ceili(cd))
	elif not _player.energy.can_afford(a.energy_cost):
		ratio = 1.0 - _player.energy.current_energy / a.energy_cost
	var shade := w.shade as ColorRect
	shade.anchor_top = 1.0 - clampf(ratio, 0.0, 1.0)
	(w.cd as Label).text = text
	(w.icon as TextureRect).modulate = Color.WHITE if ratio <= 0.0 else Color(0.5, 0.5, 0.55)
	var style := w.style as StyleBoxFlat
	if abilities.current_slot == slot:
		style.border_color = a.color.lightened(0.35)
		style.set_border_width_all(3)
	elif slot == &"ult" and ratio <= 0.0:
		style.border_color = UiStyle.ACCENT.lerp(Color.WHITE, 0.5 + 0.5 * sin(_time * 5.0))
		style.set_border_width_all(3)
	else:
		style.border_color = Color(0, 0, 0, 0.9)
		style.set_border_width_all(2)


func _on_state_changed(state: MatchManager.State, message: String) -> void:
	_round_label.text = "ROUND %d" % maxi(_manager.round_number, 1)
	_announce.text = message
	_announce.modulate.a = 1.0
	_announce_time = 999.0 if state == MatchManager.State.MATCH_OVER else 1.4
	_announce.pivot_offset = _announce.size / 2.0
	_announce.scale = Vector2.ONE * 1.4
	create_tween().tween_property(_announce, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_score_changed(scores: Array[int]) -> void:
	for team in 2:
		var pips: Array = _pips[team]
		for i in pips.size():
			var style := (pips[i] as Panel).get_theme_stylebox("panel") as StyleBoxFlat
			style.bg_color = UiStyle.TEAM_COLORS[team] if i < scores[team] else Color(1, 1, 1, 0.12)


# --- Build ----------------------------------------------------------------

func _build() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiStyle.theme()
	add_child(root)
	_build_scoreboard(root)
	_build_team_column(root, 0)
	_build_team_column(root, 1)
	_build_player_frame(root)
	_announce = UiStyle.label(root, "", 60, Color.WHITE, 800)
	_announce.add_theme_constant_override("outline_size", 12)
	_announce.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_announce.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_announce.offset_left = -500.0
	_announce.offset_right = 500.0
	_announce.offset_top = -190.0
	_announce.offset_bottom = -90.0


func _build_scoreboard(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.offset_top = 12.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", UiStyle.panel(UiStyle.BG, 12, UiStyle.BORDER, 14))
	root.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(row)
	for team in 2:
		if team == 1:
			var mid := VBoxContainer.new()
			mid.add_theme_constant_override("separation", 0)
			row.add_child(mid)
			_round_label = UiStyle.label(mid, "ROUND 1", 12, UiStyle.MUTED, 700)
			_round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			var vs := UiStyle.label(mid, "VS", 20, Color.WHITE, 800)
			vs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var side := HBoxContainer.new()
		side.add_theme_constant_override("separation", 6)
		side.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(side)
		var name_label := UiStyle.label(side, MatchManager.TEAM_NAMES[team].to_upper(), 14, UiStyle.TEAM_COLORS[team], 800)
		if team == 1:
			side.move_child(name_label, 0)
		for i in GameSession.rounds_to_win:
			var pip := Panel.new()
			pip.custom_minimum_size = Vector2(14, 14)
			pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			pip.add_theme_stylebox_override("panel", UiStyle.panel(Color(1, 1, 1, 0.12), 7, Color(0, 0, 0, 0), 0))
			side.add_child(pip)
			if team == 0:
				side.move_child(pip, side.get_child_count() - 1)
			_pips[team].append(pip)
		if team == 1:
			side.move_child(name_label, side.get_child_count() - 1)


func _build_team_column(root: Control, team: int) -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if team == 0:
		column.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		column.offset_left = 16.0
	else:
		column.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		column.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		column.offset_right = -16.0
	column.offset_top = 14.0
	root.add_child(column)
	for fighter: CombatCharacter in _fighters:
		if fighter.team == team:
			_cards[fighter] = _build_card(column, fighter)


func _build_card(parent: Control, fighter: CombatCharacter) -> Dictionary:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(270, 0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var border: Color = UiStyle.ACCENT if fighter == _player else UiStyle.BORDER
	card.add_theme_stylebox_override("panel", UiStyle.panel(UiStyle.BG, 10, border, 10))
	parent.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)
	# Portrait: coloured disc with the initial.
	var portrait := PanelContainer.new()
	portrait.custom_minimum_size = Vector2(38, 38)
	portrait.add_theme_stylebox_override("panel", UiStyle.panel(fighter.data.body_color, 19, Color(1, 1, 1, 0.35), 0))
	row.add_child(portrait)
	var initial := UiStyle.label(portrait, fighter.data.display_name.left(1), 20, Color.WHITE, 800)
	initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 3)
	row.add_child(info)
	var title: String = fighter.data.display_name.get_slice(" ", 0)
	UiStyle.label(info, title + ("  (toi)" if fighter == _player else ""), 14, UiStyle.TEXT, 700)
	var stack := Control.new()
	stack.custom_minimum_size = Vector2(0, 10)
	info.add_child(stack)
	var rec := UiStyle.bar(stack, Color(1, 1, 1, 0.35), 10, 3)
	rec.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var hp := UiStyle.bar(stack, UiStyle.TEAM_COLORS[fighter.team] if fighter != _player else Color(0.35, 0.9, 0.45), 10, 3)
	hp.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hp.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	var energy := UiStyle.bar(info, UiStyle.CHAKRA, 4, 2)
	energy.max_value = fighter.energy.max_energy
	return {"root": card, "hp": hp, "rec": rec, "energy": energy}


func _build_player_frame(root: Control) -> void:
	var frame := VBoxContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	frame.grow_horizontal = Control.GROW_DIRECTION_BOTH
	frame.grow_vertical = Control.GROW_DIRECTION_BEGIN
	frame.offset_bottom = -14.0
	frame.add_theme_constant_override("separation", 6)
	frame.alignment = BoxContainer.ALIGNMENT_END
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(frame)

	# Cast bar (only for jutsu with a noticeable startup).
	_cast_panel = PanelContainer.new()
	_cast_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_cast_panel.custom_minimum_size = Vector2(260, 0)
	_cast_panel.add_theme_stylebox_override("panel", UiStyle.panel(UiStyle.BG, 8, UiStyle.BORDER, 8))
	_cast_panel.visible = false
	frame.add_child(_cast_panel)
	var cast_box := VBoxContainer.new()
	cast_box.add_theme_constant_override("separation", 3)
	_cast_panel.add_child(cast_box)
	_cast_label = UiStyle.label(cast_box, "", 13, UiStyle.TEXT, 700)
	_cast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cast_bar = UiStyle.bar(cast_box, UiStyle.ACCENT, 6, 3)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel(UiStyle.BG, 14, UiStyle.BORDER, 12))
	frame.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)

	# Jutsu bar.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	for slot: StringName in AbilityController.SLOTS:
		var a: AbilityData = _player.abilities.get_ability(slot)
		if a != null:
			if slot == &"ult":
				var sep := VSeparator.new()
				sep.add_theme_constant_override("separation", 6)
				row.add_child(sep)
			_slots[slot] = _build_slot(row, slot, a)

	# Health.
	var hp_stack := Control.new()
	hp_stack.custom_minimum_size = Vector2(0, 18)
	col.add_child(hp_stack)
	_hp_rec_bar = UiStyle.bar(hp_stack, Color(1, 1, 1, 0.3), 18, 5)
	_hp_rec_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hp_bar = UiStyle.bar(hp_stack, Color(0.35, 0.9, 0.45), 18, 5)
	_hp_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hp_bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	_hp_text = UiStyle.label(hp_stack, "", 13, Color.WHITE, 800)
	_hp_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# Chakra energy: 4 segments of 25.
	var energy_row := HBoxContainer.new()
	energy_row.add_theme_constant_override("separation", 4)
	col.add_child(energy_row)
	for i in 4:
		var seg := UiStyle.bar(energy_row, UiStyle.CHAKRA, 7, 3)
		seg.max_value = 25.0
		seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_energy_segments.append(seg)


func _build_slot(parent: Control, slot: StringName, a: AbilityData) -> Dictionary:
	var size: float = SLOT_SIZE * (1.12 if slot == &"ult" else 1.0)
	var box := Control.new()
	box.custom_minimum_size = Vector2(size, size)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.tooltip_text = a.display_name
	parent.add_child(box)
	var icon := TextureRect.new()
	icon.texture = a.icon
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.02, 0.05, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.anchor_top = 1.0
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(shade)
	var frame := Panel.new()
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.set_corner_radius_all(10)
	style.set_border_width_all(2)
	style.border_color = Color(0, 0, 0, 0.9)
	style.anti_aliasing = true
	frame.add_theme_stylebox_override("panel", style)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(frame)
	var cd := UiStyle.label(box, "", 22, Color.WHITE, 800)
	cd.add_theme_constant_override("outline_size", 6)
	cd.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cd.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Key badge.
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", UiStyle.panel(Color(0.05, 0.05, 0.08, 0.92), 5, Color(1, 1, 1, 0.25), 3))
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(badge)
	badge.position = Vector2(-4, size - 14)
	UiStyle.label(badge, SLOT_KEYS[slot], 10, Color.WHITE, 800)
	return {"icon": icon, "shade": shade, "cd": cd, "style": style}
