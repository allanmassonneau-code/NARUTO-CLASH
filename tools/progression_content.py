#!/usr/bin/env python3
"""Writes data/progression/content.json: the game-design content of the
progression system (grades, villages, natures, clans, specializations,
Tenketsu, sub-jutsu). Edit here (or the JSON directly), then run
    python3 tools/progression_content.py
    godot --headless --path . -s tools/build_progression_db.gd
Row format for techniques: [rank, key, name, description, tags, chakra, cooldown]
"""
import json, os

ROOT = os.path.join(os.path.dirname(__file__), "..")

GRADES = [
    # grade, name, max rank, choices, sub-jutsu event, base HP, base chakra, XP to the next grade
    ["GENIN", "Genin", "C", ["PRIMARY_NATURE"], "NONE", 100, 100, 300],
    ["CHUNIN", "Chunin", "B", ["SPECIALIZATION"], "FIRST_ROLL", 120, 130, 700],
    ["KONIN", "Konin", "B", [], "NONE", 135, 150, 1300],
    ["TOKUBETSU", "Tokubetsu", "A", ["SECONDARY_NATURE"], "EVOLUTION", 155, 180, 2200],
    ["JONIN", "Jonin", "S", [], "NONE", 180, 220, 0],
]

VILLAGES = [["konoha", "Konoha"], ["suna", "Suna"], ["ame", "Ame"], ["kiri", "Kiri"]]

