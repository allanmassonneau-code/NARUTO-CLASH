class_name WorldHud
extends CanvasLayer
## Open world HUD: identity + grade + XP, current zone, health / chakra
## chakra, technique slots with radial cooldowns and the reason a technique
## can't be cast, toasts and announcements.

const SLOT_SIZE: float = 64.0
## Physical keys of the slots (labels follow the keyboard layout).
const SLOT_KEYS: Dictionary = {
	&"space": KEY_SHIFT, &"q": KEY_Q, &"j1": KEY_1, &"j2": KEY_2, &"j3": KEY_3, &"j4": KEY_4, &"j5": KEY_5, &"j6": KEY_6,
}
## Bar order: basic attack, dash, substitution, then the six techniques.
const BAR: Array[StringName] = [&"lmb", &"space", &"q", &"j1", &"j2", &"j3", &"j4", &"j5", &"j6"]
const REASON_COLORS: Dictionary = {"CHAKRA": Color(0.45, 0.7, 1.0), "BLOQUÉ": Color(1.0, 0.5, 0.4), "ACTIVE": Color(1.0, 0.85, 0.4)}

var _world: World
var _player: CombatCharacter
var _root: Control
var _name: Label
var _grade: Label
var _xp_bar: ProgressBar
var _xp_text: Label
var _zone: Label
var _hp: HealthBar
var _hp_text: Label
var _energy: ProgressBar
var _energy_text: Label
var _concentrate: Label
var _slots_row: HBoxContainer
var _slots: Dictionary = {}
var _toast: Label
var _announce: Label
var _death: Label
var _zone_name: String = ""


func bind(world: World, player: CombatCharacter) -> void:
	_world = world
	_player = player
	_build()
	rebuild_slots()


func _process(_delta: float) -> void:
	if _player == null:
		return
	var p: CharacterProfile = Profiles.profile
	if p != null:
		_name.text = p.character_name
		_grade.text = ShinobiScreen.GRADE_NAMES[p.grade].to_upper()
		var grade: GradeData = Profiles.db.get_grade(p.grade)
		var needed: int = grade.xp_to_next if grade != null else 0
		_xp_bar.max_value = maxi(needed, 1)
		_xp_bar.value = p.xp if needed > 0 else 1
		_xp_text.text = "XP %d / %d" % [p.xp, needed] if needed > 0 else "Grade maximal"
	var zone: String = _world.zone_name(_player.global_position)
	if zone != _zone_name:
		_zone_name = zone
		_zone.text = zone
		_zone.modulate.a = 1.0
	var health: HealthComponent = _player.health
	_hp.set_values(health.current_health, health.max_health, health.recoverable_health, health.shield)
	_hp_text.text = "%d / %d" % [ceili(health.current_health), roundi(health.max_health)]
	var energy: EnergyComponent = _player.energy
	_energy.max_value = energy.max_energy
	_energy.value = energy.current_energy
	_energy_text.text = "CHAKRA %d / %d" % [floori(energy.current_energy), roundi(energy.max_energy)]
	_concentrate.visible = _player.concentrating
	for slot: StringName in _slots:
		var w: Dictionary = _slots[slot]
		var a: AbilityData = _player.abilities.get_ability(slot)
		var cd: float = _player.abilities.get_cooldown_left(slot)
		(w.sweep as CooldownSweep).ratio = clampf(cd / maxf(a.cooldown, 0.01), 0.0, 1.0) if cd > 0.0 else 0.0
		(w.cd as Label).text = ("%.1f" % cd) if cd > 0.0 else ""
		var reason: String = _player.abilities.unavailable_reason(slot)
		if reason == "RECHARGE":
			reason = ""  # the sweep already shows it
		if slot == &"q" and _player.substitution_armed:
			reason = "ACTIVE"
		var reason_label: Label = w.reason
		reason_label.text = reason
		reason_label.add_theme_color_override("font_color", REASON_COLORS.get(reason, Color.WHITE))
		(w.box as Control).modulate = Color(0.55, 0.65, 1.0) if reason == "CHAKRA" else (Color(0.7, 0.7, 0.7) if reason == "BLOQUÉ" else Color.WHITE)
	var respawn: float = _world.respawn_left()
	_death.visible = respawn > 0.0
	_death.text = "K.O.\nRetour au village dans %d" % ceili(respawn)


