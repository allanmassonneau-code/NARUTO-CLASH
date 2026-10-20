class_name ClanStyles
## Visual identity of each clan in the character creator: UI colours, crest
## letter, signature traits (hair / skin palettes the clan is limited to),
## clan outfit colours. Colours are matched to the nearest real Shinobi
## Striker colour ids (SSAvatars), so they work with whatever was exported.

## clan id -> {"color", "crest", "traits" (text), "hair" (Array[Color] allowed
## hair shades, empty = free), "skin" (Array[Color], empty = free),
## "cloth": [Color, Color] (clan outfit), "village_hint"}
const STYLES: Dictionary = {
	&"clan_senju": {"color": Color(0.35, 0.75, 0.4), "crest": "森", "traits": "Cheveux bruns ou noirs · tenue verte et brune",
		"hair": [Color(0.2, 0.13, 0.08), Color(0.32, 0.2, 0.12), Color(0.08, 0.07, 0.07)], "skin": [], "cloth": [Color(0.25, 0.42, 0.22), Color(0.4, 0.3, 0.18)]},
	&"clan_uchiha": {"color": Color(0.85, 0.15, 0.15), "crest": "団", "traits": "Cheveux noirs aux reflets bleus · tenue bleu nuit · Sharingan",
		"hair": [Color(0.05, 0.05, 0.08), Color(0.08, 0.08, 0.16), Color(0.12, 0.12, 0.22)], "skin": [], "cloth": [Color(0.1, 0.12, 0.25), Color(0.85, 0.85, 0.88)]},
	&"clan_uzumaki": {"color": Color(0.95, 0.35, 0.25), "crest": "渦", "traits": "Cheveux rouges · tenue rouge et orange",
		"hair": [Color(0.8, 0.12, 0.1), Color(0.65, 0.1, 0.1), Color(0.9, 0.3, 0.2)], "skin": [], "cloth": [Color(0.7, 0.15, 0.12), Color(0.95, 0.55, 0.15)]},
	&"clan_nara": {"color": Color(0.45, 0.55, 0.3), "crest": "奈", "traits": "Cheveux sombres · tenue olive",
		"hair": [Color(0.1, 0.08, 0.06), Color(0.18, 0.13, 0.1)], "skin": [], "cloth": [Color(0.35, 0.4, 0.22), Color(0.2, 0.2, 0.18)]},
	&"clan_akimichi": {"color": Color(0.95, 0.55, 0.2), "crest": "食", "traits": "Cheveux bruns à roux · tenue rouge",
		"hair": [Color(0.45, 0.25, 0.12), Color(0.6, 0.3, 0.12), Color(0.3, 0.18, 0.1)], "skin": [], "cloth": [Color(0.7, 0.15, 0.12), Color(0.85, 0.75, 0.6)]},
	&"clan_roran": {"color": Color(0.85, 0.7, 0.4), "crest": "楼", "traits": "Tenue sable et ocre du désert",
		"hair": [], "skin": [], "cloth": [Color(0.82, 0.7, 0.48), Color(0.55, 0.38, 0.22)]},
	&"clan_sabaku": {"color": Color(0.8, 0.45, 0.25), "crest": "砂", "traits": "Cheveux roux ou blonds · tenue bordeaux et sable",
		"hair": [Color(0.7, 0.18, 0.1), Color(0.85, 0.7, 0.35), Color(0.55, 0.15, 0.1)], "skin": [], "cloth": [Color(0.45, 0.12, 0.12), Color(0.8, 0.68, 0.45)]},
	&"clan_hoki": {"color": Color(0.7, 0.55, 0.9), "crest": "法", "traits": "Tenue blanche de laboratoire, accents violets",
		"hair": [], "skin": [], "cloth": [Color(0.9, 0.9, 0.92), Color(0.5, 0.35, 0.65)]},
	&"clan_kugutsu": {"color": Color(0.6, 0.35, 0.75), "crest": "傀", "traits": "Tenue noire et violette de marionnettiste",
		"hair": [], "skin": [], "cloth": [Color(0.12, 0.1, 0.14), Color(0.5, 0.3, 0.6)]},
	&"clan_hakumei": {"color": Color(1.0, 0.85, 0.45), "crest": "白", "traits": "Cheveux clairs · tenue blanche et dorée",
		"hair": [Color(0.95, 0.88, 0.6), Color(0.9, 0.9, 0.85), Color(0.8, 0.65, 0.35)], "skin": [], "cloth": [Color(0.92, 0.9, 0.85), Color(0.85, 0.7, 0.3)]},
	&"clan_chinoike": {"color": Color(0.7, 0.05, 0.12), "crest": "血", "traits": "Cheveux noirs · tenue rouge sang",
		"hair": [Color(0.06, 0.05, 0.06), Color(0.25, 0.05, 0.06)], "skin": [], "cloth": [Color(0.45, 0.04, 0.08), Color(0.1, 0.08, 0.09)]},
	&"clan_fuma": {"color": Color(0.55, 0.6, 0.68), "crest": "風", "traits": "Tenue gris acier",
		"hair": [], "skin": [], "cloth": [Color(0.32, 0.34, 0.38), Color(0.6, 0.62, 0.66)]},
	&"clan_salamandre": {"color": Color(0.4, 0.65, 0.35), "crest": "椒", "traits": "Tenue vert sombre et noire, masque",
		"hair": [], "skin": [], "cloth": [Color(0.15, 0.25, 0.15), Color(0.08, 0.08, 0.08)]},
	&"clan_kaguya": {"color": Color(0.92, 0.92, 0.95), "crest": "骨", "traits": "Cheveux blancs · peau pâle · tenue blanche",
		"hair": [Color(0.95, 0.95, 0.95), Color(0.85, 0.85, 0.88)], "skin": [Color(0.96, 0.88, 0.82), Color(0.93, 0.83, 0.76)], "cloth": [Color(0.92, 0.92, 0.9), Color(0.35, 0.3, 0.4)]},
	&"clan_kami": {"color": Color(0.5, 0.6, 0.95), "crest": "紙", "traits": "Cheveux bleu-violet · tenue noire",
		"hair": [Color(0.4, 0.45, 0.8), Color(0.45, 0.35, 0.7), Color(0.3, 0.35, 0.6)], "skin": [], "cloth": [Color(0.1, 0.1, 0.14), Color(0.55, 0.15, 0.2)]},
	&"clan_hozuki": {"color": Color(0.45, 0.75, 0.95), "crest": "水", "traits": "Cheveux blancs ou bleu pâle · peau claire",
		"hair": [Color(0.9, 0.92, 0.95), Color(0.7, 0.82, 0.92)], "skin": [Color(0.96, 0.88, 0.82)], "cloth": [Color(0.3, 0.45, 0.65), Color(0.85, 0.85, 0.88)]},
	&"clan_hoshigaki": {"color": Color(0.3, 0.5, 0.85), "crest": "鮫", "traits": "Peau bleutée · cheveux bleu sombre",
		"hair": [Color(0.15, 0.2, 0.45), Color(0.2, 0.3, 0.55)], "skin": [Color(0.55, 0.65, 0.85), Color(0.6, 0.7, 0.8)], "cloth": [Color(0.15, 0.2, 0.35), Color(0.4, 0.45, 0.55)]},
	&"clan_yuki": {"color": Color(0.7, 0.9, 1.0), "crest": "雪", "traits": "Cheveux noirs · peau pâle · tenue blanc glacé",
		"hair": [Color(0.06, 0.06, 0.08), Color(0.12, 0.12, 0.16)], "skin": [Color(0.96, 0.9, 0.86)], "cloth": [Color(0.88, 0.94, 1.0), Color(0.4, 0.6, 0.8)]},
	&"clan_karatachi": {"color": Color(0.95, 0.5, 0.45), "crest": "珊", "traits": "Tenue corail",
		"hair": [], "skin": [], "cloth": [Color(0.9, 0.45, 0.4), Color(0.3, 0.35, 0.45)]},
	&"clan_epeistes": {"color": Color(0.7, 0.75, 0.8), "crest": "刀", "traits": "Cheveux gris ou blancs · tenue de bretteur grise",
		"hair": [Color(0.75, 0.75, 0.78), Color(0.9, 0.9, 0.92), Color(0.1, 0.1, 0.12)], "skin": [], "cloth": [Color(0.25, 0.27, 0.3), Color(0.55, 0.15, 0.15)]},
}
const NO_CLAN: Dictionary = {"color": Color(0.85, 0.8, 0.7), "crest": "忍", "traits": "Aucune contrainte : apparence libre",
	"hair": [], "skin": [], "cloth": [Color(0.3, 0.35, 0.3), Color(0.2, 0.2, 0.25)]}