NATURES = {
    "katon": ["Katon", "Feu : dégâts en zone et brûlures.", "#ff7a1a", [
        ["D", "goukakyuu", "Boule de feu suprême", "Grosse boule de feu qui explose à l'impact.", ["RANGED", "PROJECTILE", "AOE"], 15, 6],
        ["D", "housenka", "Pluie de phénix", "Salve de petites flammes guidées qui brûlent.", ["RANGED", "PROJECTILE", "DOT"], 12, 5],
        ["C", "ryuuka", "Feu du dragon", "Jet de flammes en ligne droite qui traverse.", ["RANGED", "HITSCAN"], 20, 8],
        ["C", "haisekishou", "Cendres ardentes", "Nuage de cendres qui s'enflamme en zone.", ["AOE", "DOT", "DEBUFF"], 22, 10],
        ["B", "karyuu_endan", "Missile du dragon de feu", "Long dragon de feu qui laisse le sol en flammes.", ["RANGED", "PROJECTILE", "DOT"], 30, 10],
        ["B", "bakuen", "Brasier", "Explosion autour de soi qui repousse.", ["AOE", "CC", "DEFENSIVE"], 28, 12],
        ["A", "gouryuuka", "Grand dragon de feu", "Plusieurs dragons de feu tombent sur une zone.", ["AOE", "RANGED"], 45, 16],
        ["A", "bakufuu_ranbu", "Tempête de flammes", "Tourbillon de feu canalisé qui aspire les ennemis.", ["AOE", "CHANNELING", "CC"], 45, 18],
        ["S", "goka_messhitsu", "Annihilation des flammes", "Mur de feu gigantesque qui balaie l'arène.", ["AOE", "RANGED"], 70, 30],
        ["S", "karura", "Phénix de Karura", "Phénix qui renaît une fois et brûle tout sur son passage.", ["AOE", "DOT", "BUFF"], 70, 32],
    ]],
    "suiton": ["Suiton", "Eau : contrôle, ralentissements et prisons.", "#4d9bff", [
        ["D", "mizurappa", "Vague d'eau", "Vague frontale qui repousse et ralentit.", ["AOE", "CC"], 12, 6],
        ["D", "mizu_bunshin", "Clone d'eau", "Clone qui distrait et absorbe un coup.", ["DEFENSIVE", "BUFF"], 15, 10],
        ["C", "suiryuudan", "Dragon d'eau", "Dragon d'eau qui percute et projette.", ["RANGED", "PROJECTILE", "CC"], 22, 9],
        ["C", "suijinheki", "Mur d'eau", "Mur qui bloque les projectiles.", ["DEFENSIVE"], 20, 12],
        ["B", "suikoudan", "Requin d'eau", "Requin qui traque la cible la plus proche.", ["RANGED", "PROJECTILE"], 28, 10],
        ["B", "suirou", "Prison d'eau", "Enferme une cible au contact (entrave).", ["MELEE", "CC"], 30, 14],
        ["A", "daibakufu", "Grande cascade", "Torrent qui balaie une grande zone.", ["AOE", "CC"], 45, 16],
        ["A", "kirigakure", "Brume cachée", "Brume qui masque les alliés et ralentit les ennemis.", ["AOE", "BUFF", "DEBUFF"], 40, 20],
        ["S", "daikoudan", "Grand requin", "Requin titanesque qui dévore le chakra.", ["RANGED", "PROJECTILE", "DEBUFF"], 70, 30],
        ["S", "suishouha", "Déferlante", "Raz-de-marée qui inonde l'arène.", ["AOE", "CC"], 75, 34],
    ]],
    "raiton": ["Raiton", "Foudre : vitesse, perforation et paralysie.", "#9fd8ff", [
        ["D", "raikyuu", "Sphère de foudre", "Boule électrique rapide qui paralyse brièvement.", ["RANGED", "PROJECTILE", "CC"], 12, 5],
        ["D", "jibashi", "Décharge", "Décharge au contact qui interrompt.", ["MELEE", "CC"], 10, 6],
        ["C", "kangekiha", "Onde électrique", "Arc électrique en cône.", ["AOE", "CC"], 20, 8],
        ["C", "raikou_senbon", "Aiguilles de foudre", "Pluie d'aiguilles électriques.", ["RANGED", "PROJECTILE", "DOT"], 18, 7],
        ["B", "raiton_yoroi", "Armure de foudre", "Armure qui augmente la vitesse et les dégâts.", ["BUFF", "MOVEMENT"], 30, 18],
        ["B", "raiga", "Croc de foudre", "Ruée électrique qui traverse les ennemis.", ["DASH", "MELEE"], 28, 10],
        ["A", "raigeki_ryuu", "Dragon de foudre", "Dragon électrique qui enchaîne les cibles.", ["RANGED", "AOE"], 45, 16],
        ["A", "gian", "Fausse obscurité", "Rayon perforant à longue portée.", ["RANGED", "HITSCAN"], 42, 14],
        ["S", "kuropansa", "Panthère noire", "Panthère de foudre qui paralyse en zone.", ["AOE", "CC"], 70, 30],
        ["S", "raijin_no_ken", "Épée du dieu du tonnerre", "Lame de foudre étendue, frappes en série.", ["MELEE", "BUFF"], 65, 28],
    ]],
    "doton": ["Doton", "Terre : défense, murs et lourds impacts.", "#a8804d", [
        ["D", "doryuuheki", "Mur de terre", "Mur qui bloque coups et projectiles.", ["DEFENSIVE"], 12, 10],
        ["D", "ganchuurou", "Prison rocheuse", "Piliers qui entravent la cible.", ["CC"], 14, 9],
        ["C", "doryuudan", "Dragon de terre", "Tête de dragon qui crache des boulets de boue.", ["RANGED", "PROJECTILE"], 20, 9],
        ["C", "yomi_numa", "Marais des enfers", "Sol boueux qui ralentit fortement.", ["AOE", "DEBUFF"], 22, 12],
        ["B", "doryuu_sou", "Lances de terre", "Pointes qui jaillissent du sol en ligne.", ["AOE", "CC"], 28, 11],
        ["B", "kajuugan", "Poids lourd", "Alourdit la cible (ralentit, empêche les dashs).", ["DEBUFF", "CC"], 26, 12],
        ["A", "iwa_gaeshi", "Retournement de terrain", "Soulève le sol et projette tout le monde.", ["AOE", "CC"], 45, 18],
        ["A", "kengan", "Poing de roche", "Bras de pierre qui protège puis frappe.", ["MELEE", "DEFENSIVE"], 40, 15],
        ["S", "chidou_kaku", "Montagne mouvante", "Gigantesque bloc qui écrase la zone.", ["AOE", "CC"], 70, 32],
        ["S", "kekkai_doumu", "Dôme de terre", "Dôme qui protège l'équipe puis explose.", ["DEFENSIVE", "AOE"], 70, 34],
    ]],
    "futon": ["Futon", "Vent : portée, coupures et repoussements.", "#9cffb8", [
        ["D", "daitoppa", "Grande bourrasque", "Rafale qui repousse en cône.", ["AOE", "CC"], 12, 6],
        ["D", "shinkuu_gyoku", "Balle de vide", "Projectiles d'air rapides.", ["RANGED", "PROJECTILE"], 10, 4],
        ["C", "kamaitachi", "Faucheuse", "Lames de vent qui saignent.", ["RANGED", "DOT"], 20, 8],
        ["C", "kaze_no_yoroi", "Voile de vent", "Dévie les projectiles quelques instants.", ["DEFENSIVE", "COUNTER"], 22, 14],
        ["B", "atsugai", "Pression", "Explosion de vent concentrée.", ["AOE", "RANGED"], 30, 11],
        ["B", "kaze_no_yaiba", "Lame de vent", "Lame invisible à longue portée.", ["RANGED", "HITSCAN"], 28, 10],
        ["A", "shinkuu_taigyoku", "Grande sphère de vide", "Énorme sphère d'air comprimé.", ["RANGED", "PROJECTILE", "AOE"], 45, 16],
        ["A", "fuujin", "Pas du vent", "Saut porté par le vent qui frappe à l'atterrissage.", ["MOVEMENT", "DASH", "AOE"], 40, 14],
        ["S", "rasen_tatsumaki", "Tornade spirale", "Tornade qui aspire et lacère.", ["AOE", "CC", "CHANNELING"], 70, 30],
        ["S", "shinkuu_renpa", "Rafale du vide", "Mitraille de vide sur une grande zone.", ["RANGED", "AOE"], 70, 28],
    ]],
}

