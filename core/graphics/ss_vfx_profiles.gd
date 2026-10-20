class_name SSVfxProfiles
## Shinobi Striker VFX profile of every technique (180 kit techniques + named spells).
## A profile picks an SS element (palette + sprite layers) from the technique's kit
## (nature / clan / sub-jutsu), then refines it with keywords of its id (dragon, shark,
## mirror, chain, shuriken, armour, prison...). Sizes follow the rank (D small -> S big).
##
## Layer = [kind, size, count, life] ; kind "x@flat" lies on the ground. Kinds: SSVfx.KINDS.
## Slots: cast (on the caster's hand), trail (projectile body + wake), impact, zone
## (persistent objects), line (tethers / threads / chains), aura (self buffs), color (SS).

## SS colours per element (art direction: the game's look, not the bible tags).
const COLORS: Dictionary = {
	&"fire": Color(1.0, 0.55, 0.15), &"water": Color(0.35, 0.7, 1.0), &"lightning": Color(0.7, 0.88, 1.0),
	&"earth": Color(0.78, 0.62, 0.42), &"wind": Color(0.72, 1.0, 0.85), &"wood": Color(0.62, 0.45, 0.25),
	&"shadow": Color(0.12, 0.08, 0.2), &"sand": Color(0.92, 0.78, 0.5), &"ice": Color(0.8, 0.95, 1.0),
	&"blood": Color(0.75, 0.05, 0.1), &"poison": Color(0.55, 0.3, 0.85), &"paper": Color(0.98, 0.95, 0.88),
	&"bone": Color(0.96, 0.93, 0.84), &"seal": Color(0.95, 0.75, 0.3), &"coral": Color(1.0, 0.55, 0.45),
	&"fan": Color(0.78, 1.0, 0.88), &"chemistry": Color(0.5, 1.0, 0.45), &"spider": Color(0.95, 0.95, 1.0),
	&"chakra": Color(0.45, 0.75, 1.0), &"uchiha": Color(0.95, 0.15, 0.15), &"susanoo": Color(0.7, 0.45, 1.0),
	&"puppet": Color(0.7, 0.6, 0.95), &"sword": Color(0.85, 0.92, 1.0), &"steel": Color(0.85, 0.88, 0.95),
	&"titan": Color(1.0, 0.75, 0.35), &"smoke": Color(0.92, 0.92, 0.95),
}

