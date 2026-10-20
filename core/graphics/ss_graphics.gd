class_name SSGraphics
## Shinobi Striker style rendering base: every character, prop, map, environment and
## camera gets its materials / lighting from here.
##
## Real SS assets are used locally only: textures extracted with the Shinobi Striker
## reference tools live in res://_SS_REFERENCE/extracted (git-ignored, never committed)
## and are loaded at runtime when present. Without them (fresh clone, exported build)
## every lookup falls back to procedural data, so the game always runs.

const SS_EXTRACTED: String = "res://_SS_REFERENCE/extracted/"
const TOON_SHADER: Shader = preload("res://core/graphics/shaders/ss_toon.gdshader")
const OUTLINE_SHADER: Shader = preload("res://core/graphics/shaders/ss_outline.gdshader")
const POST_OUTLINE_SHADER: Shader = preload("res://core/graphics/shaders/ss_post_outline.gdshader")
const SKY_SHADER: Shader = preload("res://core/graphics/shaders/ss_sky.gdshader")

## Surface id -> extracted SS texture (paths under SS_EXTRACTED).
const TEXTURES: Dictionary = {
	&"uc": "NarutoShading/textures/T_SHD_TypeD_UC.png",
	&"grass": "Environments/MapAssets/konohaVillage/Textures/T_ENV_KNVLLG_GrassBase_BC.png",
	&"forest_ground": "Environments/MapAssets/KonohaForest/Textures/T_ENV_KNFRST_Ground_01_BC.png",
	&"sand": "Environments/MapAssets/konohaVillage/Textures/T_ENV_KNVLLG_Ground_Sand_BC.png",
	&"slabs": "Environments/MapAssets/konohaVillage/Textures/T_ENV_KNVLLG_ConcreteSlabs_01_BC.png",
	&"plaster": "Environments/MapAssets/konohaVillage/Textures/T_ENV_KNVLLG_Plaster_BC.png",
	&"roof": "Environments/MapAssets/konohaVillage/Textures/T_ENV_KNVLLG_MetalRoof_BC.png",
	&"wood": "Environments/MapAssets/konohaVillage/Textures/T_ENV_KNVLLG_WoodBoard_BC.png",
	&"stone": "Environments/MapAssets/konohaVillage/Textures/T_ENV_KNVLLG_Stonewall_04_BC.png",
	&"leaf": "Environments/MapAssets/KonohaForest/Textures/T_ENV_KNFRST_Leaf_01_BC.png",
}
## World metres covered by one texture repeat.
const TEXTURE_TILE: Dictionary = {
	&"grass": 9.0, &"forest_ground": 7.0, &"sand": 6.0, &"slabs": 4.0, &"plaster": 3.0,
	&"roof": 2.5, &"wood": 2.2, &"stone": 3.5, &"leaf": 2.5,
}
const TEXTURE_DETAIL: Dictionary = {&"plaster": 0.8, &"slabs": 0.7, &"leaf": 0.8}
## SS colour-grading LUTs (UE 256x16 strips).
const LUTS: Dictionary = {
	&"konoha_day": "LUT/LUT_KNVLLG_Light_Day_01.png",
	&"forest_day": "LUT/LUT_KNFRST_Light_Day_01.png",
	&"ame_rain": "LUT/LUT_AMVLLG_Light_Rainy_01.png",
}

## Lit (BC) -> shadow (SC) colour pairs sampled on T_CHR_Naruto_BC / T_CHR_Naruto_SC.
const SS_SHADE_PAIRS: Array = [
	["474550", "2C2D31"], ["B2A5A5", "897D76"], ["EC9326", "CE6216"], ["AD4355", "912E4A"],
	["73594D", "503E3C"], ["3C3E58", "2C2B47"], ["CB5C03", "7B3203"], ["FCF7AD", "FCBE6B"],
	["FCFCFC", "CBD4E4"], ["554C4D", "2F2D2F"], ["EFEDE9", "848EAA"], ["EFD7AF", "DE9F6E"],
	["843D4D", "502329"], ["CE616E", "973B3F"], ["030303", "030303"],
]
## SS M_Line colour (40, 40, 40) pushed slightly warmer/darker for small primitives.
const OUTLINE_COLOR := Color(0.1, 0.08, 0.08)

