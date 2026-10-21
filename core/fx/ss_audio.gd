class_name SSAudio
## Shinobi Striker sounds and music (_ss_local/sfx, _ss_local/music), exported from SD_Default.bnk
## by _ss_local/export_audio.ps1 (catalog.json lists them). Sfx plays these in place of its
## synthesised sounds when they exist; techniques get the sounds of their SS jutsu (same SS name as
## their SSIcons icon); music and ambience loop on their own players. Presentation only.

const SFX_DIR := "res://_ss_local/sfx/"
const MUSIC_DIR := "res://_ss_local/music/"
const MUSIC_DB: float = -13.0
const AMBIENCE_DB: float = -16.0
const FADE: float = 1.2
## The same technique sound is not replayed within this many seconds (multi-hit jutsu).
const TECH_REPEAT: float = 0.12

## Ground under the player's feet, for footsteps: dirt, grass, wood, rock, sand, water.
static var surface: StringName = &"dirt"

static var _catalog: Dictionary = {}
static var _loaded: bool = false
static var _streams: Dictionary = {}
static var _last_tech: Dictionary = {}
static var _rng := RandomNumberGenerator.new()
static var _music: AudioStreamPlayer
static var _music_key: StringName = &""
static var _ambience: AudioStreamPlayer
static var _ambience_key: StringName = &""


static func available() -> bool:
	return not _cat().is_empty()


static func _cat() -> Dictionary:
	if not _loaded:
		_loaded = true
		var path := SFX_DIR + "catalog.json"
		if FileAccess.file_exists(path):
			var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if data is Dictionary:
				_catalog = data
	return _catalog


## A random SS variant of a sound event (swing, hit, dash, ui_ok...), or null.
static func event(id: StringName) -> AudioStream:
	var events: Dictionary = _cat().get("events", {})
	var files: Array = events.get(String(id), [])
	if files.is_empty():
		return null
	return _load(SFX_DIR + str(files[_rng.randi() % files.size()]))


static func has_event(id: StringName) -> bool:
	return _cat().get("events", {}).has(String(id))


## Sound of a technique's SS jutsu: slot "cast" or "impact" (null when SS has none).
static func tech(id: StringName, slot: String, display_name: String = "") -> AudioStream:
	var tech_map: Dictionary = _cat().get("tech", {})
	if tech_map.is_empty():
		return null
	var kit_icon: String = ""
	for kit: String in SSIcons.BY_KIT:
		if String(id).begins_with(kit + "_"):
			kit_icon = SSIcons.BY_KIT[kit]
			break
	# Each technique is an SS jutsu: its sounds are under its SS asset folder (or its icon name).
	var folder: String = str(SSIcons.asset(id).get("asset", ""))
	var icon: String = SSIcons.icon_name(id)
	if icon == "":
		icon = kit_icon if display_name == "" else SSIcons._by_name(display_name)
	var entry: Dictionary = tech_map.get(folder, tech_map.get(icon, {}))
	# The jutsu's own SS sound, else its element's (kit icon), else the impact for a cast.
	var files: Array = entry.get(slot, [])
	if files.is_empty():
		files = tech_map.get(kit_icon, {}).get(slot, [])
	if files.is_empty():
		files = ELEMENT_FALLBACK.get(slot, {}).get(SSVfxProfiles.element_of(id), [])
		files = tech_map.get(files[0], {}).get(slot, []) if not files.is_empty() else []
	if files.is_empty() and slot == "cast":
		files = entry.get("impact", [])
	if files.is_empty():
		# Last resort: a generic SS hit (blades, threads, puppets) or blast.
		var physical: bool = SSVfxProfiles.element_of(id) in [&"steel", &"sword", &"puppet", &"spider", &"paper"]
		return event(&"kunai_hit" if physical else &"boom") if slot == "impact" else null
	return _load(SFX_DIR + str(files[_rng.randi() % files.size()]))


## SS jutsu used for an element when the technique's own SS sound folder has none.
const ELEMENT_FALLBACK: Dictionary = {
	"impact": {&"fire": ["FireBall"], &"water": ["WaterDragon"], &"lightning": ["Chidori"], &"earth": ["EarthDragonBomb"],
		&"wind": ["AirPalm"], &"fan": ["AirPalm"], &"ice": ["D27NJ1"], &"bone": ["D94NJ1"], &"coral": ["D94NJ1"], &"uchiha": ["FireBall"], &"susanoo": ["FireBall"], &"blood": ["D94NJ1"], &"sand": ["SandShowerBarrage"], &"seal": ["BarrierMethod"], &"shadow": ["ShadowPossession"],
		&"titan": ["SpikyHumanBoulder"], &"wood": ["WoodenDragon"], &"steel": ["D33NJ2_2"], &"chakra": ["Rasengan"]},
	"cast": {},
}


## Plays a technique sound through Sfx (spatial fade, volume), skipping rapid repeats.
static func play_tech(id: StringName, slot: String, at: Vector3, gain_db: float = 0.0, display_name: String = "") -> bool:
	var key := "%s/%s" % [id, slot]
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - float(_last_tech.get(key, -10.0)) < TECH_REPEAT:
		return true
	var stream := tech(id, slot, display_name)
	if stream == null:
		return false
	_last_tech[key] = now
	Sfx.play_stream(stream, at, gain_db + Sfx.SS_GAIN_DB)
	return true


## Footstep for the current surface.
static func step(at: Vector3, gain_db: float) -> void:
	var id := StringName("step_" + String(surface))
	if not has_event(id):
		id = &"step_dirt"
	Sfx.play(id, at, gain_db)


# --- Music and ambience ---------------------------------------------------------------

## Loops a music track (title, village, forest, battle, battle_climax, boss, win, lose...);
## &"" fades the music out.
static func music(key: StringName) -> void:
	if key == _music_key:
		return
	_music_key = key
	_music = _crossfade(_music, _music_stream(key), MUSIC_DB, &"Music")


## Loops an ambience bed (amb_village, amb_forest...); &"" fades it out.
static func ambience(key: StringName) -> void:
	if key == _ambience_key:
		return
	_ambience_key = key
	var stream: AudioStream = event(key) if key != &"" else null
	_ambience = _crossfade(_ambience, _looped(stream), AMBIENCE_DB, &"SFX")


static func _music_stream(key: StringName) -> AudioStream:
	if key == &"":
		return null
	var file: String = _cat().get("music", {}).get(String(key), "")
	return _looped(_load(MUSIC_DIR + file)) if file != "" else null


static func _looped(stream: AudioStream) -> AudioStream:
	var wav := stream as AudioStreamWAV
	if wav != null and wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
	return stream


static func _crossfade(old: AudioStreamPlayer, stream: AudioStream, volume: float, bus: StringName) -> AudioStreamPlayer:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or DisplayServer.get_name() == "headless":
		return old
	if old != null and is_instance_valid(old):
		var out := old.create_tween()
		out.tween_property(old, "volume_db", -60.0, FADE)
		out.tween_callback(old.queue_free)
	if stream == null:
		return null
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = bus if AudioServer.get_bus_index(bus) >= 0 else &"Master"
	p.volume_db = -60.0
	p.autoplay = true
	# Deferred: music often starts from a scene's _ready, while the root is still adding children.
	tree.root.add_child.call_deferred(p)
	p.ready.connect(func() -> void: p.create_tween().tween_property(p, "volume_db", volume, FADE), CONNECT_ONE_SHOT)
	return p


static func _load(path: String) -> AudioStream:
	if _streams.has(path):
		return _streams[path]
	var s: AudioStream = load(path) if ResourceLoader.exists(path) else null
	_streams[path] = s
	return s
