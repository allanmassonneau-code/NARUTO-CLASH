class_name SSEnvPresets
## Lighting / atmosphere presets taken from Shinobi Striker map data
## (LM_KonohaVillage_BORUTO_Environments_Light / _Postprocess, LUT_* colour grading):
## - sun: SUN_0 colour (246, 250, 251), rotation (-54.5, -43.5), the only shadowed light;
## - ambient: PostProcess IndirectLightingColor (0.66, 0.90, 1.0), no AO, fixed exposure;
## - fog: ExponentialHeightFog inscattering colour (0.24, 0.39, 0.535 linear).
## Values are converted to the Godot toon pipeline (SSGraphics / ss_toon.gdshader).

const KONOHA_DAY: StringName = &"konoha_day"
const FOREST_DAY: StringName = &"forest_day"
const AME_RAIN: StringName = &"ame_rain"
const SUNA_DAY: StringName = &"suna_day"
const KIRI_MIST: StringName = &"kiri_mist"

const PRESETS: Dictionary = {
	&"konoha_day": {
		"lut": &"konoha_day",
		"sun_color": Color8(246, 250, 251), "sun_energy": 1.0, "sun_rotation": Vector3(-54.5, -43.5, 0),
		"ambient": Color(0.664739, 0.903031, 1.0), "ambient_energy": 0.32,
		"fog": Color(0.53, 0.66, 0.77), "fog_density": 0.0035, "fog_sun_scatter": 0.12,
		"zenith": Color(0.26, 0.52, 0.9), "horizon": Color(0.72, 0.84, 0.94), "cloud_coverage": 0.56,
		"saturation": 1.08, "contrast": 1.04,
	},
	&"forest_day": {
		"lut": &"forest_day",
		"sun_color": Color8(250, 248, 238), "sun_energy": 1.0, "sun_rotation": Vector3(-54.5, -43.5, 0),
		"ambient": Color(0.62, 0.86, 0.92), "ambient_energy": 0.34,
		"fog": Color(0.56, 0.7, 0.72), "fog_density": 0.004, "fog_sun_scatter": 0.1,
		"zenith": Color(0.3, 0.56, 0.88), "horizon": Color(0.74, 0.86, 0.9), "cloud_coverage": 0.52,
		"saturation": 1.1, "contrast": 1.04,
	},
	&"ame_rain": {
		"lut": &"ame_rain",
		"sun_color": Color(0.82, 0.86, 0.92), "sun_energy": 0.62, "sun_rotation": Vector3(-62.0, -30.0, 0),
		"ambient": Color(0.62, 0.7, 0.82), "ambient_energy": 0.42,
		"fog": Color(0.46, 0.5, 0.56), "fog_density": 0.009, "fog_sun_scatter": 0.0,
		"zenith": Color(0.36, 0.4, 0.46), "horizon": Color(0.55, 0.58, 0.63), "cloud_coverage": 0.3,
		"saturation": 0.92, "contrast": 1.02,
	},
	&"suna_day": {
		"lut": &"konoha_day",
		"sun_color": Color8(255, 244, 222), "sun_energy": 1.08, "sun_rotation": Vector3(-58.0, -40.0, 0),
		"ambient": Color(0.82, 0.86, 0.95), "ambient_energy": 0.3,
		"fog": Color(0.85, 0.76, 0.6), "fog_density": 0.004, "fog_sun_scatter": 0.18,
		"zenith": Color(0.32, 0.56, 0.86), "horizon": Color(0.9, 0.84, 0.72), "cloud_coverage": 0.7,
		"saturation": 1.05, "contrast": 1.05,
	},
	&"kiri_mist": {
		"lut": &"ame_rain",
		"sun_color": Color(0.9, 0.94, 0.98), "sun_energy": 0.78, "sun_rotation": Vector3(-50.0, -45.0, 0),
		"ambient": Color(0.68, 0.82, 0.9), "ambient_energy": 0.42,
		"fog": Color(0.7, 0.78, 0.82), "fog_density": 0.012, "fog_sun_scatter": 0.05,
		"zenith": Color(0.5, 0.62, 0.74), "horizon": Color(0.76, 0.83, 0.87), "cloud_coverage": 0.35,
		"saturation": 0.96, "contrast": 1.0,
	},
}


static func get_preset(id: StringName) -> Dictionary:
	return PRESETS.get(id, PRESETS[KONOHA_DAY])


## Preset for a village id used by the profile / world.
static func for_village(village: StringName) -> StringName:
	match village:
		&"ame":
			return AME_RAIN
		&"suna":
			return SUNA_DAY
		&"kiri":
			return KIRI_MIST
	return KONOHA_DAY