const VILLAGE_STYLES: Dictionary = {
	&"konoha": {"color": Color(0.45, 0.75, 0.4), "crest": "木", "motto": "Le village caché des feuilles", "headband": "Konoha"},
	&"suna": {"color": Color(0.9, 0.72, 0.4), "crest": "砂", "motto": "Le village caché du sable", "headband": "Suna"},
	&"ame": {"color": Color(0.5, 0.55, 0.75), "crest": "雨", "motto": "Le village caché de la pluie", "headband": "Ame"},
	&"kiri": {"color": Color(0.45, 0.7, 0.85), "crest": "霧", "motto": "Le village caché de la brume", "headband": "Kiri"},
}


static func style(clan_id: StringName) -> Dictionary:
	return STYLES.get(clan_id, NO_CLAN)


static func village(village_id: StringName) -> Dictionary:
	return VILLAGE_STYLES.get(village_id, VILLAGE_STYLES[&"konoha"])


## SS colour ids of `family` ("Hair", "Skin", "Cloth") allowed for the clan:
## the nearest ids to each clan shade (all ids if the clan is free).
static func allowed_ids(clan_id: StringName, family: String) -> Array[String]:
	var all: Array[String] = SSAvatars.colour_ids(family)
	var key: String = family.to_lower()
	var shades: Array = style(clan_id).get(key, [])
	if shades.is_empty() or all.is_empty():
		return all
	var out: Array[String] = []
	for shade: Color in shades:
		for id: String in nearest_ids(all, shade, 3):
			if not out.has(id):
				out.append(id)
	return out