static var _textures: Dictionary = {}
static var _means: Dictionary = {}
static var _luts: Dictionary = {}
static var _materials: Dictionary = {}
static var _uc: Texture2D
static var _outline: ShaderMaterial


# --- Colours -----------------------------------------------------------------------

## SS shadow colour for a lit colour: exact SS pair when the colour is an SS swatch,
## else the rule fitted on those pairs (warm hues slide toward red and saturate, neutrals
## cool toward blue-grey, dark/saturated colours lose more value).
static func shade_of(c: Color) -> Color:
	for pair: Array in SS_SHADE_PAIRS:
		var bc := Color(pair[0])
		if absf(bc.r - c.r) + absf(bc.g - c.g) + absf(bc.b - c.b) < 0.03:
			return Color(Color(pair[1]), c.a)
	var h: float = c.h
	var s: float = c.s
	var v: float = c.v
	if s < 0.12:
		return Color.from_hsv(0.6, 0.1 + 0.1 * v, v * (0.6 + 0.25 * v), c.a)
	var from_orange: float = wrapf(h - 0.08, -0.5, 0.5)
	var warm: float = clampf(1.0 - absf(from_orange) / 0.16, 0.0, 1.0)
	var cool: float = clampf(1.0 - absf(wrapf(h - 0.62, -0.5, 0.5)) / 0.2, 0.0, 1.0)
	var hue: float = fposmod(h - warm * (0.025 + 0.25 * maxf(0.0, from_orange)) + cool * 0.015, 1.0)
	var sat: float = clampf(s + 0.3 * (1.0 - s) * (0.4 + 0.6 * v), 0.0, 1.0)
	var val: float = v * clampf(0.55 + 0.35 * v + 0.1 * warm * v - 0.2 * s * s, 0.45, 1.0)
	return Color.from_hsv(hue, sat, val, c.a)


# --- Materials -----------------------------------------------------------------------

## Character part: object-space brush, SS rim, inverted-hull outline (M_Line).
## Tiny face details (eyes, brows, whiskers) skip the hull: it would swallow them.
static func character_material(color: Color, metal: bool = false, outlined: bool = true) -> ShaderMaterial:
	var key: String = "chr/%s/%s/%s" % [color.to_html(), metal, outlined]
	if _materials.has(key):
		return _materials[key]
	var m := _toon(color)
	m.set_shader_parameter("uc_scale", 1.6)
	m.set_shader_parameter("hatch_strength", 0.3)
	if metal:
		m.set_shader_parameter("shade_color", color.darkened(0.45))
		m.set_shader_parameter("rim_strength", 1.1)
		m.set_shader_parameter("rim_power", 3.0)
		m.set_shader_parameter("hatch_strength", 0.0)
	if outlined:
		m.next_pass = outline_material()
	_materials[key] = m
	return m


## Static prop / ground: world-space SS surface texture (see TEXTURES) + brush.
static func prop_material(color: Color, surface: StringName = &"", emission: float = 0.0) -> ShaderMaterial:
	var key: String = "prop/%s/%s/%s" % [color.to_html(), surface, emission]
	if _materials.has(key):
		return _materials[key]
	var m := _toon(color)
	m.set_shader_parameter("world_space", true)
	m.set_shader_parameter("uc_scale", 0.22)
	m.set_shader_parameter("hatch_strength", 0.2)
	m.set_shader_parameter("rim_strength", 0.0)
	_apply_surface(m, surface)
	if emission > 0.0:
		m.set_shader_parameter("emission_color", color)
		m.set_shader_parameter("emission_energy", emission)
	_materials[key] = m
	return m


## Grass / flowers (MultiMesh instance colours), shaded like the ground under them.
static func foliage_material(surface: StringName = &"") -> ShaderMaterial:
	var key: String = "foliage/%s" % surface
	if _materials.has(key):
		return _materials[key]
	var m := _toon(Color.WHITE)
	m.set_shader_parameter("shade_color", Color(0.62, 0.66, 0.72))
	m.set_shader_parameter("use_vertex_color", true)
	m.set_shader_parameter("up_normals", true)
	m.set_shader_parameter("world_space", true)
	m.set_shader_parameter("uc_scale", 0.22)
	m.set_shader_parameter("hatch_strength", 0.0)
	m.set_shader_parameter("rim_strength", 0.0)
	_apply_surface(m, surface)
	_materials[key] = m
	return m


