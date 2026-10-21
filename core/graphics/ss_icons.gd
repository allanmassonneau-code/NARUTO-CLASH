class_name SSIcons
## Shinobi Striker skill icons (T_UI_Skill_* / T_UI_SP_* , _ss_local/icons) for every technique.
## Each technique is a real SS jutsu: its icon comes from data/progression/ss_kit_assets.json
## (written by tools/ss_kits.ps1). Universal actions fall back on a name keyword. Visual only.

const DIR := "res://_ss_local/icons/"
const ASSETS := "res://data/progression/ss_kit_assets.json"

static var _assets: Dictionary = {}


## SS data of a technique (ss_id, icon, asset folder, type, category), or {}.
static func asset(id: StringName) -> Dictionary:
	if _assets.is_empty() and FileAccess.file_exists(ASSETS):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(ASSETS))
		if data is Dictionary:
			_assets = data
	return _assets.get(String(id), {})


## Short SS icon name of a technique ("" when unknown).
static func icon_name(id: StringName) -> String:
	return str(asset(id).get("icon", ""))

## Fallback per kit (id prefix) when a technique is not listed above.
const BY_KIT: Dictionary = {
	"katon": "FireBall", "suiton": "WaterDragon", "raiton": "Chidori", "doton": "MudWall",
	"futon": "AirPalm", "clan_senju": "WoodenDragon", "clan_uchiha": "Sharingan",
	"clan_uzumaki": "BarrierMethod", "clan_nara": "ShadowPossession", "clan_akimichi": "D83NJ3_1",
	"clan_roran": "D52NJ2", "clan_sabaku": "SandShield", "clan_hoki": "PoisonExtraction",
	"clan_kugutsu": "D73NJ1_2", "clan_hakumei": "D62NJ1", "clan_chinoike": "D92NJ1_3",
	"clan_fuma": "D33NJ2_2", "clan_salamandre": "SummonSalamandar", "clan_kaguya": "D94NJ1",
	"clan_kami": "ShikigamiDanceShield", "clan_hozuki": "D71NJ2", "clan_hoshigaki": "SharkBomb",
	"clan_yuki": "D27NJ1", "clan_karatachi": "SUMNJ12", "clan_epeistes": "D32NJ2", "sub": "Rasengan",
}

## Universal actions and roster abilities, by display name keyword.
const BY_NAME: Dictionary = {
	"taijutsu": "LeafFlashHeelDropKick", "dash": "Teleportation", "shunshin": "Teleportation",
	"substitution": "TransportTech", "rasengan": "Rasengan", "chidori": "Chidori",
	"ombre": "ShadowPossession", "shadow": "ShadowPossession", "boule de feu": "FireBall",
	"fireball": "FireBall", "amaterasu": "Amaterasu", "susanoo": "D44NJ2", "sharingan": "Sharingan",
	"tsukuyomi": "D31NJ2", "lotus": "LeafHurricane", "tourbillon": "LeafHurricane",
	"porte": "SevenHeavens", "gate": "SevenHeavens", "soin": "Healing", "heal": "Healing",
	"poing": "D42NJ2_2", "punch": "D42NJ2_2", "cerisier": "CherryBlossomClash",
	"clone": "D41NJ1", "kunai": "D42NJ2_1", "shuriken": "D33NJ2_2", "eclair": "LightningStrike",
	"foudre": "LightningStrike", "corbeau": "D73NJ1_1", "crow": "D73NJ1_1",
}

static var _cache: Dictionary = {}


static func available() -> bool:
	return ResourceLoader.exists(DIR + "Rasengan.png")


## SS icon for a technique id (and optional display name), or null.
static func for_technique(id: StringName, display_name: String = "") -> Texture2D:
	var file: String = icon_name(id)
	if file == "" and id != &"":
		var s := String(id)
		for kit: String in BY_KIT:
			if s.begins_with(kit + "_"):
				file = BY_KIT[kit]
				break
	if file == "" and display_name != "":
		file = _by_name(display_name)
	return _load(file)


static func _by_name(display_name: String) -> String:
	var n := display_name.to_lower()
	for key: String in BY_NAME:
		if n.contains(key):
			return BY_NAME[key]
	return ""


## Icon for an ability: its technique id first, then its name; keeps the
## ability's own icon when SS has nothing for it.
static func for_ability(a: AbilityData) -> Texture2D:
	if a == null:
		return null
	var t := for_technique(a.source_id, a.display_name)
	return t if t != null else a.icon


## Adds a square SS icon for a technique to a UI container (nothing without one).
static func add_rect(parent: Control, id: StringName, display_name: String, size: float) -> TextureRect:
	var tex := for_technique(id, display_name)
	if tex == null:
		return null
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(size, size)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


static func _load(file: String) -> Texture2D:
	if file == "":
		return null
	if _cache.has(file):
		return _cache[file]
	var path := DIR + file + ".png"
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_cache[file] = tex
	return tex
