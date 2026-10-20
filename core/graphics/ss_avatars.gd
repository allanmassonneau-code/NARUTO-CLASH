class_name SSAvatars
## Shinobi Striker character creator, with the game's own parts and colours (LOCAL ONLY):
## res://_ss_local/creator/catalog.json (DT_CustomHair / Jacket / Pants / PartsColors) and
## res://_ss_local/creator/parts/<mesh>.glb (untinted SS parts + ColorMask_RGB, all on the
## avatar SK_CHR_Face skeleton; SK_CHR_Face.glb also carries the avatar animation clips).
##
## An avatar is a plain Dictionary (saved in the profile, sent over the network):
##   {"sex": "Male"/"Female", "hair": mesh, "upper": mesh, "lower": mesh, "skin": colour id,
##    "hair_colors": [id0, id1], "upper_colors": [id0, id1], "lower_colors": [id0, id1]}
## Missing local files -> available() false and callers keep their fallback.

const ROOT: String = "res://_ss_local/creator/"
const BODY: String = "SK_CHR_Face"
const SLOTS: Array[String] = ["hair", "upper", "lower"]
const SEXES: Array[String] = ["Male", "Female"]
const CATALOG_SLOTS: Dictionary = {"hair": "hair", "upper": "upper", "lower": "lower"}

static var _catalog: Dictionary = {}
static var _loaded: bool = false
static var _scenes: Dictionary = {}
static var _sidecars: Dictionary = {}
static var _foreheads: Dictionary = {}


static func available() -> bool:
	return ResourceLoader.exists(_glb(BODY)) and not _catalog_data().is_empty()


