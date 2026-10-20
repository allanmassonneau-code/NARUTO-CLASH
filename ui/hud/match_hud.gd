class_name MatchHud
extends CanvasLayer
## Match HUD built in code, fighting-game style: scoreboard + round clock,
## team frames with live portraits, local player frame (live bust portrait,
## health with damage trail, chakra, status chips, jutsu bar with radial
## cooldowns), cast bar, low-health vignette and round announcer.

const SLOT_KEYS: Dictionary = {
	&"lmb": "LMB", &"rmb": "RMB", &"space": "SPACE", &"q": "A/Q", &"e": "E", &"ult": "R",
}
const SLOT_SIZE: float = 66.0
const PLAYER_COLOR := Color(0.35, 0.9, 0.45)

var _player: CombatCharacter
var _fighters: Array[CombatCharacter] = []
var _manager: MatchManager
var _cards: Dictionary = {}  # CombatCharacter -> widgets
var _slots: Dictionary = {}  # slot -> widgets
var _hp_bar: HealthBar
var _hp_text: Label
var _energy_segments: Array[ProgressBar] = []
var _energy_text: Label
var _status_row: HBoxContainer
var _cast_panel: PanelContainer
var _cast_bar: ProgressBar
var _cast_label: Label
var _pips: Array = [[], []]  # per team: Array[Panel]
var _round_label: Label
var _clock: Label
var _announce_root: Control
var _announce: Label
var _announce_band: ColorRect
var _announce_time: float = 0.0
var _vignette: ColorRect
var _guard_style: StyleBoxFlat
var _flash_rect: ColorRect
# 20v20 battle widgets.
var _ticket_labels: Array[Label] = []
var _feed: VBoxContainer
var _minimap: BattleMinimap
var _respawn_label: Label
var _was_ult: bool = false
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
	for fighter: CombatCharacter in _cards:
		_update_card(fighter, _cards[fighter])
	_update_player_frame()
	if _manager.is_battle():
		_update_battle(delta)
	_update_clock()
	for slot: StringName in _slots:
		_update_slot(slot, _slots[slot])
	_update_announcer(delta)
	var ult: bool = _player.abilities.phase == AbilityController.Phase.ACTIVE and _player.abilities.current.energy_cost >= 100.0
	if ult and not _was_ult:
		_flash_rect.color.a = 0.45  # ultimate: white flash
	_was_ult = ult
	_flash_rect.color.a = maxf(0.0, _flash_rect.color.a - delta * 1.8)
	var hp_ratio: float = _player.health.get_ratio()
	var danger: float = 0.0 if _player.is_dead() else clampf((0.35 - hp_ratio) / 0.35, 0.0, 1.0)
	(_vignette.material as ShaderMaterial).set_shader_parameter("strength", danger * (0.75 + 0.25 * sin(_time * 6.0)))


# --- Updates --------------------------------------------------------------

func _update_card(fighter: CombatCharacter, card: Dictionary) -> void:
	var health: HealthComponent = fighter.health
	(card.hp as HealthBar).set_values(health.current_health, health.max_health, health.recoverable_health, health.shield)
	(card.energy as ProgressBar).value = fighter.energy.current_energy
	var dead: bool = fighter.is_dead()
	(card.root as Control).modulate = Color(0.55, 0.55, 0.6, 0.8) if dead else Color.WHITE
	(card.ko as Control).visible = dead
	_fill_status(card.status as HBoxContainer, fighter, 3)