# Clans: one technique per rank D, C, B, A, S (name, description, tags, chakra, cooldown)
CLANS = {
    "konoha": {
        "senju": ["Senju", "Lignée du bois et de la vitalité.", [
            ["Pousse de bois", "Racines qui entravent la cible.", ["CC"], 14, 9],
            ["Mur de bois", "Rempart de bois qui protège les alliés.", ["DEFENSIVE"], 20, 12],
            ["Forêt naissante", "Une forêt jaillit et entrave la zone.", ["AOE", "CC"], 30, 15],
            ["Dragon de bois", "Dragon qui enserre et draine le chakra.", ["CC", "DEBUFF"], 45, 18],
            ["Bouddha aux mille mains", "Statue colossale qui pilonne la zone.", ["AOE", "CC"], 75, 34]]],
        "uchiha": ["Uchiha", "Sharingan, feu et illusions.", [
            ["Sharingan", "Lit les mouvements : marque les ennemis touchés.", ["BUFF", "DEBUFF"], 10, 12],
            ["Corbeaux illusoires", "Nuée de corbeaux qui aveugle.", ["CC", "DEBUFF"], 18, 10],
            ["Magen : Narakumi", "Illusion qui paralyse la cible.", ["CC"], 28, 14],
            ["Amaterasu", "Flammes noires qui brûlent longtemps.", ["RANGED", "DOT"], 45, 18],
            ["Susanoo", "Guerrier spectral qui protège et frappe.", ["DEFENSIVE", "BUFF", "MELEE"], 75, 36]]],
        "uzumaki": ["Uzumaki", "Sceaux et vitalité hors norme.", [
            ["Sceau d'entrave", "Sceau au sol qui fige l'ennemi.", ["CC"], 12, 9],
            ["Chaînes de chakra", "Chaînes qui attirent la cible.", ["CC", "RANGED"], 20, 11],
            ["Vitalité Uzumaki", "Régénère rapidement les PV.", ["HEAL", "BUFF"], 25, 18],
            ["Sceau des quatre symboles", "Scelle les techniques de la cible.", ["DEBUFF", "CC"], 40, 20],
            ["Prison adamantine", "Barrière de chaînes qui emprisonne une zone.", ["AOE", "CC"], 70, 32]]],
        "nara": ["Nara", "Manipulation des ombres.", [
            ["Possession des ombres", "Lie l'ombre de la cible à la sienne.", ["CC"], 14, 10],
            ["Étranglement des ombres", "Étrangle la cible immobilisée.", ["DOT", "CC"], 20, 10],
            ["Couture des ombres", "Aiguilles d'ombre qui transpercent plusieurs ennemis.", ["AOE", "CC"], 30, 14],
            ["Rassemblement des ombres", "Attire et lie tous les ennemis proches.", ["AOE", "CC"], 45, 18],
            ["Domaine des ombres", "L'arène entière devient piège d'ombres.", ["AOE", "CC", "CHANNELING"], 70, 34]]],
        "akimichi": ["Akimichi", "Expansion corporelle et force brute.", [
            ["Expansion", "Grossit : plus de PV et de recul.", ["BUFF", "DEFENSIVE"], 12, 12],
            ["Char humain", "Roule à grande vitesse et renverse.", ["DASH", "CC"], 20, 10],
            ["Poing géant", "Bras géant qui écrase devant soi.", ["MELEE", "AOE"], 28, 11],
            ["Pilule de sur-expansion", "Forme géante temporaire.", ["BUFF"], 40, 22],
            ["Mode papillon", "Ailes de chakra : puissance démesurée.", ["BUFF", "MELEE", "MOVEMENT"], 70, 36]]],
    },
    "suna": {
        "roran": ["Rōran", "Gardiens de la veine du dragon.", [
            ["Pulsation de la veine", "Onde de chakra qui repousse.", ["AOE", "CC"], 12, 8],
            ["Mirage du désert", "Mirage qui crée des leurres.", ["DEFENSIVE", "BUFF"], 18, 12],
            ["Sceau de Rōran", "Sceau qui réduit les dégâts reçus par les alliés.", ["BUFF", "DEFENSIVE"], 28, 16],
            ["Torrent de la veine", "Flux de chakra dévastateur en ligne.", ["RANGED", "HITSCAN"], 45, 16],
            ["Renaissance de la veine", "Ramène un allié tombé avec une partie de ses PV.", ["HEAL"], 80, 60]]],
        "sabaku": ["Sabaku", "Maîtres du sable.", [
            ["Shuriken de sable", "Salve de shuriken de sable.", ["RANGED", "PROJECTILE"], 10, 5],
            ["Cercueil de sable", "Enveloppe et immobilise la cible.", ["CC"], 22, 12],
            ["Armure de sable", "Bouclier qui absorbe les dégâts.", ["DEFENSIVE", "BUFF"], 28, 16],
            ["Enterrement du désert", "Écrase la cible prisonnière du sable.", ["CC", "AOE"], 45, 18],
            ["Tsunami de sable", "Vague de sable qui engloutit l'arène.", ["AOE", "CC"], 75, 34]]],
        "hoki": ["Hōki", "Transmission et partage du chakra.", [
            ["Transfert de chakra", "Donne du chakra à un allié.", ["BUFF"], 10, 10],
            ["Lien mental", "Relie deux alliés : dégâts partagés.", ["DEFENSIVE", "BUFF"], 18, 14],
            ["Sceau de soutien", "Augmente les dégâts de l'équipe.", ["BUFF", "AOE"], 28, 18],
            ["Esprit partagé", "Les alliés voient les télégraphes plus tôt.", ["BUFF"], 40, 24],
            ["Connaissance absolue", "Réduit tous les temps de recharge de l'équipe.", ["BUFF", "AOE"], 70, 40]]],
        "kugutsu": ["Kugutsu", "Marionnettistes.", [
            ["Fils de chakra", "Fils qui attirent et ralentissent.", ["CC", "RANGED"], 10, 7],
            ["Marionnette Karasu", "Marionnette qui attaque à distance.", ["RANGED", "PROJECTILE"], 20, 10],
            ["Lames empoisonnées", "Lames qui empoisonnent.", ["MELEE", "DOT"], 26, 11],
            ["Marionnette bouclier", "Marionnette qui protège de face.", ["DEFENSIVE"], 40, 18],
            ["Armée des cent marionnettes", "Cent marionnettes envahissent l'arène.", ["AOE", "CC"], 75, 36]]],
        "hakumei": ["Hakumei", "Lumière de l'aube et illusions solaires.", [
            ["Éclat de l'aube", "Éclair lumineux qui aveugle.", ["CC", "RANGED"], 12, 8],
            ["Voile crépusculaire", "Rend invisible quelques instants.", ["MOVEMENT", "DEFENSIVE"], 18, 14],
            ["Rayon d'aurore", "Rayon de lumière perforant.", ["RANGED", "HITSCAN"], 28, 11],
            ["Brume de l'aube", "Zone lumineuse qui soigne les alliés.", ["HEAL", "AOE"], 40, 18],
            ["Aube éternelle", "Lumière écrasante qui étourdit l'arène.", ["AOE", "CC"], 70, 34]]],
    },
    "ame": {
        "chinoike": ["Chinoike", "Ketsuryūgan et sang.", [
            ["Ketsuryūgan", "Yeux de sang : les coups saignent.", ["BUFF", "DOT"], 12, 12],
            ["Lame de sang", "Lame de sang durci.", ["MELEE"], 18, 7],
            ["Ébullition du sang", "Fait bouillir le sang de la cible.", ["DOT", "DEBUFF"], 28, 14],
            ["Genjutsu sanglant", "Illusion qui terrifie.", ["CC"], 42, 18],
            ["Lune de sang", "Œil maudit qui paralyse et vide la vie.", ["AOE", "CC", "DOT"], 75, 36]]],
        "fuma": ["Fūma", "Maîtres des grands shuriken.", [
            ["Fūma shuriken", "Grand shuriken qui revient.", ["RANGED", "PROJECTILE"], 10, 6],
            ["Moulin géant", "Shuriken tournoyant autour de soi.", ["AOE", "MELEE"], 18, 9],
            ["Tempête de lames", "Pluie de shuriken sur une zone.", ["AOE", "RANGED"], 28, 12],
            ["Ombre de shuriken", "Shuriken caché dans l'ombre d'un autre.", ["RANGED", "PROJECTILE"], 40, 14],
            ["Danse des mille lames", "Mille shuriken balaient l'arène.", ["AOE", "RANGED"], 70, 32]]],
        "salamandre": ["Salamandre", "Poison et invocation d'Ibuse.", [
            ["Poison de salamandre", "Poison qui ronge les PV.", ["DOT", "RANGED"], 10, 7],
            ["Ibuse", "Invoque la salamandre géante.", ["AOE", "DOT"], 22, 16],
            ["Brume toxique", "Nuage empoisonné persistant.", ["AOE", "DOT", "DEBUFF"], 28, 14],
            ["Kusarigama de Hanzō", "Faucille enchaînée empoisonnée.", ["MELEE", "RANGED", "DOT"], 40, 14],
            ["Gardien Ibuse", "Ibuse protège et empoisonne la zone.", ["AOE", "DEFENSIVE", "DOT"], 70, 34]]],
        "kaguya": ["Kaguya", "Shikotsumyaku : manipulation des os.", [
            ["Balles d'os", "Tire des fragments d'os.", ["RANGED", "PROJECTILE"], 10, 5],
            ["Danse du camélia", "Épée d'os rapide.", ["MELEE"], 16, 6],
            ["Danse du saule", "Os qui jaillissent de tout le corps.", ["AOE", "COUNTER"], 26, 12],
            ["Danse du mélèze", "Armure d'os acérée.", ["DEFENSIVE", "MELEE"], 40, 16],
            ["Forêt d'os", "Forêt de lances d'os en zone.", ["AOE", "CC"], 72, 34]]],
        "kami": ["Kami", "Origami de chakra.", [
            ["Papillons de papier", "Nuée qui aveugle et suit la cible.", ["RANGED", "DEBUFF"], 10, 7],
            ["Lances de papier", "Lances de papier tranchant.", ["RANGED", "PROJECTILE"], 18, 8],
            ["Ailes de papier", "Envol qui rend insaisissable.", ["MOVEMENT", "DEFENSIVE"], 26, 14],
            ["Clone de papier", "Clone qui explose.", ["AOE", "DEFENSIVE"], 40, 16],
            ["Mer de papier", "Océan de papier qui ensevelit l'arène.", ["AOE", "CC"], 75, 36]]],
    },
    "kiri": {
        "hozuki": ["Hōzuki", "Corps liquide.", [
            ["Liquéfaction", "Devient eau : esquive les coups.", ["DEFENSIVE", "MOVEMENT"], 12, 10],
            ["Balle d'eau", "Tir d'eau sous pression.", ["RANGED", "PROJECTILE"], 12, 5],
            ["Bras gonflé", "Bras hypertrophié qui écrase.", ["MELEE"], 22, 9],
            ["Corps d'eau", "Intangible pendant plusieurs secondes.", ["DEFENSIVE"], 38, 20],
            ["Dragon d'eau colossal", "Se transforme en dragon d'eau.", ["AOE", "CC"], 70, 34]]],
        "hoshigaki": ["Hoshigaki", "Hommes-requins.", [
            ["Peau de requin", "Réduit les dégâts reçus.", ["DEFENSIVE", "BUFF"], 10, 12],
            ["Absorption de chakra", "Vole le chakra au contact.", ["MELEE", "DEBUFF"], 16, 8],
            ["Charge du requin", "Plongée qui percute.", ["DASH", "MELEE"], 26, 10],
            ["Fusion requin", "Forme de requin : vitesse et dégâts.", ["BUFF", "MOVEMENT"], 40, 20],
            ["Mille requins", "Banc de requins qui dévore l'arène.", ["AOE", "DEBUFF"], 72, 34]]],
        "yuki": ["Yuki", "Hyōton : la glace.", [
            ["Senbon de glace", "Aiguilles de glace qui ralentissent.", ["RANGED", "PROJECTILE", "DEBUFF"], 10, 5],
            ["Miroirs de glace", "Cage de miroirs autour de la cible.", ["CC", "AOE"], 22, 14],
            ["Lances de glace", "Lances qui jaillissent du sol.", ["AOE", "CC"], 28, 11],
            ["Prison de glace", "Gèle la cible sur place.", ["CC"], 40, 16],
            ["Dragon noir de glace", "Dragon de glace qui gèle la zone.", ["AOE", "CC"], 72, 34]]],
        "karatachi": ["Karatachi", "Corail et miroirs d'eau.", [
            ["Corail", "Corail qui enracine la cible.", ["CC"], 12, 9],
            ["Miroir d'eau", "Renvoie la prochaine technique.", ["COUNTER", "DEFENSIVE"], 20, 14],
            ["Bâton à crochets", "Frappe qui attire.", ["MELEE", "CC"], 24, 9],
            ["Sceau de corail", "Corail qui pétrifie en zone.", ["AOE", "CC"], 40, 18],
            ["Réflexion totale", "Copie la dernière technique ennemie.", ["COUNTER", "BUFF"], 70, 34]]],
        "epeistes": ["Épéistes", "Héritiers des sept épées de Kiri.", [
            ["Kubikiribōchō", "Tranche lourde qui se répare en touchant.", ["MELEE", "HEAL"], 10, 6],
            ["Kiba", "Lames de foudre jumelles.", ["MELEE", "CC"], 18, 8],
            ["Hiramekarei", "Lame de chakra étendue.", ["MELEE", "AOE"], 26, 11],
            ["Nuibari", "Aiguille qui coud plusieurs ennemis ensemble.", ["RANGED", "CC"], 40, 16],
            ["Samehada", "L'épée dévore le chakra et soigne son porteur.", ["MELEE", "HEAL", "DEBUFF"], 70, 32]]],
    },
}

