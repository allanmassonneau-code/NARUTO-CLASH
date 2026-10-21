class_name KitState
extends Node
## Per-fighter state of the technique kits (design bible): named resources
## (Vigueur, Charges, Glyphes...), named marks carried by this fighter
## (Braise, Humidité...), recast windows, temporary modifiers (buffs,
## debuffs, modes) and scheduled callbacks. Everything is named and
## inspectable so the HUD can show it.

signal changed

var character: CombatCharacter
## name -> {"value", "max", "label", "color", "decay", "idle"}
var resources: Dictionary = {}
## name -> {"stacks", "max", "left", "source", "label", "color"}
var marks: Dictionary = {}
## technique id -> {"left", "callable"}
var recasts: Dictionary = {}
## id -> {"left", "props"}; props keys: see modifier_mult / has_flag / callbacks.
var modifiers: Dictionary = {}
## KitSignature instances (nature / clan signature mechanics) of this fighter.
var signatures: Array = []
var _timers: Array[Dictionary] = []


func _init(owner_character: CombatCharacter = null) -> void:
	character = owner_character
	name = "KitState"


func reset() -> void:
	for key: String in resources:
		resources[key].value = 0.0
	marks.clear()
	recasts.clear()
	modifiers.clear()
	_timers.clear()
	changed.emit()


func tick(delta: float) -> void:
	for key: String in resources:
		var r: Dictionary = resources[key]
		r.idle += delta
		if r.decay > 0.0 and r.idle >= r.decay and r.value > 0.0:
			r.value = 0.0
			changed.emit()
	for key: String in marks.keys():
		marks[key].left -= delta
		if marks[key].left <= 0.0:
			marks.erase(key)
			changed.emit()
	for key: StringName in recasts.keys():
		recasts[key].left -= delta
		if recasts[key].left <= 0.0:
			var expire: Callable = recasts[key].get("on_expire", Callable())
			recasts.erase(key)
			if expire.is_valid():
				expire.call()
	for key: String in modifiers.keys():
		var m: Dictionary = modifiers[key]
		m.left -= delta
		var tick_cb: Callable = m.props.get("on_tick", Callable())
		if tick_cb.is_valid():
			tick_cb.call(delta)
		if m.left <= 0.0 and modifiers.has(key):
			_end_modifier(key)
	var due: Array[Dictionary] = []
	for t: Dictionary in _timers:
		t.left -= delta
		if t.left <= 0.0:
			due.append(t)
	for t: Dictionary in due:
		_timers.erase(t)
		if (t.callable as Callable).is_valid():
			t.callable.call()
	for sig: Object in signatures:
		if sig.has_method("tick"):
			sig.tick(character, delta)


# --- Resources ----------------------------------------------------------------------

## Declares a resource shown on the HUD. `decay`: seconds without gain or
## spend after which it falls back to 0 (out of combat), 0 = never.
func define_resource(key: String, maximum: float, label: String, color: Color, decay: float = 0.0) -> void:
	if resources.has(key):
		resources[key].max = maximum
		return
	resources[key] = {"value": 0.0, "max": maximum, "label": label, "color": color, "decay": decay, "idle": 0.0}
	changed.emit()


func res(key: String) -> float:
	return resources[key].value if resources.has(key) else 0.0


func res_max(key: String) -> float:
	return resources[key].max if resources.has(key) else 0.0


func add_res(key: String, amount: float) -> float:
	if not resources.has(key):
		return 0.0
	var r: Dictionary = resources[key]
	r.value = clampf(r.value + amount, 0.0, r.max)
	r.idle = 0.0
	changed.emit()
	return r.value


func spend_res(key: String, amount: float) -> bool:
	if res(key) < amount - 0.001:
		return false
	add_res(key, -amount)
	return true


## Consumes the whole resource; returns how much there was.
func take_all_res(key: String) -> float:
	var v: float = res(key)
	if v > 0.0:
		add_res(key, -v)
	return v


# --- Marks (carried by this fighter) ------------------------------------------------

func add_mark(key: String, stacks: int, duration: float, max_stacks: int, source: CombatCharacter,
		label: String = "", color: Color = Color.WHITE) -> int:
	var m: Dictionary = marks.get(key, {"stacks": 0, "max": max_stacks, "label": label if label != "" else key.capitalize(), "color": color})
	m.stacks = mini(m.stacks + stacks, max_stacks)
	m.max = max_stacks
	m.left = maxf(m.get("left", 0.0), duration)
	m.source = source
	marks[key] = m
	changed.emit()
	return m.stacks


func mark(key: String) -> int:
	return marks[key].stacks if marks.has(key) else 0


func mark_source(key: String) -> CombatCharacter:
	return marks[key].source if marks.has(key) and is_instance_valid(marks[key].source) else null


## Removes the mark; returns its stacks.
func consume_mark(key: String) -> int:
	var n: int = mark(key)
	if marks.erase(key):
		changed.emit()
	return n