func _update_player_frame() -> void:
	var health: HealthComponent = _player.health
	_hp_bar.set_values(health.current_health, health.max_health, health.recoverable_health, health.shield)
	_hp_text.text = "%d / %d" % [ceili(health.current_health), roundi(health.max_health)]
	var energy: float = _player.energy.current_energy
	for i in _energy_segments.size():
		var seg: ProgressBar = _energy_segments[i]
		seg.value = clampf(energy - i * 25.0, 0.0, 25.0)
		seg.modulate = Color(1.4, 1.4, 1.6) if seg.value >= 25.0 and energy >= 100.0 and fmod(_time, 0.6) < 0.3 else Color.WHITE
	_energy_text.text = "%d" % floori(energy)
	_fill_status(_status_row, _player, 6)
	if _player.parry_flash > 0.0:
		_guard_style.bg_color = Color(1.0, 0.85, 0.3, 0.95)
	elif _player.guarding:
		_guard_style.bg_color = Color(0.25, 0.45, 0.8, 0.95)
	else:
		_guard_style.bg_color = Color(0.08, 0.1, 0.16, 0.95)
	var abilities: AbilityController = _player.abilities
	_cast_panel.visible = abilities.phase == AbilityController.Phase.STARTUP and abilities.current.startup_time >= 0.2
	if _cast_panel.visible:
		_cast_label.text = abilities.current.display_name.to_upper()
		_cast_bar.value = abilities.phase_elapsed / abilities.current.startup_time * 100.0
		_cast_bar.add_theme_stylebox_override("fill", UiStyle.bar_fill(abilities.current.color.lightened(0.2), 3))