static func outline_material() -> ShaderMaterial:
	if _outline == null:
		_outline = ShaderMaterial.new()
		_outline.shader = OUTLINE_SHADER
		_outline.set_shader_parameter("outline_color", OUTLINE_COLOR)
	return _outline


static func _toon(color: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TOON_SHADER
	m.set_shader_parameter("base_color", color)
	m.set_shader_parameter("shade_color", shade_of(color))
	m.set_shader_parameter("uc_texture", uc_texture())
	return m


static func _apply_surface(m: ShaderMaterial, surface: StringName) -> void:
	if surface == &"":
		return
	var tex: Texture2D = ss_texture(surface)
	if tex == null:
		return
	m.set_shader_parameter("use_albedo_texture", true)
	m.set_shader_parameter("albedo_texture", tex)
	var mean: Color = _means.get(surface, Color(0.5, 0.5, 0.5))
	m.set_shader_parameter("albedo_mean", Vector3(mean.r, mean.g, mean.b))
	m.set_shader_parameter("texture_scale", 1.0 / float(TEXTURE_TILE.get(surface, 4.0)))
	m.set_shader_parameter("texture_detail", float(TEXTURE_DETAIL.get(surface, 1.0)))


## Rough surface guess for scenes authored with plain colours (arena .tscn).
static func guess_surface(color: Color, mesh: Mesh) -> StringName:
	var flat: bool = mesh is PlaneMesh or (mesh is BoxMesh and (mesh as BoxMesh).size.y <= 1.0 and (mesh as BoxMesh).size.x > 8.0) \
		or (mesh is CylinderMesh and (mesh as CylinderMesh).height < 0.1)
	if color.g > color.r * 1.12 and color.g > color.b * 1.12:
		return &"leaf" if mesh is SphereMesh else &"grass"
	if color.s < 0.15:
		return &"slabs" if flat else (&"plaster" if color.v > 0.75 else &"stone")
	if color.r > color.g and color.g > color.b and color.h < 0.12:
		return &"sand" if flat else &"wood"
	return &""


## Converts the plain StandardMaterial3D of a hand-made scene to SS toon materials.
## Unshaded / transparent / emissive / textured materials (VFX, telegraphs, UI) are kept.
static func convert_tree(root: Node) -> void:
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		var override: Material = _convert(mi.material_override, mi.mesh)
		if override != null:
			mi.material_override = override
			continue
		if mi.material_override != null:
			continue
		for i in mi.mesh.get_surface_count():
			var src: Material = mi.get_surface_override_material(i)
			if src == null:
				src = mi.mesh.surface_get_material(i)
			var converted: Material = _convert(src, mi.mesh)
			if converted != null:
				mi.set_surface_override_material(i, converted)


static func _convert(src: Material, mesh: Mesh) -> Material:
	var std := src as StandardMaterial3D
	if std == null or std.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED or std.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED \
			or std.emission_enabled or std.albedo_texture != null or std.vertex_color_use_as_albedo:
		return null
	return prop_material(std.albedo_color, guess_surface(std.albedo_color, mesh))


# --- Textures ------------------------------------------------------------------------

## Extracted SS texture, or null when the local reference library is absent.
static func ss_texture(id: StringName) -> Texture2D:
	if _textures.has(id):
		return _textures[id]
	var tex: Texture2D = null
	var image: Image = _load_extracted(TEXTURES.get(id, ""))
	if image != null:
		if image.is_compressed():
			image.decompress()
		image.convert(Image.FORMAT_RGBA8)
		_means[id] = _image_mean(image)
		image.generate_mipmaps()
		tex = ImageTexture.create_from_image(image)
	_textures[id] = tex
	return tex


## True when the local SS reference textures are available (dev machine).
static func has_local_assets() -> bool:
	return ss_texture(&"uc") != null


## SS shadow brush (T_SHD_TypeD_UC), else a procedural stand-in (patches, no hatching).
static func uc_texture() -> Texture2D:
	if _uc != null:
		return _uc
	_uc = ss_texture(&"uc")
	if _uc == null:
		_uc = _procedural_uc()
	return _uc


## SS LUT strip converted to a Godot 3D colour-correction texture.
static func lut_texture(id: StringName) -> Texture3D:
	if _luts.has(id):
		return _luts[id]
	var tex: Texture3D = null
	var image: Image = _load_extracted(LUTS.get(id, ""))
	if image != null and image.get_width() == 256 and image.get_height() == 16:
		image.convert(Image.FORMAT_RGB8)
		var slices: Array[Image] = []
		for b in 16:
			slices.append(image.get_region(Rect2i(b * 16, 0, 16, 16)))
		var lut := ImageTexture3D.new()
		if lut.create(Image.FORMAT_RGB8, 16, 16, 16, false, slices) == OK:
			tex = lut
	_luts[id] = tex
	return tex


static func _load_extracted(relative: String) -> Image:
	if relative == "":
		return null
	var path: String = ProjectSettings.globalize_path(SS_EXTRACTED + relative)
	if path == "" or not FileAccess.file_exists(path):
		return null
	return Image.load_from_file(path)


static func _image_mean(image: Image) -> Color:
	var small := image.duplicate() as Image
	small.resize(8, 8, Image.INTERPOLATE_TRILINEAR)
	var sum := Color(0, 0, 0, 0)
	for y in 8:
		for x in 8:
			sum += small.get_pixel(x, y)
	return sum / 64.0


static func _procedural_uc() -> Texture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	noise.frequency = 0.03
	var a: Image = noise.get_seamless_image(128, 128)
	noise.seed = 7
	var b: Image = noise.get_seamless_image(128, 128)
	var image := Image.create(128, 128, false, Image.FORMAT_RGB8)
	for y in 128:
		for x in 128:
			image.set_pixel(x, y, Color(lerpf(0.5, 0.84, a.get_pixel(x, y).r), 0.0, lerpf(0.3, 0.64, b.get_pixel(x, y).r)))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


# --- Environment / camera --------------------------------------------------------------

static func build_environment(preset_id: StringName) -> Environment:
	var p: Dictionary = SSEnvPresets.get_preset(preset_id)
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	sky_mat.set_shader_parameter("zenith_color", p.zenith)
	sky_mat.set_shader_parameter("horizon_color", p.horizon)
	var fog: Color = p.fog
	var horizon: Color = p.horizon
	sky_mat.set_shader_parameter("ground_color", fog.darkened(0.35))
	sky_mat.set_shader_parameter("cloud_shade", horizon.darkened(0.12))
	sky_mat.set_shader_parameter("cloud_coverage", p.cloud_coverage)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# SS: flat bluish indirect light (IndirectLightingColor), AO off, fixed exposure.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = p.ambient
	env.ambient_light_energy = p.ambient_energy
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	env.ssao_enabled = false
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.fog_enabled = true
	env.fog_light_color = p.fog
	env.fog_density = p.fog_density
	env.fog_sun_scatter = p.fog_sun_scatter
	env.fog_sky_affect = 0.25
	env.adjustment_enabled = true
	env.adjustment_contrast = p.contrast
	env.adjustment_saturation = p.saturation
	var lut: Texture3D = lut_texture(p.lut)
	if lut != null:
		env.adjustment_color_correction = lut
	return env


## SS sun: hard toon shadows, 2 cascades (SUN_0 DynamicShadowCascades = 2).
static func configure_sun(sun: DirectionalLight3D, preset_id: StringName) -> void:
	var p: Dictionary = SSEnvPresets.get_preset(preset_id)
	sun.rotation_degrees = p.sun_rotation
	sun.light_color = p.sun_color
	sun.light_energy = p.sun_energy
	sun.light_angular_distance = 0.0
	sun.shadow_enabled = true
	sun.shadow_blur = 0.5
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 52.0   # top-down view: shadows only around the action


## Full-screen SS line pass (depth + normal edges), parented to the camera.
static func attach_post_outline(camera: Camera3D) -> MeshInstance3D:
	if not CombatFx.is_enabled() or ProjectSettings.get_setting("rendering/renderer/rendering_method", "forward_plus") != "forward_plus":
		return null  # needs the Forward+ normal-roughness buffer
	var existing := camera.get_node_or_null("SSPostOutline") as MeshInstance3D
	if existing != null:
		return existing
	var mat := ShaderMaterial.new()
	mat.shader = POST_OUTLINE_SHADER
	mat.render_priority = -64  # before VFX: jutsu effects stay on top of the lines
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	quad.material = mat
	var mi := MeshInstance3D.new()
	mi.name = "SSPostOutline"
	mi.mesh = quad
	mi.extra_cull_margin = 16384.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	camera.add_child(mi)
	return mi