## Parts of a slot for a sex (unisex included), only those exported locally.
## Each: {"id", "mesh" (short name), "color0", "color1"}.
static func options(slot: String, sex: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen: Dictionary = {}
	for row: Dictionary in _catalog_data().get(CATALOG_SLOTS.get(slot, slot), []):
		var s: String = row.get("sex", "")
		if s != sex and s != "Unisex":
			continue
		var mesh: String = String(row.get("mesh", "")).get_file()
		if mesh == "" or seen.has(mesh) or not ResourceLoader.exists(_glb(mesh)):
			continue
		seen[mesh] = true
		out.append({"id": row.get("id", ""), "mesh": mesh, "color0": row.get("color0", ""), "color1": row.get("color1", "")})
	return out


## Forehead protectors (DT_CustomForehead): material swapped on the hair's headband slot.
## Each: {"id", "material" (short name)}.
static func forehead_options() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var mats: Dictionary = _forehead_materials()
	for row: Dictionary in _catalog_data().get("forehead", []):
		var m: String = String(row.get("material", "")).get_file()
		if mats.has(m):
			out.append({"id": row.get("id", ""), "material": m})
	return out


## Accessories (DT_CustomAccessories, static meshes worn on the head).
static func accessory_options() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen: Dictionary = {}
	for row: Dictionary in _catalog_data().get("accessory", []):
		var mesh: String = String(row.get("mesh", "")).get_file()
		if mesh == "" or seen.has(mesh) or not ResourceLoader.exists(_acc_glb(mesh)):
			continue
		seen[mesh] = true
		out.append({"id": row.get("id", ""), "mesh": mesh})
	return out


## SS colour ids of a family ("Skin", "Hair", "Cloth", "Eye"...), in table order.
static func colour_ids(family: String) -> Array[String]:
	var out: Array[String] = []
	var prefix: String = "ID_PartsColor_%s_" % family
	for id: String in _catalog_data().get("colors", {}):
		if id.begins_with(prefix):
			out.append(id)
	return out


## Lit colour (BaseColor) of an SS colour id.
static func colour(id: String) -> Color:
	var c: Array = _catalog_data().get("colors", {}).get(id, [])
	return Color(String(c[0])) if c.size() > 0 else Color.WHITE


## Deterministic avatar for a seed (player default, mobs): real SS parts and colours.
static func random(seed_value: int, sex: String = "") -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	if sex == "":
		sex = SEXES[rng.randi() % SEXES.size()]
	var avatar: Dictionary = {"sex": sex}
	var skins: Array[String] = colour_ids("Skin")
	avatar.skin = skins[rng.randi() % mini(skins.size(), 8)] if not skins.is_empty() else ""
	for slot: String in SLOTS:
		var opts: Array[Dictionary] = options(slot, sex)
		if opts.is_empty():
			continue
		var pick: Dictionary = opts[rng.randi() % opts.size()]
		avatar[slot] = pick.mesh
		avatar[slot + "_colors"] = [pick.color0, pick.color1]
	return avatar


## Fills missing keys with the defaults of the chosen parts (so saved avatars stay valid).
## "seed" (int) picks the defaults: an empty {"seed": n} is a full random SS avatar.
static func complete(avatar: Dictionary) -> Dictionary:
	var seed_value: int = int(avatar.get("seed", 1))
	var sex: String = avatar.get("sex", "")
	var base: Dictionary = random(seed_value, sex if SEXES.has(sex) else "")
	var out: Dictionary = base.duplicate()
	for key: String in avatar:
		out[key] = avatar[key]
	for slot: String in SLOTS:
		if not out.has(slot + "_colors"):
			for o: Dictionary in options(slot, out.sex):
				if o.mesh == out.get(slot, ""):
					out[slot + "_colors"] = [o.color0, o.color1]
	return out


## Builds the avatar: SS body (with clips) + parts skinned on the body skeleton, tinted.
static func instantiate(avatar: Dictionary) -> Node3D:
	if not available():
		return null
	avatar = complete(avatar)
	var body_scene: PackedScene = _scene(BODY)
	var root := body_scene.instantiate() as Node3D
	var skeletons: Array[Node] = root.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return root
	var skel := skeletons[0] as Skeleton3D
	var skin_tint: Color = colour(avatar.get("skin", ""))
	_tint(root, BODY, skin_tint, Color.WHITE, Color.WHITE)
	var forehead: String = avatar.get("forehead", "")
	for slot: String in SLOTS:
		var mesh_name: String = avatar.get(slot, "")
		if mesh_name == "" or _scene(mesh_name) == null:
			continue
		var ids: Array = avatar.get(slot + "_colors", ["", ""])
		var part := _scene(mesh_name).instantiate() as Node3D
		_tint(part, mesh_name, skin_tint, colour(str(ids[0]) if ids.size() > 0 else ""), colour(str(ids[1]) if ids.size() > 1 else ""), forehead)
		_graft(skel, part)
		part.free()
	_wear_accessory(skel, avatar.get("accessory", ""))
	for node: Node in root.find_children("*", "AnimationPlayer", true, false):
		var ap := node as AnimationPlayer
		for clip: StringName in SSCharacters.LOOPS:
			if ap.has_animation(clip):
				ap.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	return root


## Moves the part's meshes onto the body skeleton; bones only the part has (hair, cloth
## tails) are added to the body skeleton at their rest pose; skins bind by bone name.
static func _graft(body: Skeleton3D, part: Node3D) -> void:
	var pskels: Array[Node] = part.find_children("*", "Skeleton3D", true, false)
	if pskels.is_empty():
		return
	var pskel := pskels[0] as Skeleton3D
	for i in pskel.get_bone_count():
		var bone_name: String = pskel.get_bone_name(i)
		if body.find_bone(bone_name) >= 0:
			continue
		var parent: int = pskel.get_bone_parent(i)
		body.add_bone(bone_name)
		var bi: int = body.get_bone_count() - 1
		if parent >= 0:
			body.set_bone_parent(bi, body.find_bone(pskel.get_bone_name(parent)))
		var rest: Transform3D = pskel.get_bone_rest(i)
		body.set_bone_rest(bi, rest)
		body.set_bone_pose_position(bi, rest.origin)
		body.set_bone_pose_rotation(bi, rest.basis.get_rotation_quaternion())
		body.set_bone_pose_scale(bi, rest.basis.get_scale())
	for node: Node in part.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var skin: Skin = mi.skin.duplicate() as Skin if mi.skin != null else null
		if skin != null:
			for b in skin.get_bind_count():
				if skin.get_bind_name(b) == &"" and skin.get_bind_bone(b) >= 0:
					skin.set_bind_name(b, pskel.get_bone_name(skin.get_bind_bone(b)))
		var overrides: Array[Material] = []
		for s in mi.mesh.get_surface_count():
			overrides.append(mi.get_surface_override_material(s))
		mi.get_parent().remove_child(mi)
		mi.owner = null
		body.add_child(mi)
		mi.skeleton = NodePath("..")
		mi.skin = skin
		mi.transform = Transform3D.IDENTITY
		for s in overrides.size():
			mi.set_surface_override_material(s, overrides[s])


## SS accessory on the head bone (meshes keep their SS pivot, relative to that bone).
static func _wear_accessory(skel: Skeleton3D, mesh_name: String) -> void:
	if mesh_name == "" or not ResourceLoader.exists(_acc_glb(mesh_name)):
		return
	var bone: String = ""
	for n: String in ["Head", "head", "Neck"]:
		if skel.find_bone(n) >= 0:
			bone = n
			break
	if bone == "":
		return
	var attach := BoneAttachment3D.new()
	attach.bone_name = bone
	skel.add_child(attach)
	var acc := (load(_acc_glb(mesh_name)) as PackedScene).instantiate() as Node3D
	var entries: Dictionary = {}
	for e: Dictionary in _sidecar_at(_acc_glb(mesh_name)).get("materials", []):
		entries[e.name] = e
	for node: Node in acc.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var src: Material = mi.mesh.surface_get_material(i)
			var key: String = src.resource_name if src != null else ""
			if entries.has(key):
				mi.set_surface_override_material(i, SSCharacters.material_from(ROOT + "parts/acc/", entries[key]))
	# SS accessory meshes are in character axes around the head: undo the head bone's rest rotation.
	var rest: Transform3D = skel.get_bone_global_rest(skel.find_bone(bone))
	acc.transform = Transform3D(rest.basis.orthonormalized().inverse(), Vector3.ZERO)
	attach.add_child(acc)


static func _tint(root: Node, mesh_name: String, skin: Color, c0: Color, c1: Color, forehead: String = "") -> void:
	var entries: Dictionary = {}
	for e: Dictionary in _sidecar(mesh_name).get("materials", []):
		entries[e.name] = e
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var src: Material = mi.mesh.surface_get_material(i)
			var key: String = src.resource_name if src != null else ""
			if not entries.has(key):
				continue
			var entry: Dictionary = entries[key]
			# Forehead protector: the hair's Hachigane slot takes the chosen SS headband material.
			if forehead != "" and String(entry.get("source", "")).contains("Hachigane") and _forehead_materials().has(forehead):
				entry = _forehead_materials()[forehead]
			var m: Material = SSCharacters.material_from(ROOT + "parts/", entry)
			if m is ShaderMaterial and (m as ShaderMaterial).get_shader_parameter("use_mask"):
				m = (m as ShaderMaterial).duplicate()
				(m as ShaderMaterial).set_shader_parameter("tint_skin", skin)
				(m as ShaderMaterial).set_shader_parameter("tint_color0", c0)
				(m as ShaderMaterial).set_shader_parameter("tint_color1", c1)
			mi.set_surface_override_material(i, m)


static func _acc_glb(mesh_name: String) -> String:
	return "%sparts/acc/%s.glb" % [ROOT, mesh_name]


static func _forehead_materials() -> Dictionary:
	if _foreheads.is_empty():
		for e: Dictionary in _sidecar_at(ROOT + "parts/foreheads.json").get("materials", []):
			_foreheads[e.name] = e
	return _foreheads


static func _sidecar_at(path: String) -> Dictionary:
	if _sidecars.has(path):
		return _sidecars[path]
	var data: Dictionary = {}
	var file := FileAccess.open(path if path.ends_with(".json") else path + ".ss.json", FileAccess.READ)
	if file != null:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			data = parsed
	_sidecars[path] = data
	return data


static func _glb(mesh_name: String) -> String:
	return "%sparts/%s.glb" % [ROOT, mesh_name]


static func _scene(mesh_name: String) -> PackedScene:
	if _scenes.has(mesh_name):
		return _scenes[mesh_name]
	var path: String = _glb(mesh_name)
	var scene: PackedScene = load(path) as PackedScene if ResourceLoader.exists(path) else null
	_scenes[mesh_name] = scene
	return scene


static func _sidecar(mesh_name: String) -> Dictionary:
	if _sidecars.has(mesh_name):
		return _sidecars[mesh_name]
	var data: Dictionary = {}
	var file := FileAccess.open(_glb(mesh_name) + ".ss.json", FileAccess.READ)
	if file != null:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			data = parsed
	_sidecars[mesh_name] = data
	return data


static func _catalog_data() -> Dictionary:
	if not _loaded:
		_loaded = true
		var file := FileAccess.open(ROOT + "catalog.json", FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				_catalog = parsed
	return _catalog