# Specializations: 3 actives + 1 passive (name, description, tags, chakra, cooldown)
SPECIALIZATIONS = [
    ["medic", "Médecin", "Soutien", "Soigne, purifie et maintient l'équipe en vie.", [
        ["Paume mystique", "Soigne un allié (ou soi-même).", ["HEAL"], 20, 10],
        ["Extraction", "Retire poisons et altérations d'un allié.", ["HEAL", "BUFF"], 15, 14],
        ["Scalpel de chakra", "Coupe les muscles : ralentit et affaiblit.", ["MELEE", "DEBUFF"], 15, 8]],
        ["Médecine ninja", "Les soins prodigués sont plus efficaces.", ["HEAL"]]],
    ["tracker", "Traqueur", "Traque", "Marque, piste et achève les cibles isolées.", [
        ["Marque de traque", "Révèle et marque une cible.", ["DEBUFF", "RANGED"], 10, 10],
        ["Chiens pisteurs", "Invoque des chiens qui harcèlent la cible.", ["DOT", "CC"], 20, 14],
        ["Piège à fil", "Piège qui entrave le premier ennemi.", ["CC"], 15, 12]],
        ["Œil du chasseur", "Dégâts accrus contre les cibles marquées ou isolées.", ["BUFF"]]],
    ["fighter", "Combattant", "Dégâts", "Taijutsu offensif et enchaînements.", [
        ["Ruée", "Fonce sur la cible et frappe.", ["DASH", "MELEE"], 10, 8],
        ["Enchaînement", "Série de coups rapides.", ["MELEE"], 15, 7],
        ["Brise-garde", "Coup lourd qui brise la garde.", ["MELEE", "CC"], 20, 12]],
        ["Instinct de combat", "Chaque coup au corps à corps réduit les temps de recharge.", ["BUFF"]]],
    ["bulwark", "Rempart", "Protection", "Encaisse et protège ses alliés.", [
        ["Provocation", "Force les ennemis proches à vous cibler.", ["CC", "DEFENSIVE"], 10, 14],
        ["Bouclier de chakra", "Bouclier sur soi ou un allié.", ["DEFENSIVE", "BUFF"], 20, 14],
        ["Mur protecteur", "Se place devant un allié et bloque.", ["DEFENSIVE", "MOVEMENT"], 15, 12]],
        ["Peau de fer", "Réduit les dégâts subis.", ["DEFENSIVE"]]],
]

