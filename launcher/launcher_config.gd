## Where the launcher looks for updates. CI replaces the placeholder with the
## VPS address; a `launcher.cfg` next to the exe can override it:
##   [launcher]
##   base_url="http://1.2.3.4/naruto-clash/"

const DEFAULT_BASE_URL: String = "__BASE_URL__"
const GAME_EXE: String = "NarutoClash.exe"
## base64("user:password") for the password-protected site; CI fills it in.
const AUTH: String = "__AUTH__"


static func headers() -> PackedStringArray:
	if AUTH == "" or AUTH.begins_with("__"):
		return PackedStringArray()
	return PackedStringArray(["Authorization: Basic " + AUTH])


static func base_url() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(install_dir().path_join("launcher.cfg")) == OK:
		return str(cfg.get_value("launcher", "base_url", DEFAULT_BASE_URL))
	return DEFAULT_BASE_URL


## Portable install: everything lives next to the launcher exe.
static func install_dir() -> String:
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path("user://")
	return OS.get_executable_path().get_base_dir()


static func game_dir() -> String:
	return install_dir().path_join("game")