static func nearest_ids(ids: Array[String], target: Color, count: int) -> Array[String]:
	var scored: Array = []
	for id: String in ids:
		var c: Color = SSAvatars.colour(id)
		scored.append([Vector3(c.r - target.r, c.g - target.g, c.b - target.b).length_squared(), id])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var out: Array[String] = []
	for i in mini(count, scored.size()):
		out.append(scored[i][1])
	return out


## Applies the clan's signature look to an avatar: hair / skin moved inside the
## clan palettes, clan outfit colours on upper and lower.
static func apply(avatar: Dictionary, clan_id: StringName) -> Dictionary:
	var out: Dictionary = avatar.duplicate(true)
	var s: Dictionary = style(clan_id)
	var hair_ok: Array[String] = allowed_ids(clan_id, "Hair")
	var hair: Array = out.get("hair_colors", ["", ""])
	if not hair_ok.is_empty() and not hair_ok.has(str(hair[0] if hair.size() > 0 else "")):
		out["hair_colors"] = [hair_ok[0], hair_ok[0]]
	var skin_ok: Array[String] = allowed_ids(clan_id, "Skin")
	if not skin_ok.is_empty() and not skin_ok.has(str(out.get("skin", ""))):
		out["skin"] = skin_ok[0]
	var cloth: Array[String] = SSAvatars.colour_ids("Cloth")
	if not cloth.is_empty():
		var c0: String = nearest_ids(cloth, s.cloth[0], 1)[0]
		var c1: String = nearest_ids(cloth, s.cloth[1], 1)[0]
		out["upper_colors"] = [c0, c1]
		out["lower_colors"] = [c1, c0]
	return out


# --- Outfits reserved to a clan / village -------------------------------------------

## Outfit owners: [mesh name fragment, "clan" | "village", id]. An owned outfit
## (upper or lower) is only offered to that clan / village; others are free.
## Any part whose name contains a clan name (e.g. "Uchiha") is reserved to it.
const OUTFIT_OWNERS: Array = [
	["Vest_01", "village", &"konoha"], ["Vest_03", "village", &"konoha"], ["Vest_04", "village", &"konoha"],
	["SandVest", "village", &"suna"], ["SandPants", "village", &"suna"],
	["MistVest", "village", &"kiri"], ["MistPants", "village", &"kiri"],
	["Cloak_01", "village", &"ame"],
	["Shirt_01", "clan", &"clan_uchiha"],
	["Hoodie_01", "clan", &"clan_kugutsu"], ["Hoodie_02", "clan", &"clan_kugutsu"],
	["Coat_01", "clan", &"clan_hoki"],
	["LeatherCoat_01", "clan", &"clan_epeistes"],
	["Apron_01", "clan", &"clan_akimichi"],
	["Dress_01", "clan", &"clan_hakumei"], ["Dress_02", "clan", &"clan_kaguya"],
	["Tuxedo_01", "clan", &"clan_fuma"],
]


## Owner of an outfit mesh: {"kind": "clan"/"village", "id"} or {} if free.
static func outfit_owner(mesh: String) -> Dictionary:
	var lower: String = mesh.to_lower()
	for clan_id: StringName in STYLES:
		if lower.contains(String(clan_id).trim_prefix("clan_")):
			return {"kind": "clan", "id": clan_id}
	for row: Array in OUTFIT_OWNERS:
		if mesh.contains(row[0]):
			return {"kind": row[1], "id": row[2]}
	return {}


static func outfit_allowed(mesh: String, village_id: StringName, clan_id: StringName) -> bool:
	var owner: Dictionary = outfit_owner(mesh)
	if owner.is_empty():
		return true
	return owner.id == (clan_id if owner.kind == "clan" else village_id)
