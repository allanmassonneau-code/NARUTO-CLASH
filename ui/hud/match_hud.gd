class_name MatchHud
extends CanvasLayer
## Match HUD, built in code (placeholder UI): team health bars, score,
## announcer, local player's chakra energy and ability cooldowns.

const SLOT_KEYS: Dictionary = {
	&"lmb": "LMB", &"rmb": "RMB", &"space": "SPACE", &"q": "Q/A", &"e": "E", &"ult": "F",
}

var _player: CombatCharacter
var _fighters: Array[CombatCharacter] = []
var _bars: Dictionary = {}  # CombatCharacter -> {hp, rec, label}
var _ability_labels: Dictionary = {}  # slot -> Label
var _energy_bar: ProgressBar
var _energy_label: Label
var _score_label: Label
var _announce: Label
var _announce_time: float = 0.0


func bind(player: CombatCharacter, fighters: Array[CombatCharacter], match_manager: MatchManager) -> void:
	_player = player
	_fighters = fighters
	_build()
	match_manager.state_changed.connect(_on_state_changed)
	match_manager.score_changed.connect(_on_score_changed)


func _process(delta: float) -> void:
	if _player == null:
		return
	for fighter: CombatCharacter in _fighters:
		var w: Dictionary = _bars[fighter]
		(w.hp as ProgressBar).max_value = fighter.health.max_health
		(w.hp as ProgressBar).value = fighter.health.current_health
		(w.rec as ProgressBar).max_value = fighter.health.max_health
		(w.rec as ProgressBar).value = fighter.health.current_health + fighter.health.recoverable_health
		(w.label as Label).text = "%s%s  %d" % [fighter.data.display_name, " (you)" if fighter == _player else "", ceili(fighter.health.current_health)]
	_energy_bar.value = _player.energy.current_energy
	_energy_label.text = "Chakra Energy %d / %d" % [floori(_player.energy.current_energy), _player.energy.max_energy]
	for slot: StringName in _ability_labels:
		_update_ability_label(slot, _ability_labels[slot])
	if _announce_time > 0.0:
		_announce_time -= delta
		_announce.modulate.a = clampf(_announce_time, 0.0, 1.0)


func _update_ability_label(slot: StringName, label: Label) -> void:
	var abilities: AbilityController = _player.abilities
	var a: AbilityData = abilities.get_ability(slot)
	var cd: float = abilities.get_cooldown_left(slot)
	var state: String = "READY"
	if abilities.current_slot == slot:
		state = AbilityController.Phase.keys()[abilities.phase]
	elif cd > 0.0:
		state = "%.1f" % cd
	elif not _player.energy.can_afford(a.energy_cost):
		state = "%d EN" % a.energy_cost
	label.text = "[%s]\n%s\n%s" % [SLOT_KEYS[slot], a.display_name, state]
	label.modulate = Color.WHITE if state == "READY" else Color(1, 1, 1, 0.45)
	if abilities.current_slot == slot:
		label.modulate = a.color.lightened(0.3)


func _on_state_changed(state: MatchManager.State, message: String) -> void:
	_announce.text = message
	_announce.modulate.a = 1.0
	_announce_time = 999.0 if state == MatchManager.State.MATCH_OVER else 1.6


func _on_score_changed(scores: Array[int]) -> void:
	_score_label.text = "%d  -  %d" % [scores[0], scores[1]]


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var left := _team_column(root, 0)
	var right := _team_column(root, 1)
	for fighter: CombatCharacter in _fighters:
		_bars[fighter] = _health_widget(left if fighter.team == 0 else right, fighter)

	_score_label = _label(root, "0  -  0", 34)
	_score_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_score_label.offset_top = 10.0
	_announce = _label(root, "", 48)
	_announce.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_announce.offset_top = -160.0

	var bottom := VBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.offset_bottom = -12.0
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bottom)
	_energy_label = _label(bottom, "", 14)
	_energy_bar = _bar(bottom, Color(0.25, 0.6, 1.0), 100.0)
	_energy_bar.custom_minimum_size = Vector2(560, 10)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	bottom.add_child(row)
	for slot: StringName in AbilityController.SLOTS:
		if _player.abilities.get_ability(slot) == null:
			continue
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(88, 64)
		panel.add_theme_stylebox_override("panel", _style(Color(0, 0, 0, 0.6)))
		row.add_child(panel)
		var label := _label(panel, "", 13)
		_ability_labels[slot] = label


func _team_column(root: Control, team: int) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT if team == 0 else Control.PRESET_TOP_RIGHT)
	column.grow_horizontal = Control.GROW_DIRECTION_END if team == 0 else Control.GROW_DIRECTION_BEGIN
	column.offset_left = 16.0 if team == 0 else -336.0
	column.offset_right = 336.0 if team == 0 else -16.0
	column.offset_top = 12.0
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(column)
	return column


func _health_widget(parent: Control, fighter: CombatCharacter) -> Dictionary:
	var label := _label(parent, fighter.data.display_name, 15)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if fighter.team == 0 else HORIZONTAL_ALIGNMENT_RIGHT
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(320, 16)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(holder)
	var rec := _bar(holder, Color(0.9, 0.9, 0.9, 0.35), fighter.health.max_health)
	rec.set_anchors_preset(Control.PRESET_FULL_RECT)
	var hp := _bar(holder, fighter.data.body_color, fighter.health.max_health)
	hp.set_anchors_preset(Control.PRESET_FULL_RECT)
	hp.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	return {"hp": hp, "rec": rec, "label": label}


func _bar(parent: Control, color: Color, max_value: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = max_value
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(320, 16)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("fill", _style(color))
	bar.add_theme_stylebox_override("background", _style(Color(0, 0, 0, 0.55)))
	parent.add_child(bar)
	return bar


func _label(parent: Control, text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style