# Tenketsu: id, name, description, cost, prerequisites, modifiers, position, max level
TENKETSU = [
    ["vitality", "Vitalité", "+8 PV max par niveau.", 1, [], {"hp": 8}, [0, 0], 3],
    ["flow", "Flux de chakra", "+10 chakra max par niveau.", 1, [], {"chakra": 10}, [2, 0], 3],
    ["agility", "Agilité", "+3 % de vitesse par niveau.", 1, [], {"mobility": 0.03}, [4, 0], 2],
    ["regeneration", "Régénération", "+0,5 PV/s par niveau.", 1, ["vitality"], {"hp_regen": 0.5}, [0, 1], 2],
    ["circulation", "Circulation", "+1 chakra/s par niveau.", 1, ["flow"], {"chakra_regen": 1.0}, [2, 1], 2],
    ["reflexes", "Réflexes", "-4 % de temps de recharge par niveau.", 2, ["agility"], {"cooldown_reduction": 0.04}, [4, 1], 2],
    ["iron_body", "Corps de fer", "-4 % de dégâts subis par niveau.", 2, ["regeneration"], {"resistance": 0.04}, [0, 2], 2],
    ["focus", "Concentration", "+5 % de dégâts des techniques par niveau.", 2, ["circulation"], {"jutsu_power": 0.05}, [2, 2], 2],
    ["pressure_points", "Points vitaux", "+5 % de dégâts au corps à corps par niveau.", 2, ["reflexes"], {"melee_power": 0.05}, [4, 2], 2],
    ["eight_gates", "Ouverture des portes", "Ultime : +10 % de dégâts et de vitesse sous 30 % de PV.", 3, ["iron_body", "focus", "pressure_points"], {"last_stand": 0.10}, [2, 3], 1],
]