func _update_slot(slot: StringName, w: Dictionary) -> void:
	var abilities: AbilityController = _player.abilities
	var a: AbilityData = abilities.get_ability(slot)
	var cd: float = abilities.get_cooldown_left(slot)
	var ratio: float = 0.0
	var text: String = ""
	var lacks_energy: bool = false
	if cd > 0.0:
		ratio = cd / maxf(maxf(a.cooldown, a.cancel_cooldown), 0.01)
		text = "%.1f" % cd if cd < 10.0 else str(ceili(cd))
	elif not _player.energy.can_afford(a.energy_cost):
		ratio = 1.0 - _player.energy.current_energy / a.energy_cost
		lacks_energy = true
	var sweep := w.sweep as CooldownSweep
	sweep.ratio = clampf(ratio, 0.0, 1.0)
	sweep.color = Color(0.03, 0.06, 0.18, 0.74) if lacks_energy else Color(0.02, 0.02, 0.05, 0.74)
	(w.cd as Label).text = text
	(w.icon as TextureRect).modulate = Color.WHITE if ratio <= 0.0 else Color(0.62, 0.62, 0.68)
	var icon_tex := _icon_of(a)
	if w.icon.texture != icon_tex:
		(w.icon as TextureRect).texture = icon_tex  # copied jutsu (Kakashi)
	var style := w.style as StyleBoxFlat
	var ready: bool = ratio <= 0.0
	if abilities.current_slot == slot:
		style.border_color = a.color.lightened(0.45)
		style.set_border_width_all(3)
	elif slot == &"ult" and ready:
		style.border_color = UiStyle.ACCENT.lerp(Color.WHITE, 0.5 + 0.5 * sin(_time * 6.0))
		style.set_border_width_all(3)
		style.shadow_color = Color(UiStyle.ACCENT, 0.55 + 0.25 * sin(_time * 6.0))
		style.shadow_size = 12
	else:
		style.border_color = Color(1, 1, 1, 0.22) if ready else Color(0, 0, 0, 0.9)
		style.set_border_width_all(2)
		style.shadow_size = 0
	# "Ready" pop when a cooldown ends.
	if ready and not w.was_ready:
		var box := w.box as Control
		box.pivot_offset = box.size / 2.0
		box.scale = Vector2.ONE * 1.15
		box.create_tween().tween_property(box, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	w.was_ready = ready


func _update_clock() -> void:
	var rules: ArenaRules = _manager.rules
	if rules == null:
		return
	var t: int = int(rules.fight_time)
	_clock.text = "%d:%02d" % [t / 60, t % 60]
	var until_sd: float = ArenaRules.SUDDEN_DEATH_AT - rules.fight_time
	if rules.is_sudden_death():
		_clock.add_theme_color_override("font_color", Color(1.0, 0.3, 0.45))
	elif until_sd <= 10.0:
		_clock.add_theme_color_override("font_color", Color(1.0, 0.75, 0.3).lerp(Color.WHITE, 0.5 + 0.5 * sin(_time * 8.0)))
	else:
		_clock.add_theme_color_override("font_color", Color.WHITE)


## Status chips (crowd control first) for a fighter.
func _fill_status(row: HBoxContainer, fighter: CombatCharacter, max_chips: int) -> void:
	var chips: Array = []
	var s: StatusController = fighter.status
	var T := StatusController.Type
	var table: Array = [
		[T.STUN, "STUN", Color(1.0, 0.85, 0.2)], [T.INCAPACITATE, "GENJUTSU", Color(0.85, 0.3, 0.9)],
		[T.ROOT, "ROOT", Color(0.75, 0.55, 0.3)], [T.SILENCE, "SILENCE", Color(0.7, 0.75, 1.0)],
		[T.SLOW, "SLOW", Color(0.4, 0.6, 1.0)], [T.BURN, "BURN", Color(1.0, 0.45, 0.15)],
		[T.SEAL, "SEAL", Color(1.0, 0.9, 0.35)], [T.HASTE, "HASTE", Color(0.4, 1.0, 0.8)],
		[T.EMPOWER, "EMPOWER", Color(0.8, 0.4, 1.0)], [T.REGEN, "REGEN", Color(0.4, 1.0, 0.5)],
		[T.IMMATERIAL, "INTANGIBLE", Color(0.85, 0.9, 1.0)], [T.COUNTER, "COUNTER", Color(1.0, 0.6, 0.6)],
	]
	for entry: Array in table:
		if s.has_status(entry[0]):
			chips.append([entry[1], entry[2], s.get_remaining(entry[0])])
	if fighter.guarding:
		chips.push_front(["GUARD", Color(0.6, 0.8, 1.0), -1.0])
	var marks: int = s.get_stacks(T.MARK)
	if marks > 0:
		chips.append(["MARK ×%d" % marks, Color(0.95, 0.2, 0.25), -1.0])
	var lock: int = s.get_stacks(T.LOCK)
	if lock > 0:
		chips.append(["BLOCK ×%d" % lock, Color(0.7, 0.75, 1.0), -1.0])
	if fighter.health.shield > 0.0:
		chips.append(["SHIELD %d" % ceili(fighter.health.shield), Color(0.7, 0.85, 1.0), -1.0])
	chips = chips.slice(0, max_chips)
	var children: Array[Node] = row.get_children()
	for i in maxi(chips.size(), children.size()):
		if i >= chips.size():
			(children[i] as Control).visible = false
			continue
		var chip: PanelContainer
		if i < children.size():
			chip = children[i]
		else:
			chip = PanelContainer.new()
			chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(chip)
			var l := UiStyle.label(chip, "", 11, Color.WHITE, 900)
			l.add_theme_constant_override("outline_size", 4)
		chip.visible = true
		var c: Color = chips[i][1]
		chip.add_theme_stylebox_override("panel", UiStyle.panel(Color(c.darkened(0.55), 0.92), 5, c, 5))
		var label := chip.get_child(0) as Label
		var left: float = chips[i][2]
		label.text = chips[i][0] + (" %.1f" % left if left > 0.0 and left < 10.0 else "")
		label.add_theme_color_override("font_color", c.lightened(0.35))


# --- Announcer ------------------------------------------------------------

func _on_state_changed(state: MatchManager.State, message: String) -> void:
	_round_label.text = "BATTLE" if _manager.is_battle() else "ROUND %d" % maxi(_manager.round_number, 1)
	var color: Color = Color.WHITE
	if state == MatchManager.State.FIGHTING and message == "FIGHT!":
		Sfx.play(&"gong", Vector3.INF, -4.0)
		color = UiStyle.ACCENT
	elif message == "SUDDEN DEATH":
		Sfx.play(&"gong", Vector3.INF, -2.0, 0.7)
		color = Color(1.0, 0.3, 0.45)
	elif state == MatchManager.State.ROUND_OVER or state == MatchManager.State.MATCH_OVER:
		Sfx.play(&"gong", Vector3.INF, -6.0, 1.25)
		color = UiStyle.TEAM_COLORS[0] if message.begins_with(MatchManager.TEAM_NAMES[0]) else UiStyle.TEAM_COLORS[1]
	_announce.text = message.to_upper() if state != MatchManager.State.MATCH_OVER else message
	_announce.add_theme_color_override("font_color", color)
	_announce_band.color = Color(color.darkened(0.6), 0.75)
	_announce_time = 999.0 if state == MatchManager.State.MATCH_OVER else 1.5
	_announce_root.modulate.a = 1.0
	_announce_root.pivot_offset = _announce_root.size / 2.0
	_announce_root.scale = Vector2(1.6, 0.4)
	_announce_root.create_tween().tween_property(_announce_root, "scale", Vector2.ONE, 0.28) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _update_announcer(delta: float) -> void:
	if _announce_time > 0.0:
		_announce_time -= delta
		_announce_root.modulate.a = clampf(_announce_time * 3.0, 0.0, 1.0)


func _on_score_changed(scores: Array[int]) -> void:
	for team in 2:
		var pips: Array = _pips[team]
		for i in pips.size():
			var won: bool = i < scores[team]
			var style := UiStyle.panel(UiStyle.TEAM_COLORS[team] if won else Color(1, 1, 1, 0.1), 3,
				UiStyle.TEAM_COLORS[team].lightened(0.3) if won else Color(1, 1, 1, 0.25), 0)
			style.set_border_width_all(1)
			(pips[i] as Panel).add_theme_stylebox_override("panel", style)


# --- Battle (20v20) --------------------------------------------------------

func _build_battle(root: Control) -> void:
	_feed = VBoxContainer.new()
	_feed.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_feed.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_feed.offset_right = -18.0
	_feed.offset_top = 16.0
	_feed.add_theme_constant_override("separation", 4)
	_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_feed)
	_manager.kill_feed.connect(_on_kill)
	_minimap = BattleMinimap.new()
	_minimap.manager = _manager
	_minimap.player = _player
	_minimap.custom_minimum_size = BattleMinimap.SIZE
	_minimap.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_minimap.offset_left = 18.0
	_minimap.offset_top = -BattleMinimap.SIZE.y - 18.0
	_minimap.offset_right = 18.0 + BattleMinimap.SIZE.x
	_minimap.offset_bottom = -18.0
	root.add_child(_minimap)
	_respawn_label = UiStyle.label(root, "", 34, Color.WHITE, 900)
	_respawn_label.add_theme_constant_override("outline_size", 10)
	_respawn_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_respawn_label.offset_left = -400
	_respawn_label.offset_right = 400
	_respawn_label.offset_top = 40
	_respawn_label.offset_bottom = 100
	_respawn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _update_battle(_delta: float) -> void:
	for team in _ticket_labels.size():
		_ticket_labels[team].text = str(_manager.tickets[team])
		_ticket_labels[team].add_theme_color_override("font_color", Color(1.0, 0.35, 0.3) if _manager.tickets[team] <= 10 else Color.WHITE)
	var left: float = _manager.respawn_left(_player)
	_respawn_label.text = "RESPAWN IN %d" % ceili(left) if left > 0.0 else ""


