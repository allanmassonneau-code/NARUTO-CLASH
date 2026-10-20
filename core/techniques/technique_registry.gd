class_name TechniqueRegistry
## Maps technique ids (JutsuData.id) to their scripts, and kit ids (nature
## / clan) to their signature mechanic. Kit files are listed in
## content/techniques/technique_index.gd and expose:
##   const TECHNIQUES := {&"katon_d_braise_tracante": BraiseTracante, ...}
##   const SIGNATURE = KatonSignature   (optional, a KitSignature subclass)
##   const KIT_ID := &"katon"

static var _techniques: Dictionary = {}
static var _signatures: Dictionary = {}
static var _loaded: bool = false


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	for script: GDScript in TechniqueIndex.KITS:
		var consts: Dictionary = script.get_script_constant_map()
		var techniques: Dictionary = consts.get("TECHNIQUES", {})
		for id: Variant in techniques:
			_techniques[StringName(id)] = techniques[id]
		if consts.get("SIGNATURE") != null and consts.has("KIT_ID"):
			_signatures[StringName(consts.KIT_ID)] = consts.SIGNATURE


static func has(id: StringName) -> bool:
	_load()
	return _techniques.has(id)


static func create(jutsu: JutsuData) -> Technique:
	_load()
	var script: Variant = _techniques.get(jutsu.id)
	if script == null:
		return null
	var t: Technique = script.new()
	t.id = jutsu.id
	t.jutsu = jutsu
	return t


static func signature(kit_id: StringName) -> KitSignature:
	_load()
	var script: Variant = _signatures.get(kit_id)
	if script == null:
		return null
	var s: KitSignature = script.new()
	s.kit_id = kit_id
	return s


static func scripted_ids() -> Array[StringName]:
	_load()
	var out: Array[StringName] = []
	for id: StringName in _techniques:
		out.append(id)
	return out