## Element presets.
const ELEMENTS: Dictionary = {
	&"fire": {"cast": [["fire", 0.7, 3, 0.4]], "trail": [["fire", 0.9, 1, 0.5], ["ember", 0.5, 1, 0.5]],
		"impact": [["fire", 1.0, 5, 0.6], ["shock@flat", 1.4, 1, 0.35], ["smoke", 0.9, 2, 0.9]],
		"zone": [["magma@flat", 1.0, 1, 0.0], ["fire", 0.6, 3, 0.0]], "line": "trail_soft"},
	&"water": {"cast": [["splash", 0.7, 2, 0.4]], "trail": [["water", 0.8, 1, 0.45], ["bubble", 0.4, 1, 0.6]],
		"impact": [["splash", 1.2, 3, 0.5], ["ring@flat", 1.6, 1, 0.45], ["bubble", 0.5, 3, 0.7]],
		"zone": [["ring_thin@flat", 1.0, 1, 0.0], ["bubble", 0.4, 3, 0.0]], "line": "trail"},
	&"lightning": {"cast": [["lightning", 0.6, 3, 0.3], ["flash", 0.6, 1, 0.2]], "trail": [["lightning", 0.7, 1, 0.25], ["glint", 0.5, 1, 0.3]],
		"impact": [["lightning", 1.0, 4, 0.35], ["flash", 1.4, 1, 0.25], ["ring_thin@flat", 1.6, 1, 0.3]],
		"zone": [["ring_thin@flat", 1.0, 1, 0.0], ["lightning", 0.6, 2, 0.0]], "line": "trail"},
	&"earth": {"cast": [["dust", 0.6, 2, 0.6]], "trail": [["rock", 0.6, 1, 0.5], ["dust", 0.4, 1, 0.7]],
		"impact": [["rock", 1.0, 5, 0.6], ["crack@flat", 1.6, 1, 1.2], ["dust", 1.0, 3, 0.9]],
		"zone": [["crack@flat", 1.0, 1, 0.0], ["dust", 0.5, 2, 0.0]], "line": "trail_soft"},
	&"wind": {"cast": [["wind", 0.6, 1, 0.4], ["speed", 0.7, 1, 0.3]], "trail": [["wind", 0.7, 1, 0.4], ["speed", 0.6, 1, 0.3]],
		"impact": [["wind", 1.3, 1, 0.45], ["ring@flat", 1.8, 1, 0.4], ["speed", 1.0, 2, 0.35]],
		"zone": [["wind@flat", 1.0, 1, 0.0], ["speed", 0.5, 2, 0.0]], "line": "trail_soft"},
	&"wood": {"cast": [["dust", 0.5, 2, 0.6], ["shards", 0.4, 2, 0.6]], "trail": [["rock", 0.6, 1, 0.5], ["shards", 0.3, 1, 0.6]],
		"impact": [["spikes", 1.1, 3, 0.7], ["shards", 0.6, 3, 0.8], ["dust", 0.9, 2, 0.9]],
		"zone": [["crack@flat", 1.0, 1, 0.0], ["shards", 0.4, 2, 0.0]], "line": "trail_soft"},
	&"shadow": {"cast": [["ink", 0.6, 2, 0.6]], "trail": [["ink", 0.6, 1, 0.6]],
		"impact": [["ink", 1.0, 4, 0.8], ["ink@flat", 1.6, 1, 1.0]],
		"zone": [["ink@flat", 1.0, 1, 0.0]], "line": "trail"},
	&"sand": {"cast": [["sand", 0.7, 2, 0.7]], "trail": [["sand", 0.8, 1, 0.7]],
		"impact": [["sand", 1.2, 4, 0.9], ["dust", 1.0, 2, 1.0], ["ring@flat", 1.4, 1, 0.5]],
		"zone": [["sand@flat", 1.0, 1, 0.0], ["sand", 0.5, 2, 0.0]], "line": "trail_soft"},
	&"ice": {"cast": [["ice", 0.6, 1, 0.4], ["glint", 0.5, 1, 0.3]], "trail": [["shards", 0.4, 1, 0.5], ["glint", 0.4, 1, 0.3]],
		"impact": [["ice", 1.2, 1, 0.6], ["shards", 0.7, 4, 0.7], ["cloud", 0.9, 2, 0.8]],
		"zone": [["ice@flat", 1.0, 1, 0.0], ["shards", 0.4, 2, 0.0]], "line": "trail"},
	&"blood": {"cast": [["splash", 0.5, 2, 0.4]], "trail": [["splash", 0.5, 1, 0.4]],
		"impact": [["splash", 1.0, 3, 0.5], ["ink@flat", 1.3, 1, 1.2]],
		"zone": [["ink@flat", 1.0, 1, 0.0], ["splash", 0.4, 2, 0.0]], "line": "trail"},
	&"poison": {"cast": [["cloud", 0.6, 2, 0.8]], "trail": [["bubble", 0.5, 1, 0.6], ["cloud", 0.5, 1, 0.7]],
		"impact": [["cloud", 1.2, 4, 1.2], ["bubble", 0.5, 3, 0.8], ["splash@flat", 1.2, 1, 1.0]],
		"zone": [["cloud", 0.8, 3, 0.0], ["splash@flat", 1.0, 1, 0.0]], "line": "trail_soft"},
	&"paper": {"cast": [["shards", 0.5, 3, 0.7]], "trail": [["shards", 0.4, 1, 0.6], ["glint", 0.3, 1, 0.3]],
		"impact": [["shards", 0.8, 5, 0.9], ["flash", 1.0, 1, 0.25], ["smoke", 0.8, 2, 0.8]],
		"zone": [["shards", 0.5, 4, 0.0]], "line": "trail_soft"},
	&"bone": {"cast": [["shards", 0.4, 2, 0.5]], "trail": [["shards", 0.4, 1, 0.5], ["blur", 0.5, 1, 0.3]],
		"impact": [["spikes", 1.0, 3, 0.7], ["shards", 0.6, 3, 0.7], ["comic", 0.8, 1, 0.2]],
		"zone": [["spikes", 0.6, 3, 0.0]], "line": "trail"},
	&"seal": {"cast": [["seal_strip", 0.8, 1, 0.5], ["ring_thin@flat", 1.2, 1, 0.5]], "trail": [["seal", 0.6, 1, 0.5], ["glint", 0.3, 1, 0.3]],
		"impact": [["seal", 1.0, 3, 0.6], ["ring_thin@flat", 1.6, 1, 0.6], ["rays", 1.0, 1, 0.3]],
		"zone": [["ring_thin@flat", 1.0, 1, 0.0], ["seal_strip", 0.7, 2, 0.0]], "line": "seal"},
	&"coral": {"cast": [["splash", 0.5, 1, 0.4]], "trail": [["shards", 0.4, 1, 0.5], ["splash", 0.4, 1, 0.4]],
		"impact": [["spikes", 1.1, 3, 0.8], ["splash", 0.8, 2, 0.5]],
		"zone": [["spikes", 0.6, 3, 0.0], ["crack@flat", 1.0, 1, 0.0]], "line": "trail_soft"},
	&"fan": {"cast": [["wind", 0.8, 1, 0.4], ["speed", 0.9, 2, 0.3]], "trail": [["wind", 0.7, 1, 0.4], ["shards", 0.3, 1, 0.5]],
		"impact": [["wind", 1.4, 1, 0.5], ["speed", 1.1, 2, 0.4], ["shards", 0.4, 3, 0.7]],
		"zone": [["wind@flat", 1.0, 1, 0.0], ["speed", 0.6, 2, 0.0]], "line": "trail_soft"},
	&"chemistry": {"cast": [["bubble", 0.5, 2, 0.6], ["glint", 0.4, 1, 0.3]], "trail": [["bubble", 0.5, 1, 0.6]],
		"impact": [["splash", 0.9, 2, 0.5], ["bubble", 0.6, 4, 0.8], ["cloud", 0.9, 2, 1.0]],
		"zone": [["cloud", 0.7, 2, 0.0], ["bubble", 0.4, 3, 0.0]], "line": "trail"},
	&"spider": {"cast": [["blur", 0.8, 1, 0.3], ["glint", 0.4, 1, 0.3]], "trail": [["blur", 0.6, 1, 0.3], ["glint", 0.3, 1, 0.3]],
		"impact": [["crack@flat", 1.4, 1, 1.2], ["rays", 0.9, 1, 0.3], ["blur", 0.8, 2, 0.4]],
		"zone": [["crack@flat", 1.0, 1, 0.0], ["cloud", 0.6, 2, 0.0]], "line": "trail"},
	&"chakra": {"cast": [["orb", 0.6, 1, 0.4], ["rays", 0.6, 1, 0.3]], "trail": [["orb", 0.6, 1, 0.3], ["glint", 0.4, 1, 0.3]],
		"impact": [["flash", 1.1, 1, 0.25], ["ring_thin@flat", 1.6, 1, 0.4], ["glow", 0.8, 2, 0.4]],
		"zone": [["ring_thin@flat", 1.0, 1, 0.0], ["glow", 0.4, 2, 0.0]], "line": "trail"},
	&"uchiha": {"cast": [["fire", 0.5, 2, 0.4], ["rays", 0.6, 1, 0.3]], "trail": [["fire", 0.7, 1, 0.4]],
		"impact": [["fire", 0.9, 3, 0.6], ["flash", 1.0, 1, 0.25]],
		"zone": [["ring_thin@flat", 1.0, 1, 0.0], ["fire", 0.5, 2, 0.0]], "line": "trail"},
	&"susanoo": {"cast": [["rays", 1.0, 1, 0.5], ["shell", 1.2, 1, 0.6]], "trail": [["orb", 0.8, 1, 0.4]],
		"impact": [["rays", 1.3, 1, 0.4], ["shock@flat", 1.6, 1, 0.4]],
		"zone": [["shell", 1.0, 1, 0.0]], "line": "trail_soft"},
	&"puppet": {"cast": [["smoke", 0.6, 2, 0.6]], "trail": [["glint", 0.4, 1, 0.3], ["blur", 0.4, 1, 0.3]],
		"impact": [["comic", 0.8, 1, 0.2], ["smoke", 0.8, 2, 0.8], ["cloud", 0.7, 1, 1.0]],
		"zone": [["cloud", 0.6, 2, 0.0]], "line": "trail"},
	&"sword": {"cast": [["glint", 0.6, 1, 0.3]], "trail": [["blur", 0.7, 1, 0.3], ["glint", 0.5, 1, 0.3]],
		"impact": [["speed", 1.2, 1, 0.25], ["flash", 1.0, 1, 0.2], ["glint", 0.7, 2, 0.3]],
		"zone": [["cloud", 0.8, 3, 0.0]], "line": "trail"},
	&"steel": {"cast": [["glint", 0.5, 1, 0.3]], "trail": [["glint", 0.5, 1, 0.3], ["blur", 0.5, 1, 0.3]],
		"impact": [["glint", 0.8, 2, 0.3], ["comic", 0.7, 1, 0.2], ["dust", 0.6, 1, 0.6]],
		"zone": [["glint", 0.4, 2, 0.0]], "line": "trail"},
	&"titan": {"cast": [["rays", 0.8, 1, 0.4], ["dust", 0.6, 2, 0.6]], "trail": [["dust", 0.6, 1, 0.6]],
		"impact": [["comic", 1.2, 1, 0.25], ["shock@flat", 1.8, 1, 0.4], ["dust", 1.2, 4, 1.0], ["crack@flat", 1.6, 1, 1.2]],
		"zone": [["crack@flat", 1.0, 1, 0.0]], "line": "trail_soft"},
	&"smoke": {"cast": [["smoke", 0.8, 3, 0.8]], "trail": [["smoke", 0.6, 1, 0.6]],
		"impact": [["smoke", 1.1, 5, 0.9]], "zone": [["cloud", 0.8, 3, 0.0]], "line": "trail_soft"},
}