# Sub-jutsu: rank, id, name, description, tags, chakra, cooldown, weight
SUB_JUTSU = [
    ["B", "kage_bunshin", "Multiclonage", "Plusieurs clones solides combattent à vos côtés.", ["BUFF", "AOE"], 30, 18, 4],
    ["B", "shunshin", "Shunshin avancé", "Téléportation courte à répétition.", ["MOVEMENT", "DASH"], 15, 6, 4],
    ["B", "choju_giga", "Bêtes d'encre", "Fauves d'encre qui attaquent et entravent.", ["RANGED", "CC"], 25, 12, 4],
    ["B", "kuchiyose_gama", "Invocation : crapauds", "Un crapaud combat et vous protège.", ["DEFENSIVE", "AOE"], 30, 20, 4],
    ["B", "senbon_doku", "Senbon empoisonnés", "Aiguilles au poison paralysant.", ["RANGED", "DOT", "CC"], 18, 8, 4],
    ["A", "hachimon_life", "Porte de la vie", "Ouvre les premières portes : puissance au prix des PV.", ["BUFF", "MELEE"], 0, 30, 2],
    ["A", "rashomon", "Rashōmon", "Porte démoniaque qui bloque tout.", ["DEFENSIVE"], 45, 30, 2],
    ["A", "hiraishin", "Dieu du tonnerre volant", "Kunai marqués : téléportation instantanée.", ["MOVEMENT", "DASH"], 40, 14, 2],
    ["A", "senjutsu", "Mode ermite", "Énergie naturelle : dégâts et portée accrus.", ["BUFF"], 50, 40, 2],
    ["S", "hachimon_death", "Porte de la mort", "Huitième porte : puissance absolue, puis épuisement.", ["BUFF", "MELEE"], 0, 90, 1],
    ["S", "kamui", "Kamui", "Dimension parallèle : intangibilité et absorption.", ["DEFENSIVE", "COUNTER"], 70, 36, 1],
    ["S", "edo_tensei", "Réincarnation des âmes", "Rappelle un combattant tombé pour se battre à vos côtés.", ["BUFF", "AOE"], 90, 60, 1],
]