func _on_kill(killer: CombatCharacter, victim: CombatCharacter) -> void:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", UiStyle.panel(Color(0.04, 0.03, 0.07, 0.8), 6, Color(0, 0, 0, 0), 8))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feed.add_child(row)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	row.add_child(line)
	if killer != null:
		_feed_name(line, killer)
		UiStyle.label(line, "✕", 14, Color(1, 1, 1, 0.7), 900)
	_feed_name(line, victim)
	if killer == _player or victim == _player:
		row.add_theme_stylebox_override("panel", UiStyle.panel(Color(0.25, 0.15, 0.02, 0.9), 6, UiStyle.ACCENT, 8))
	while _feed.get_child_count() > 6:
		var old: Node = _feed.get_child(0)
		_feed.remove_child(old)
		old.queue_free()
	var tween := row.create_tween()
	tween.tween_interval(5.0)
	tween.tween_property(row, "modulate:a", 0.0, 0.6)
	tween.tween_callback(row.queue_free)


func _feed_name(parent: Control, fighter: CombatCharacter) -> void:
	var title: String = fighter.data.short_name if fighter.data.short_name != "" else fighter.data.display_name
	var color: Color = PLAYER_COLOR if fighter == _player else UiStyle.TEAM_COLORS[fighter.team].lightened(0.3)
	UiStyle.label(parent, title, 14, color, 800)