# --- Recast -------------------------------------------------------------------------

## Opens a window during which pressing the technique again calls `callable`
## instead of casting it (no cost, no cooldown).
func open_recast(id: StringName, seconds: float, callable: Callable, on_expire: Callable = Callable()) -> void:
	recasts[id] = {"left": seconds, "callable": callable, "on_expire": on_expire}
	changed.emit()


func has_recast(id: StringName) -> bool:
	return recasts.has(id)


func fire_recast(id: StringName) -> bool:
	if not recasts.has(id):
		return false
	var cb: Callable = recasts[id].callable
	recasts.erase(id)
	changed.emit()
	if cb.is_valid():
		cb.call()
	return true


func close_recast(id: StringName) -> void:
	if recasts.erase(id):
		changed.emit()


func recast_left(id: StringName) -> float:
	return recasts[id].left if recasts.has(id) else 0.0


# --- Modifiers ----------------------------------------------------------------------

## Temporary modifier (replaces one with the same id). Props:
##   damage_dealt, damage_taken, heal_taken, speed, basic_damage, chakra_regen, lifesteal: multipliers / fractions
##   tenacity (forced movement x0.25, no launch), cc_immune, untargetable, silence_self: flags
##   uses: int (removed after that many on_deal calls)
##   on_deal(target, hit, damage) / on_take(hit, damage) -> optional float new damage
##   on_tick(delta), on_end(): callbacks
##   label, color: HUD
func add_modifier(id: String, seconds: float, props: Dictionary = {}) -> void:
	modifiers[id] = {"left": seconds, "props": props}
	changed.emit()


func has_modifier(id: String) -> bool:
	return modifiers.has(id)


func modifier_left(id: String) -> float:
	return modifiers[id].left if modifiers.has(id) else 0.0


func remove_modifier(id: String) -> void:
	if modifiers.has(id):
		_end_modifier(id)


func _end_modifier(id: String) -> void:
	var m: Dictionary = modifiers[id]
	modifiers.erase(id)
	var end_cb: Callable = m.props.get("on_end", Callable())
	if end_cb.is_valid():
		end_cb.call()
	changed.emit()


func modifier_mult(key: String) -> float:
	var m: float = 1.0
	for id: String in modifiers:
		m *= float(modifiers[id].props.get(key, 1.0))
	return m


func modifier_sum(key: String) -> float:
	var s: float = 0.0
	for id: String in modifiers:
		s += float(modifiers[id].props.get(key, 0.0))
	return s


func has_flag(key: String) -> bool:
	for id: String in modifiers:
		if modifiers[id].props.get(key, false):
			return true
	return false


## The fighter dealt `damage` with `hit` to `target`: modifier callbacks and
## signatures. Returns the (possibly changed) damage.
func on_deal(target: CombatCharacter, hit: HitData, damage: float) -> float:
	for id: String in modifiers.keys():
		if not modifiers.has(id):
			continue
		var props: Dictionary = modifiers[id].props
		var cb: Callable = props.get("on_deal", Callable())
		if cb.is_valid():
			var r: Variant = cb.call(target, hit, damage)
			if r is float:
				damage = r
			if props.has("uses"):
				props.uses -= 1
				if props.uses <= 0 and modifiers.has(id):
					_end_modifier(id)
	for sig: Object in signatures:
		if sig.has_method("on_deal"):
			var r2: Variant = sig.on_deal(character, target, hit, damage)
			if r2 is float:
				damage = r2
	return damage


## The fighter is about to take `damage` from `hit`. Returns the damage.
func on_take(hit: HitData, damage: float) -> float:
	for id: String in modifiers.keys():
		if not modifiers.has(id):
			continue
		var cb: Callable = modifiers[id].props.get("on_take", Callable())
		if cb.is_valid():
			var r: Variant = cb.call(hit, damage)
			if r is float:
				damage = r
	for sig: Object in signatures:
		if sig.has_method("on_take"):
			var r2: Variant = sig.on_take(character, hit, damage)
			if r2 is float:
				damage = r2
	return damage


# --- Timers -------------------------------------------------------------------------

func after(seconds: float, callable: Callable) -> void:
	_timers.append({"left": seconds, "callable": callable})


## HUD lines: resources then active modifiers with a label.
func hud_lines() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for key: String in resources:
		var r: Dictionary = resources[key]
		out.append({"text": "%s %d/%d" % [r.label, roundi(r.value), roundi(r.max)], "color": r.color})
	for id: String in modifiers:
		var props: Dictionary = modifiers[id].props
		if props.has("label"):
			out.append({"text": "%s %.0fs" % [props.label, ceilf(modifiers[id].left)], "color": props.get("color", Color.WHITE)})
	for id: StringName in recasts:
		out.append({"text": "Recast %.1fs" % recasts[id].left, "color": Color(1.0, 0.85, 0.4)})
	return out