## Kit (id prefix) -> element.
const KITS: Dictionary = {
	"katon": &"fire", "suiton": &"water", "raiton": &"lightning", "doton": &"earth", "futon": &"wind",
	"clan_senju": &"wood", "clan_uchiha": &"uchiha", "clan_uzumaki": &"seal", "clan_nara": &"shadow",
	"clan_akimichi": &"titan", "clan_roran": &"fan", "clan_sabaku": &"sand", "clan_hoki": &"chemistry",
	"clan_kugutsu": &"puppet", "clan_hakumei": &"spider", "clan_chinoike": &"blood", "clan_fuma": &"steel",
	"clan_salamandre": &"poison", "clan_kaguya": &"bone", "clan_kami": &"paper", "clan_hozuki": &"water",
	"clan_hoshigaki": &"water", "clan_yuki": &"ice", "clan_karatachi": &"coral", "clan_epeistes": &"sword",
	"sub": &"chakra",
}

## Keyword in a sub-jutsu id -> element (sub-jutsu have no kit element; checked in order).
## Clan / nature techniques keep their kit element, except Susanoo.
const KEYWORDS: Array = [
	["clone", &"smoke"], ["brume", &"smoke"], ["voile", &"smoke"], ["shunshin", &"smoke"], ["substitution", &"smoke"],
	["parchemin", &"paper"], ["explosif", &"fire"], ["hiraishin", &"seal"], ["spatio", &"seal"], ["sceau", &"seal"],
	["barriere", &"seal"], ["marque_maudite", &"shadow"], ["extinction", &"shadow"], ["huit_portes", &"titan"],
	["senbon", &"steel"], ["kunai", &"steel"], ["cable", &"steel"], ["fil_de_chakra", &"puppet"], ["faucon", &"fan"],
	["sphere_spirale", &"wind"], ["absorption", &"chakra"], ["sonore", &"chakra"], ["sensorielle", &"chakra"],
	["lame_de_chakra", &"sword"],
]