# --- Build ----------------------------------------------------------------

func _build() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiStyle.theme()
	add_child(root)
	_build_vignette(root)
	_build_scoreboard(root)
	if _manager.is_battle():
		_build_battle(root)
	else:
		_build_team_column(root, 0)
		_build_team_column(root, 1)
	_build_player_frame(root)
	_build_announcer(root)
	_flash_rect = ColorRect.new()
	_flash_rect.color = Color(1, 1, 1, 0)
	_flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_flash_rect)


func _build_vignette(root: Control) -> void:
	_vignette = ColorRect.new()
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float strength = 0.0;
void fragment() {
	float d = distance(UV, vec2(0.5));
	float edge = smoothstep(0.35, 0.75, d);
	COLOR = vec4(0.75, 0.0, 0.05, edge * strength * 0.65);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	_vignette.material = mat
	root.add_child(_vignette)


func _build_scoreboard(root: Control) -> void:
	var holder := HBoxContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	holder.grow_horizontal = Control.GROW_DIRECTION_BOTH
	holder.offset_top = 12.0
	holder.add_theme_constant_override("separation", 0)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(holder)
	for team in 2:
		if team == 1:
			var mid := PanelContainer.new()
			var mid_style := UiStyle.panel(Color(0.04, 0.03, 0.06, 0.95), 0, UiStyle.ACCENT, 16)
			mid_style.set_border_width_all(0)
			mid_style.border_width_bottom = 3
			mid.add_theme_stylebox_override("panel", mid_style)
			mid.custom_minimum_size = Vector2(130, 0)
			holder.add_child(mid)
			var col := VBoxContainer.new()
			col.add_theme_constant_override("separation", -4)
			mid.add_child(col)
			_round_label = UiStyle.label(col, "ROUND 1", 12, UiStyle.ACCENT, 900)
			_round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_clock = UiStyle.label(col, "0:00", 28, Color.WHITE, 900)
			_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var plate := PanelContainer.new()
		var color: Color = UiStyle.TEAM_COLORS[team]
		var style := UiStyle.panel(Color(color.darkened(0.7), 0.92), 0, color, 14)
		style.set_border_width_all(0)
		style.border_width_bottom = 3
		if team == 0:
			style.corner_radius_bottom_left = 14
			style.corner_radius_top_left = 14
		else:
			style.corner_radius_bottom_right = 14
			style.corner_radius_top_right = 14
		plate.add_theme_stylebox_override("panel", style)
		plate.custom_minimum_size = Vector2(250, 0)
		holder.add_child(plate)
		var side := HBoxContainer.new()
		side.add_theme_constant_override("separation", 8)
		side.alignment = BoxContainer.ALIGNMENT_END if team == 0 else BoxContainer.ALIGNMENT_BEGIN
		plate.add_child(side)
		var name_label := UiStyle.label(side, MatchManager.TEAM_NAMES[team].to_upper(), 15, color.lightened(0.45), 900)
		name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var pips := HBoxContainer.new()
		pips.add_theme_constant_override("separation", 6)
		pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		side.add_child(pips)
		if team == 1:
			side.move_child(pips, 0)
		if _manager.is_battle():
			var tickets := UiStyle.label(pips, str(MatchManager.BATTLE_TICKETS), 24, Color.WHITE, 900)
			tickets.tooltip_text = "Reinforcements"
			_ticket_labels.append(tickets)
			continue
		for i in GameSession.rounds_to_win:
			var pip := Panel.new()
			pip.custom_minimum_size = Vector2(16, 16)
			pip.rotation = PI / 4.0
			pip.pivot_offset = Vector2(8, 8)
			pips.add_child(pip)
			_pips[team].append(pip)


func _build_team_column(root: Control, team: int) -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if team == 0:
		column.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		column.offset_left = 18.0
	else:
		column.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		column.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		column.offset_right = -18.0
	column.offset_top = 14.0
	root.add_child(column)
	for fighter: CombatCharacter in _fighters:
		if fighter.team == team:
			_cards[fighter] = _build_card(column, fighter, team == 1)


func _build_card(parent: Control, fighter: CombatCharacter, mirrored: bool) -> Dictionary:
	var color: Color = PLAYER_COLOR if fighter == _player else UiStyle.TEAM_COLORS[fighter.team]
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(300, 0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := UiStyle.panel(Color(0.05, 0.04, 0.08, 0.86), 12, Color(color, 0.55), 8)
	frame.set_border_width_all(0)
	if mirrored:
		frame.border_width_right = 3
	else:
		frame.border_width_left = 3
	card.add_theme_stylebox_override("panel", frame)
	parent.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)
	var portrait := _round_portrait(row, fighter, 58.0, color, ShinobiPortrait.Framing.FACE)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	row.add_child(info)
	if mirrored:
		row.move_child(portrait, 1)
	var title: String = fighter.data.short_name if fighter.data.short_name != "" else fighter.data.display_name.get_slice(" ", 0)
	var name_row := HBoxContainer.new()
	info.add_child(name_row)
	var name_label := UiStyle.label(name_row, title.to_upper(), 15, Color.WHITE, 900)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if fighter == _player:
		UiStyle.label(name_row, "YOU", 11, PLAYER_COLOR, 900).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var hp := HealthBar.new()
	hp.custom_minimum_size = Vector2(0, 13)
	hp.fill_color = color
	info.add_child(hp)
	var energy := UiStyle.bar(info, UiStyle.CHAKRA, 5, 2)
	energy.max_value = fighter.energy.max_energy
	var status := HBoxContainer.new()
	status.add_theme_constant_override("separation", 3)
	status.custom_minimum_size = Vector2(0, 18)
	info.add_child(status)
	var ko := UiStyle.label(portrait, "KO", 22, Color(1.0, 0.25, 0.2), 900)
	ko.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ko.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ko.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ko.add_theme_constant_override("outline_size", 8)
	ko.visible = false
	return {"root": card, "hp": hp, "energy": energy, "status": status, "ko": ko}


## Circular live portrait mirroring the fighter (poses, stun, KO).
func _round_portrait(parent: Control, fighter: CombatCharacter, diameter: float, ring: Color, framing: ShinobiPortrait.Framing) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(diameter, diameter)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(holder)
	var disc := Panel.new()
	disc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	disc.add_theme_stylebox_override("panel", UiStyle.panel(Color(fighter.data.body_color.darkened(0.55), 1.0), int(diameter / 2.0), Color(0, 0, 0, 0), 0))
	disc.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(disc)
	if CombatFx.is_enabled():
		var size_px: int = int(diameter * 2.0)
		var portrait := ShinobiPortrait.create(fighter.data, framing, Vector2i(size_px, size_px))
		portrait.mirror = fighter
		portrait.flourishes = false
		portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		disc.add_child(portrait)
	var border := Panel.new()
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.set_corner_radius_all(int(diameter / 2.0))
	style.set_border_width_all(3)
	style.border_color = ring
	style.anti_aliasing = true
	border.add_theme_stylebox_override("panel", style)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(border)
	return holder


func _build_player_frame(root: Control) -> void:
	var frame := HBoxContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	frame.grow_horizontal = Control.GROW_DIRECTION_BOTH
	frame.grow_vertical = Control.GROW_DIRECTION_BEGIN
	frame.offset_bottom = -16.0
	frame.add_theme_constant_override("separation", -26)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(frame)

	var portrait_box := VBoxContainer.new()
	portrait_box.alignment = BoxContainer.ALIGNMENT_END
	portrait_box.z_index = 1
	frame.add_child(portrait_box)
	_round_portrait(portrait_box, _player, 128.0, UiStyle.ACCENT, ShinobiPortrait.Framing.BUST)

	var panel := PanelContainer.new()
	var style := UiStyle.panel(Color(0.05, 0.04, 0.08, 0.9), 14, Color(UiStyle.ACCENT, 0.35), 14)
	style.content_margin_left = 40
	panel.add_theme_stylebox_override("panel", style)
	frame.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)

	# Cast bar sits above the whole frame.
	_cast_panel = PanelContainer.new()
	_cast_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_cast_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_cast_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_cast_panel.offset_bottom = -235.0
	_cast_panel.custom_minimum_size = Vector2(300, 0)
	_cast_panel.add_theme_stylebox_override("panel", UiStyle.panel(Color(0.05, 0.04, 0.08, 0.9), 8, Color(1, 1, 1, 0.2), 8))
	_cast_panel.visible = false
	root.add_child(_cast_panel)
	var cast_box := VBoxContainer.new()
	cast_box.add_theme_constant_override("separation", 3)
	_cast_panel.add_child(cast_box)
	_cast_label = UiStyle.label(cast_box, "", 13, UiStyle.TEXT, 900)
	_cast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cast_bar = UiStyle.bar(cast_box, UiStyle.ACCENT, 7, 3)

	# Name, statuses.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	col.add_child(head)
	var title: String = _player.data.display_name.to_upper()
	UiStyle.label(head, title, 16, Color.WHITE, 900)
	_status_row = HBoxContainer.new()
	_status_row.add_theme_constant_override("separation", 4)
	_status_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_row.alignment = BoxContainer.ALIGNMENT_END
	head.add_child(_status_row)

	# Health.
	var hp_stack := Control.new()
	hp_stack.custom_minimum_size = Vector2(0, 22)
	col.add_child(hp_stack)
	_hp_bar = HealthBar.new()
	_hp_bar.fill_color = PLAYER_COLOR
	_hp_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hp_stack.add_child(_hp_bar)
	_hp_text = UiStyle.label(hp_stack, "", 14, Color.WHITE, 900)
	_hp_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hp_text.add_theme_constant_override("outline_size", 5)

	# Chakra: 4 segments of 25.
	var energy_row := HBoxContainer.new()
	energy_row.add_theme_constant_override("separation", 4)
	col.add_child(energy_row)
	for i in 4:
		var seg := UiStyle.bar(energy_row, UiStyle.CHAKRA, 9, 3)
		seg.max_value = 25.0
		seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_energy_segments.append(seg)
	_energy_text = UiStyle.label(energy_row, "0", 12, UiStyle.CHAKRA.lightened(0.4), 900)
	_energy_text.custom_minimum_size = Vector2(28, 0)
	_energy_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# Jutsu bar.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	for slot: StringName in AbilityController.SLOTS:
		var a: AbilityData = _player.abilities.get_ability(slot)
		if a != null:
			if slot == &"ult":
				var gap := Control.new()
				gap.custom_minimum_size = Vector2(8, 0)
				row.add_child(gap)
			_slots[slot] = _build_slot(row, slot, a)
	_build_guard_slot(row)