# World mobs: id, name, XP per kill (the server's reference table)
MOBS = [
    ["bandit", "Bandit", 12],
    ["bandit_thrower", "Lanceur de kunai", 14],
    ["rogue_ninja", "Ninja déserteur", 30],
    ["rogue_kunoichi", "Kunoichi déserteuse", 32],
    ["elite_missing_nin", "Nukenin d'élite", 70],
    ["ronin", "Samouraï renégat", 65],
    ["boss_akatsuki", "Membre de l'Akatsuki", 250],
]


def slug(text):
    import unicodedata
    t = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode().lower()
    return "".join(c if c.isalnum() else "_" for c in t).strip("_").replace("__", "_")


def jutsu(id_, name, desc, rank, tags, chakra, cd, passive=False):
    return {"id": id_, "name": name, "description": desc, "rank": rank, "tags": tags,
            "chakra_cost": chakra, "cooldown": cd, "passive": passive}


def load_bible():
    """Natures, clans and sub-jutsu from the design bible (tools/bible_import.py)."""
    path = os.path.join(ROOT, "data", "progression", "bible.json")
    if not os.path.exists(path):
        return None
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def bible_jutsu(j):
    entry = jutsu(j["id"], j["name"], j["description"], j["rank"], j["tags"], j["chakra_cost"], j["cooldown"])
    entry["design_tags"] = j["design_tags"]
    parts = [j.get("activation", "")]
    for label, key in (("Mécanique", "mechanic"), ("Synergies", "synergies"), ("Contre-jeu", "counter")):
        if j.get(key):
            parts.append(f"{label} : {j[key]}")
    entry["details"] = "\n\n".join(parts)
    return entry