## Keyword -> extra shaping of the profile.
const SHAPES: Array = [
	["dragon", {"trail_scale": 2.2, "impact_scale": 1.5}], ["leviathan", {"trail_scale": 2.4, "impact_scale": 1.6}],
	["requin", {"trail_scale": 1.8, "extra_trail": ["bubble_big", 0.6, 1, 0.5]}],
	["phenix", {"extra_trail": ["ember", 0.6, 1, 0.5], "trail_scale": 1.4}],
	["shuriken", {"extra_trail": ["glint", 0.6, 1, 0.2]}], ["miroir", {"extra_zone": ["shards", 0.6, 3, 0.0]}],
	["chaine", {"line": "seal"}], ["fil", {"line": "trail"}], ["ombre", {"line": "trail"}],
	["armure", {"aura": true}], ["avatar", {"aura": true}], ["frenesie", {"aura": true}], ["mode", {"aura": true}],
	["corps", {"aura": true}], ["peau", {"aura": true}], ["greffe", {"aura": true}], ["impulsion", {"aura": true}],
	["porte", {"aura": true}], ["surcadencage", {"aura": true}], ["prison", {"zone_scale": 1.2}], ["cage", {"zone_scale": 1.2}],
	["tornade", {"extra_zone": ["wind", 1.0, 1, 0.0]}], ["typhon", {"extra_zone": ["wind", 1.4, 2, 0.0]}],
	["orage", {"extra_zone": ["lightning", 1.0, 3, 0.0]}], ["tonnerre", {"impact_scale": 1.4}],
	["colosse", {"impact_scale": 1.5}], ["titan", {"impact_scale": 1.7}], ["golem", {"impact_scale": 1.5}],
	["mer_de", {"zone_scale": 1.3}], ["ocean", {"zone_scale": 1.3}], ["domaine", {"zone_scale": 1.3}],
]