## Guard / parry reminder: lights up while guarding, flashes on a parry.
func _build_guard_slot(parent: Control) -> void:
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(58, SLOT_SIZE)
	box.size_flags_vertical = Control.SIZE_SHRINK_END
	_guard_style = UiStyle.panel(Color(0.08, 0.1, 0.16, 0.95), 10, Color(0.6, 0.8, 1.0, 0.35), 4)
	_guard_style.set_border_width_all(2)
	box.add_theme_stylebox_override("panel", _guard_style)
	box.tooltip_text = "Hold F: guard. F + LMB right before an enemy basic attack: perfect parry (stun)."
	parent.add_child(box)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	box.add_child(col)
	for line: Array in [["F", 20], ["GUARD", 10], ["+LMB", 9]]:
		var l := UiStyle.label(col, line[0], line[1], Color(0.75, 0.88, 1.0), 900)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _build_slot(parent: Control, slot: StringName, a: AbilityData) -> Dictionary:
	var size: float = SLOT_SIZE * (1.14 if slot == &"ult" else 1.0)
	var box := Control.new()
	box.custom_minimum_size = Vector2(size, size)
	box.size_flags_vertical = Control.SIZE_SHRINK_END
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(box)
	var clip := Panel.new()
	clip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip.add_theme_stylebox_override("panel", UiStyle.panel(Color(0.02, 0.02, 0.04, 1.0), 10, Color(0, 0, 0, 0), 0))
	clip.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(clip)
	var icon := TextureRect.new()
	icon.texture = _icon_of(a)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(icon)
	var sweep := CooldownSweep.new()
	sweep.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip.add_child(sweep)
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
	var cd := UiStyle.label(box, "", 24, Color.WHITE, 900)
	cd.add_theme_constant_override("outline_size", 7)
	cd.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cd.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", UiStyle.panel(Color(0.08, 0.07, 0.12, 0.96), 5, Color(1, 1, 1, 0.3), 4))
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(badge)
	badge.position = Vector2(-5, size - 15)
	UiStyle.label(badge, SLOT_KEYS[slot], 10, Color.WHITE, 900)
	return {"box": box, "icon": icon, "sweep": sweep, "cd": cd, "style": style, "was_ready": true}


