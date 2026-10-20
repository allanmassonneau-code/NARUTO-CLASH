class_name SSIcons
## Shinobi Striker skill icons (T_UI_Skill_*_BC, _ss_local/icons) for every
## technique. Each technique id maps to the SS icon closest to its effect;
## anything unlisted falls back to its kit's element icon, then its own icon.
## Visual only.

const DIR := "res://_ss_local/icons/"

const BY_ID: Dictionary = {
	# Katon
	&"katon_d_braise_tracante": "FlameBombs",
	&"katon_d_souffle_de_recul": "GiantFlameBombs",
	&"katon_c_anneau_de_cendres": "HidingInAsh",
	&"katon_c_comete_incendiaire": "FireBall",
	&"katon_b_prison_thermique": "D33NJ1",
	&"katon_b_lance_de_verre": "D53NJ2",
	&"katon_a_mer_de_flammes": "D63NJ3_Fire",
	&"katon_a_phenix_a_rebond": "PhoenixFlower",
	&"katon_s_fournaise_solaire": "DestroyerFlame",
	&"katon_s_dragon_de_feu_devorant": "DragonFlameBombs",
	# Suiton
	&"suiton_d_aiguille_de_pression": "D45NJ2_2",
	&"suiton_d_pas_de_surface": "Teleportation",
	&"suiton_c_sphere_de_rupture": "D26NJ2",
	&"suiton_c_rideau_refringent": "D24NJ1",
	&"suiton_b_prison_aqueuse": "D26NJ2",
	&"suiton_b_torrent_de_renversement": "Sazanami",
	&"suiton_a_miroir_liquide": "D32NJ2",
	&"suiton_a_maree_captive": "D45NJ2_2",
	&"suiton_s_leviathan_de_pression": "WaterDragon",
	&"suiton_s_domaine_des_profondeurs": "SharkBomb",
	# Raiton
	&"raiton_d_aiguille_voltaique": "LightningBlade",
	&"raiton_d_pas_ionique": "D44NJ1",
	&"raiton_c_arc_sauteur": "LightningStrike",
	&"raiton_c_garde_statique": "TemporaryParalysis",
	&"raiton_b_lance_magnetique": "Chidori",
	&"raiton_b_cage_de_foudre": "D84NJ1",
	&"raiton_a_armure_d_eclair": "Lariat",
	&"raiton_a_tonnerre_guide": "D61NJ1",
	&"raiton_s_circuit_raijin": "D23NJ4",
	&"raiton_s_cataclysme_de_l_orage": "D51NJ1",
	# Doton
	&"doton_d_schiste_ricochet": "Petrifying",
	&"doton_d_ancrage_tellurique": "WeightedBoulder",
	&"doton_c_mur_d_eperon": "MudWall",
	&"doton_c_fosse_d_argile": "SubterraneanVoyage",
	&"doton_b_armure_lithique": "PartialExpansion",
	&"doton_b_chambre_sismique": "DomedWall",
	&"doton_a_faille_ascendante": "Landslide",
	&"doton_a_colosse_de_basalte": "EarthDragonBomb",
	&"doton_s_citadelle_mobile": "D45NJ2_1",
	&"doton_s_cur_tellurique": "HeavenKickPain",
	# Futon
	&"futon_d_lame_de_sillage": "SeveringWave",
	&"futon_d_paume_de_pression": "AirPalm",
	&"futon_c_fil_du_vide": "GreatBreach",
	&"futon_c_ascendance": "LeafRisingWind",
	&"futon_b_orbite_tranchante": "D83NJ1",
	&"futon_b_tornade_de_prise": "TornadoHigh",
	&"futon_a_pas_du_faucon": "D35NJ1",
	&"futon_a_chambre_a_vide": "D52NJ1",
	&"futon_s_typhon_des_huit_directions": "LeafHurricane",
	&"futon_s_lame_atmospherique": "TrueRasenShuriken",
	# Senju (bois)
	&"clan_senju_d_impulsion_ancestrale": "D41NJ2",
	&"clan_senju_c_poigne_de_seve": "SilentStrange",
	&"clan_senju_b_rempart_de_racines": "D73NJ1_2",
	&"clan_senju_a_floraison_de_combat": "D82NJ1",
	&"clan_senju_s_avatar_du_grand_bois": "WoodenDragon",
	# Uchiha
	&"clan_uchiha_d_sharingan_observation": "Sharingan",
	&"clan_uchiha_c_genjutsu_faux_pas": "D31NJ2",
	&"clan_uchiha_b_mimetisme_analytique": "D23NJ2",
	&"clan_uchiha_a_sharingan_prediction": "Amaterasu",
	&"clan_uchiha_s_susanoo_gardien_incomplet": "D44NJ2",
	# Uzumaki (sceaux)
	&"clan_uzumaki_d_fuda_d_entrave": "D29NJ4",
	&"clan_uzumaki_c_chaine_de_scellement": "D33NJ2_1",
	&"clan_uzumaki_b_barriere_quadrillee": "BarrierMethod",
	&"clan_uzumaki_a_sceau_de_renversement": "D43NJ1",
	&"clan_uzumaki_s_chaines_adamantines_prison_des_huit_sceaux": "D26NJ1",
	# Nara (ombres)
	&"clan_nara_d_fil_d_ombre": "ShadowStitching",
	&"clan_nara_c_pas_jumeau": "D73NJ1_1",
	&"clan_nara_b_couture_des_ombres": "ShadowStitching",
	&"clan_nara_a_possession_tactique": "ShadowPossession",
	&"clan_nara_s_crepuscule_des_cent_ombres": "D73NJ2_2",
	# Akimichi
	&"clan_akimichi_d_poing_d_expansion": "D83NJ3_1",
	&"clan_akimichi_c_corps_belier": "D83NJ2_2",
	&"clan_akimichi_b_boulet_humain": "SpikyHumanBoulder",
	&"clan_akimichi_a_mode_papillon": "D83NJ3_2",
	&"clan_akimichi_s_expansion_colossale_chute_du_titan": "D42NJ2_2",
	# Roran (vent d'éventail)
	&"clan_roran_d_claque_d_eventail": "D52NJ2",
	&"clan_roran_c_trois_souffles_cadences": "D72NJ3_L",
	&"clan_roran_b_eventail_miroir": "D72NJ3_R",
	&"clan_roran_a_danse_des_quatre_rafales": "D25NJ2",
	&"clan_roran_s_theatre_des_mille_vents": "DLCNJ03",
	# Sabaku (sable)
	&"clan_sabaku_d_sable_gardien": "SandShield",
	&"clan_sabaku_c_main_des_dunes": "D72NJ2_1",
	&"clan_sabaku_b_cercueil_de_sable": "D72NJ2_2",
	&"clan_sabaku_a_mer_de_sable_mouvante": "D72NJ1_1",
	&"clan_sabaku_s_mausolee_du_desert": "DLCNJ05_2",
	# Hôki (chimie)
	&"clan_hoki_d_injection_experimentale": "PoisonExtraction",
	&"clan_hoki_c_aiguille_adaptative": "NeedleJizo",
	&"clan_hoki_b_greffe_reactive": "PreHealing",
	&"clan_hoki_a_dissection_de_combat": "ChakraDissectionBlade",
	&"clan_hoki_s_chimere_de_laboratoire": "D92NJ1_2",
	# Kugutsu (marionnettes)
	&"clan_kugutsu_d_karakuri_premier_fil": "D71NJ1",
	&"clan_kugutsu_c_croisement_des_fils": "D73NJ1_2",
	&"clan_kugutsu_b_arsenal_dissimule": "D84NJ2",
	&"clan_kugutsu_a_substitution_mecanique": "D101NJ2_3",
	&"clan_kugutsu_s_cent_fils_atelier_de_guerre": "D51NJ2",
	# Hakumei (assassin araignée)
	&"clan_hakumei_d_pas_dedouble": "D54NJ3_Teleportation",
	&"clan_hakumei_c_kunai_du_reflet": "D42NJ2_1",
	&"clan_hakumei_b_marque_du_doute": "D55NJ1_2",
	&"clan_hakumei_a_assassinat_de_l_angle_mort": "D62NJ1",
	&"clan_hakumei_s_theatre_des_morts_blancs": "D62NJ2",
	# Chinoike (sang)
	&"clan_chinoike_d_aiguille_carmine": "D91NJ2",
	&"clan_chinoike_c_miroir_hematique": "D55NJ2_2",
	&"clan_chinoike_b_marionnette_ecarlate": "D93NJ1_1",
	&"clan_chinoike_a_ketsuryugan_regard_de_coagulation": "D102NJ2_2",
	&"clan_chinoike_s_palais_de_sang": "D92NJ1_3",
	# Fûma (acier)
	&"clan_fuma_d_shuriken_fuma_angle_mort": "D33NJ2_2",
	&"clan_fuma_c_fil_du_chasseur": "D33NJ2_1",
	&"clan_fuma_b_demon_a_quatre_lames": "D28NJ4",
	&"clan_fuma_a_course_sur_cable": "FlyingRaijin",
	&"clan_fuma_s_toile_des_lames_cardinales": "D42NJ2_1",
	# Salamandre (poison)
	&"clan_salamandre_d_crachat_alcalin": "D92NJ2",
	&"clan_salamandre_c_salamandre_fouisseuse": "SummonSalamandar",
	&"clan_salamandre_b_miasme_dormant": "PoisonExtraction",
	&"clan_salamandre_a_peau_venimeuse": "D29NJ2",
	&"clan_salamandre_s_grande_salamandre_souffle_d_ibuse": "D42NJ1",
	# Kaguya (os)
	&"clan_kaguya_d_lame_phalangienne": "D94NJ2",
	&"clan_kaguya_c_danse_des_cotes": "D93NJ2",
	&"clan_kaguya_b_balles_digitales": "D93NJ1_2",
	&"clan_kaguya_a_foret_de_tessons": "D81NJ2",
	&"clan_kaguya_s_shikotsumyaku_danse_du_dernier_squelette": "D94NJ1",
	# Kami (papier)
	&"clan_kami_d_shuriken_de_papier": "ShikigamiDanceShield",
	&"clan_kami_c_clone_origami": "D63NJ2",
	&"clan_kami_b_ailes_du_papier": "AngelicAdvent",
	&"clan_kami_a_cage_de_mille_feuillets": "ScrollBird",
	&"clan_kami_s_ocean_de_papier_mille_detonations": "D29NJ4",
	# Hôzuki (eau)
	&"clan_hozuki_d_corps_fluide": "D71NJ2",
	&"clan_hozuki_c_pistolet_a_eau": "D45NJ2_2",
	&"clan_hozuki_b_flaque_vivante": "D24NJ1",
	&"clan_hozuki_a_bras_hydraulique": "D42NJ2_2",
	&"clan_hozuki_s_demon_d_eau_corps_torrentiel": "DLCNJ11",
	# Hoshigaki (requin)
	&"clan_hoshigaki_d_morsure_du_requin": "SharkBomb",
	&"clan_hoshigaki_c_siphon_branchial": "SUMNJ21",
	&"clan_hoshigaki_b_requin_pisteur": "SharkBomb",
	&"clan_hoshigaki_a_frenesie_des_branchies": "D26NJ2",
	&"clan_hoshigaki_s_grand_requin_devoreur_de_chakra": "DLCNJ13",
	# Yuki (glace)
	&"clan_yuki_d_senbon_de_givre": "D35NJ2_1",
	&"clan_yuki_c_miroir_de_glace": "D28NJ4_L",
	&"clan_yuki_b_patinoire_fracturee": "D63NJ3_Ice",
	&"clan_yuki_a_labyrinthe_des_miroirs": "D28NJ4_R",
	&"clan_yuki_s_zero_absolu_cercueil_cristallin": "D27NJ2",
	# Karatachi (corail)
	&"clan_karatachi_d_epine_de_corail": "D94NJ2",
	&"clan_karatachi_c_ecaille_recifale": "D61NJ2",
	&"clan_karatachi_b_crete_jaillissante": "D45NJ2_1",
	&"clan_karatachi_a_recif_predateur": "D93NJ1_2",
	&"clan_karatachi_s_sanctuaire_de_la_tortue_corallienne": "SUMNJ12",
	# Épéistes
	&"clan_epeistes_d_iai_de_garde": "D32NJ2",
	&"clan_epeistes_c_lame_en_rappel": "D62NJ1",
	&"clan_epeistes_b_brise_garde_du_bourreau": "D91NJ1",
	&"clan_epeistes_a_duel_dans_la_brume_rouge": "D55NJ2_1",
	&"clan_epeistes_s_maitrise_des_sept_lames": "D35NJ2_2",
	# Sub-jutsu
	&"sub_b_shunshin_double_empreinte": "Teleportation",
	&"sub_b_clone_explosif_tactique": "D53NJ1_2",
	&"sub_b_paume_d_absorption_de_chakra": "PalmRotation",
	&"sub_b_voile_de_brume_silencieuse": "D53NJ1_2_2",
	&"sub_b_reseau_de_parchemins_explosifs": "D29NJ4",
	&"sub_b_fil_de_chakra_manipulateur": "UniversalPull",
	&"sub_b_fausse_ouverture": "D53NJ1_1",
	&"sub_b_danse_des_cables_kunai": "D42NJ2_1",
	&"sub_b_pulsation_sensorielle": "Byakugan",
	&"sub_b_lame_de_chakra_fluide": "ChakraDissectionBlade",
	&"sub_b_substitution_a_balise": "TransportTech",
	&"sub_b_sceau_d_echo_sonore": "D43NJ1",
	&"sub_a_reseau_de_clones_relais": "D41NJ1",
	&"sub_a_barriere_des_quatre_coins": "BarrierMethod",
	&"sub_a_huit_portes_porte_de_la_vie": "SevenHeavens",
	&"sub_a_marque_d_echange_spatio_temporel": "FlyingRaijin",
	&"sub_a_surcadencage_du_reseau_de_chakra": "D32NJ1",
	&"sub_a_marque_maudite_stade_i": "D55NJ1_2",
	&"sub_a_orbite_des_mille_senbon": "NeedleJizo",
	&"sub_a_sceau_de_suppression_majeure": "NervousRupture",
	&"sub_a_invocation_faucon_de_relais": "ScrollBird",
	&"sub_a_reservoir_de_chakra_scelle": "D34NJ2",
	&"sub_s_hiraishin_reseau_des_marques": "FlyingRaijinLv2",
	&"sub_s_huit_portes_porte_de_la_vue": "UchihaFlameForm",
	&"sub_s_marque_maudite_stade_ii": "D54NJ2",
	&"sub_s_barriere_spatio_temporelle": "D31NJ1",
	&"sub_s_legion_des_clones_d_ombre": "D21NJ1",
	&"sub_s_sphere_spirale_effondrement": "Rasengan",
	&"sub_s_domaine_d_extinction_du_chakra": "D34NJ1_2",
	&"sub_s_transfert_celeste_interdit": "AlmightyPush",
}

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
	var file: String = BY_ID.get(id, "")
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