static var _cache: Dictionary = {}


## Rank D..S -> size factor ("fidèle SS": small and readable low ranks, big ultimates).
static func rank_scale(id: StringName) -> float:
	var s: String = String(id)
	for r: Array in [["_s_", 1.55], ["_a_", 1.3], ["_b_", 1.12], ["_c_", 1.0], ["_d_", 0.85]]:
		if s.contains(r[0]):
			return r[1]
	return 1.0


static func element_of(id: StringName) -> StringName:
	var s: String = String(id)
	if s.contains("susanoo"):
		return &"susanoo"
	if s.begins_with("sub_"):
		for kw: Array in KEYWORDS:
			if s.contains(kw[0]):
				return kw[1]
	var best: String = ""
	for prefix: String in KITS:
		if s.begins_with(prefix + "_") and prefix.length() > best.length():
			best = prefix
	return KITS.get(best, &"chakra")


## Full profile of a technique id (cached).
static func profile(id: StringName) -> Dictionary:
	if _cache.has(id):
		return _cache[id]
	var el: StringName = element_of(id)
	var base: Dictionary = ELEMENTS.get(el, ELEMENTS[&"chakra"])
	var p: Dictionary = {"element": el, "color": COLORS.get(el, Color.WHITE), "scale": rank_scale(id),
		"cast": base.cast.duplicate(), "trail": base.trail.duplicate(), "impact": base.impact.duplicate(),
		"zone": base.zone.duplicate(), "line": base.line, "aura": false,
		"trail_scale": 1.0, "impact_scale": 1.0, "zone_scale": 1.0}
	var s: String = String(id)
	for shape: Array in SHAPES:
		if not s.contains(shape[0]):
			continue
		var mod: Dictionary = shape[1]
		for key: String in mod:
			match key:
				"extra_trail":
					p.trail.append(mod[key])
				"extra_zone":
					p.zone.append(mod[key])
				"trail_scale", "impact_scale", "zone_scale":
					p[key] = maxf(float(p[key]), float(mod[key]))
				_:
					p[key] = mod[key]
	_cache[id] = p
	return p