func _build_announcer(root: Control) -> void:
	_announce_root = Control.new()
	_announce_root.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_announce_root.offset_left = -800.0
	_announce_root.offset_right = 800.0
	_announce_root.offset_top = -210.0
	_announce_root.offset_bottom = -110.0
	_announce_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_announce_root.modulate.a = 0.0
	root.add_child(_announce_root)
	_announce_band = ColorRect.new()
	_announce_band.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_announce_band.offset_top = 18.0
	_announce_band.offset_bottom = -18.0
	_announce_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var band_shader := Shader.new()
	band_shader.code = """
shader_type canvas_item;
void fragment() {
	float fade = smoothstep(0.0, 0.3, UV.x) * smoothstep(1.0, 0.7, UV.x);
	COLOR = vec4(COLOR.rgb, COLOR.a * fade);
}
"""
	var band_mat := ShaderMaterial.new()
	band_mat.shader = band_shader
	_announce_band.material = band_mat
	_announce_root.add_child(_announce_band)
	_announce = UiStyle.label(_announce_root, "", 64, Color.WHITE, 900)
	_announce.add_theme_constant_override("outline_size", 14)
	_announce.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.0))
	_announce.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_announce.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_announce.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


## Shinobi Striker skill icon for an ability (cached per ability).
var _icons: Dictionary = {}


func _icon_of(a: AbilityData) -> Texture2D:
	if a == null:
		return null
	if not _icons.has(a):
		_icons[a] = SSIcons.for_ability(a)
	return _icons[a]