def build():
    data = {
        "_comment": "Generated by tools/progression_content.py; values are a first pass to tune.",
        "grades": [{"grade": g[0], "name": g[1], "max_rank": g[2], "choices": g[3], "sub_jutsu_event": g[4],
                    "base_hp": g[5], "base_chakra": g[6], "tenketsu_points": 2, "xp_to_next": g[7]} for g in GRADES],
        "mobs": {m[0]: {"name": m[1], "xp": m[2]} for m in MOBS},
        "villages": [{"id": v[0], "name": v[1]} for v in VILLAGES],
        "natures": [], "clans": [], "specializations": [], "tenketsu": [], "sub_jutsu": [],
        "rules": {"sub_jutsu_roll_ranks": ["B", "A", "S"], "max_equipped_jutsu": 6, "specialization_grants_skills": True},
    }
    bible = load_bible()
    for nid, (name, desc, color, rows) in NATURES.items():
        if bible:
            kit = bible["natures"][nid]
            data["natures"].append({"id": nid, "name": name, "description": desc, "color": color,
                "identity": kit.get("identity", ""), "signature": kit.get("signature", ""),
                "jutsu": [bible_jutsu(j) for j in kit["jutsu"]]})
            continue
        data["natures"].append({"id": nid, "name": name, "description": desc, "color": color,
            "jutsu": [jutsu(f"{nid}_{r[0].lower()}_{r[1]}", r[2], r[3], r[0], r[4], r[5], r[6]) for r in rows]})
    for village, clans in CLANS.items():
        for cid, (name, desc, rows) in clans.items():
            if bible:
                kit = bible["clans"][cid]
                data["clans"].append({"id": f"clan_{cid}", "name": kit["name"], "village": village, "description": desc,
                    "identity": kit.get("identity", ""), "signature": kit.get("signature", ""),
                    "jutsu": [bible_jutsu(j) for j in kit["jutsu"]]})
                continue
            data["clans"].append({"id": f"clan_{cid}", "name": name, "village": village, "description": desc,
                "jutsu": [jutsu(f"clan_{cid}_{rank.lower()}_{slug(r[0])}", r[0], r[1], rank, r[2], r[3], r[4])
                          for rank, r in zip("DCBAS", rows)]})
    for sid, name, role, desc, actives, passive in SPECIALIZATIONS:
        data["specializations"].append({"id": sid, "name": name, "role": role, "description": desc,
            "active": [jutsu(f"{sid}_{slug(a[0])}", a[0], a[1], "D", a[2], a[3], a[4]) for a in actives],
            "passive": jutsu(f"{sid}_passive_{slug(passive[0])}", passive[0], passive[1], "D", passive[2], 0, 0, True)})
    for t in TENKETSU:
        data["tenketsu"].append({"id": f"tenketsu_{t[0]}", "name": t[1], "description": t[2], "cost": t[3],
            "prerequisites": [f"tenketsu_{p}" for p in t[4]], "modifiers": t[5], "position": t[6], "max_level": t[7]})
    for s in ([] if bible else SUB_JUTSU):
        entry = jutsu(f"sub_{s[0].lower()}_{s[1]}", s[2], s[3], s[0], s[4], s[5], s[6])
        entry["weight"] = s[7]
        data["sub_jutsu"].append(entry)
    if bible:
        for j in bible["sub_jutsu"]:
            entry = bible_jutsu(j)
            entry["weight"] = 4
            data["sub_jutsu"].append(entry)
    os.makedirs(os.path.join(ROOT, "data", "progression"), exist_ok=True)
    with open(os.path.join(ROOT, "data", "progression", "content.json"), "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
    print("wrote content.json:", len(data["natures"]), "natures,", len(data["clans"]), "clans,",
          len(data["sub_jutsu"]), "sub-jutsu")


if __name__ == "__main__":
    build()