func rebuild_slots() -> void:
	for child: Node in _slots_row.get_children():
		child.queue_free()
	_slots.clear()
	for slot: StringName in BAR:
		var a: AbilityData = _player.abilities.get_ability(slot)
		_slots[slot] = _slot(slot, a) if a != null else _empty_slot(slot)
	for slot: StringName in _slots.keys():
		if _player.abilities.get_ability(slot) == null:
			_slots.erase(slot)


func toast(text: String, color: Color = Color.WHITE) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", color)
	_toast.modulate.a = 1.0
	var tween := _toast.create_tween()
	tween.tween_interval(2.5)
	tween.tween_property(_toast, "modulate:a", 0.0, 0.6)


func announce(text: String) -> void:
	_announce.text = text
	_announce.modulate.a = 1.0
	_announce.pivot_offset = _announce.size / 2.0
	_announce.scale = Vector2(1.5, 0.5)
	var tween := _announce.create_tween()
	tween.tween_property(_announce, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(2.0)
	tween.tween_property(_announce, "modulate:a", 0.0, 0.6)
	Sfx.play(&"gong", Vector3.INF, -4.0)


# --- Build --------------------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiStyle.theme()
	add_child(_root)
	# Identity / grade / XP.
	var id_panel := PanelContainer.new()
	id_panel.position = Vector2(18, 16)
	id_panel.custom_minimum_size = Vector2(340, 0)
	id_panel.add_theme_stylebox_override("panel", UiStyle.panel(Color(0.05, 0.04, 0.08, 0.86), 12, Color(UiStyle.ACCENT, 0.5), 12))
	id_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(id_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	id_panel.add_child(col)
	var row := HBoxContainer.new()
	col.add_child(row)
	_name = UiStyle.label(row, "", 20, Color.WHITE, 900)
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grade = UiStyle.label(row, "", 16, UiStyle.ACCENT, 900)
	_xp_bar = UiStyle.bar(col, Color(0.55, 0.8, 1.0), 10, 4)
	_xp_text = UiStyle.label(col, "", 12, Color(0.75, 0.88, 1.0), 800)
	# Zone name.
	_zone = UiStyle.label(_root, "", 22, Color(1.0, 0.92, 0.75), 900)
	_zone.add_theme_constant_override("outline_size", 8)
	_zone.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_zone.offset_left = -400
	_zone.offset_right = 400
	_zone.offset_top = 18
	_zone.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Bottom frame: health, energy, slots.
	var frame := PanelContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	frame.grow_horizontal = Control.GROW_DIRECTION_BOTH
	frame.grow_vertical = Control.GROW_DIRECTION_BEGIN
	frame.offset_bottom = -16
	frame.add_theme_stylebox_override("panel", UiStyle.panel(Color(0.05, 0.04, 0.08, 0.9), 14, Color(UiStyle.ACCENT, 0.35), 14))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(frame)
	var fcol := VBoxContainer.new()
	fcol.add_theme_constant_override("separation", 6)
	frame.add_child(fcol)
	var hp_stack := Control.new()
	hp_stack.custom_minimum_size = Vector2(0, 22)
	fcol.add_child(hp_stack)
	_hp = HealthBar.new()
	_hp.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hp_stack.add_child(_hp)
	_hp_text = UiStyle.label(hp_stack, "", 14, Color.WHITE, 900)
	_hp_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var chakra_stack := Control.new()
	chakra_stack.custom_minimum_size = Vector2(0, 14)
	fcol.add_child(chakra_stack)
	_energy = UiStyle.bar(chakra_stack, UiStyle.CHAKRA, 14, 4)
	_energy.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_energy_text = UiStyle.label(chakra_stack, "", 11, Color.WHITE, 900)
	_energy_text.add_theme_constant_override("outline_size", 4)
	_energy_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_energy_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_energy_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_slots_row = HBoxContainer.new()
	_slots_row.add_theme_constant_override("separation", 8)
	fcol.add_child(_slots_row)
	_concentrate = UiStyle.label(_root, "CONCENTRATION", 18, UiStyle.CHAKRA, 900)
	_concentrate.add_theme_constant_override("outline_size", 8)
	_concentrate.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_concentrate.offset_left = -300
	_concentrate.offset_right = 300
	_concentrate.offset_top = -190
	_concentrate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_concentrate.visible = false
	var hint_text: String = "B : techniques  ·  Espace : saut  ·  %s (maintenir) : concentration  ·  F : garde  ·  Échap : menu SHINOBI  ·  O : options" % key_label(KEY_R)
	var hint := UiStyle.label(_root, hint_text, 13, UiStyle.MUTED, 700)
	hint.position = Vector2(20, 104)
	_toast = UiStyle.label(_root, "", 20, Color.WHITE, 900)
	_toast.add_theme_constant_override("outline_size", 8)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_toast.offset_left = -500
	_toast.offset_right = 500
	_toast.offset_top = 120
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_announce = UiStyle.label(_root, "", 56, UiStyle.ACCENT, 900)
	_announce.add_theme_constant_override("outline_size", 14)
	_announce.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_announce.offset_left = -600
	_announce.offset_right = 600
	_announce.offset_top = -200
	_announce.offset_bottom = -120
	_announce.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_announce.modulate.a = 0.0
	_death = UiStyle.label(_root, "", 44, Color(1.0, 0.35, 0.3), 900)
	_death.add_theme_constant_override("outline_size", 12)
	_death.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_death.offset_left = -500
	_death.offset_right = 500
	_death.offset_top = -60
	_death.offset_bottom = 60
	_death.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death.visible = false


func _slot(slot: StringName, a: AbilityData) -> Dictionary:
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(SLOT_SIZE * 1.6, SLOT_SIZE)
	var style := UiStyle.panel(Color(a.color.darkened(0.75), 0.95), 10, Color(a.color, 0.7), 6)
	box.add_theme_stylebox_override("panel", style)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slots_row.add_child(box)
	var stack := Control.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(stack)
	var name_label := UiStyle.label(stack, a.display_name, 12, Color.WHITE, 800)
	name_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var sweep := CooldownSweep.new()
	sweep.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_child(sweep)
	var cd := UiStyle.label(stack, "", 22, Color.WHITE, 900)
	cd.add_theme_constant_override("outline_size", 6)
	cd.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cd.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var key := UiStyle.label(stack, _slot_key(slot), 10, UiStyle.ACCENT, 900)
	key.position = Vector2(0, -4)
	if a.energy_cost > 0.0:
		var cost := UiStyle.label(stack, str(roundi(a.energy_cost)), 10, UiStyle.CHAKRA, 900)
		cost.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		cost.offset_left = -24
		cost.offset_top = -4
		cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var reason := UiStyle.label(stack, "", 10, Color.WHITE, 900)
	reason.add_theme_constant_override("outline_size", 4)
	reason.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	reason.offset_top = -12
	reason.offset_bottom = 2
	reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return {"sweep": sweep, "cd": cd, "reason": reason, "box": box}


func _empty_slot(slot: StringName) -> Dictionary:
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(SLOT_SIZE * 1.6, SLOT_SIZE)
	box.add_theme_stylebox_override("panel", UiStyle.panel(Color(0.08, 0.08, 0.1, 0.8), 10, Color(1, 1, 1, 0.12), 6))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slots_row.add_child(box)
	var l := UiStyle.label(box, "%s\nlibre" % _slot_key(slot), 11, UiStyle.MUTED, 700)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return {}


func _slot_key(slot: StringName) -> String:
	return "CLIC G" if slot == &"lmb" else key_label(SLOT_KEYS[slot])


## Label of a physical key on the player's keyboard layout (Q -> A on AZERTY).
static func key_label(physical: Key) -> String:
	if physical == KEY_SHIFT:
		return "MAJ"
	var k: Key = KEY_NONE
	if DisplayServer.get_name() != "headless":
		k = DisplayServer.keyboard_get_label_from_physical(physical)
	return OS.get_keycode_string(k if k != KEY_NONE else physical).to_upper()
