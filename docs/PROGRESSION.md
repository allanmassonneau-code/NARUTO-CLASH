# Progression shinobi — architecture

Spécification de référence : le master prompt « Système de progression shinobi ».
Ce document décrit l'implémentation (Godot 4.3, GDScript typé, data-driven).

## Données (`core/progression/data/`, contenu dans `data/progression/progression_db.tres`)

| Resource | Rôle |
|---|---|
| `GradeData` | PV / chakra de base, points Tenketsu, rang max, choix accordés, événement Sub-jutsu |
| `VillageData` | Konoha, Suna, Ame, Kiri |
| `ChakraNatureData` | une nature + ses 10 techniques (2 par rang D/C/B/A/S) |
| `ClanData` | un clan d'un village + 5 techniques (1 par rang) |
| `SpecializationData` | Médecin / Traqueur / Combattant / Rempart : 3 actifs + 1 passif |
| `JutsuData` | technique : id stable, rang, source, coût, cooldown, tags, prérequis, `gameplay_data` (AbilityData de combat) |
| `SubJutsuData` | technique cachée (B/A/S) : poids, exclusions, villages autorisés |
| `TenketsuTreeData` / `TenketsuNodeData` | coût, prérequis, `stat_modifiers`, position, niveau max |
| `ProgressionDatabase` | tout le contenu + règles encore ouvertes + `validate()` |

Le contenu est généré par `tools/build_progression_db.gd` :
`godot --headless --path . -s tools/build_progression_db.gd`.

## Profil (`CharacterProfile`)

Identité, origine (village, clan / sans clan), grade, récompenses déjà accordées, choix en attente,
natures + **choix par rang** (`nature_choices`), spécialité, techniques **apprises** et **équipées**
(séparées), Sub-jutsu, Tenketsu. Sérialisé en ids uniquement (`to_dict` / `from_dict`, versionné + migration).

## Services (`core/progression/services/`)

- `JutsuRules` : règles pures (`can_learn` : grade, nature possédée, rang autorisé, choix déjà fait, prérequis ; `node_state` pour l'UI).
- `ProgressionService` : création, `promote` (récompenses lues dans `GradeData`, jamais deux fois), natures, spécialité, apprendre / équiper, évolution Sub-jutsu, PV / chakra max.
- `TenketsuService` : dépenser (points, prérequis, niveau max), bonus de stats, reset.
- `SubJutsuRollService` : tirages pondérés (rang, village, exclusions, prérequis, déjà possédé), RNG injectable, `higher_rank` (B→A→S, rien au-dessus de S).
- `ProgressionAuthority` : seul point d'entrée des requêtes joueur (valide → modifie → sauvegarde → signal). Les promotions ne se demandent pas.
- `ProgressionAdmin` : grade, ajout / retrait de jutsu et Sub-jutsu, nature, points Tenketsu, reset, clan, inspection.
- `ProgressionSaveService` : JSON par personnage (même format qu'une base de données).
- `ProgressionDebug` : profils de test par grade (clan / sans clan), commandes `promote_to_*`.

## Contenu (première passe, à ajuster)

Source éditable : `tools/progression_content.py` → `data/progression/content.json` →
`tools/build_progression_db.gd` → `progression_db.tres` (validé : 2 techniques par rang et par nature,
1 par rang et par clan, 3 actifs + 1 passif par spécialité, Sub-jutsu en B/A/S, ids uniques).

- Grades : PV / chakra 100/100, 120/130, 135/150, 155/180, 180/220 ; +2 Tenketsu chacun.
- 5 natures (Katon, Suiton, Raiton, Doton, Futon), 10 techniques chacune.
- 20 clans : Konoha (Senju, Uchiha, Uzumaki, Nara, Akimichi), Suna (Rōran, Sabaku, Hōki, Kugutsu, Hakumei),
  Ame (Chinoike, Fūma, Salamandre, Kaguya, Kami), Kiri (Hōzuki, Hoshigaki, Yuki, Karatachi, Épéistes).
- Spécialités : Médecin, Traqueur, Combattant, Rempart (3 actifs + 1 passif).
- Tenketsu : 10 nœuds (vitalité, chakra, agilité, régénérations, réflexes, corps de fer, concentration,
  points vitaux, ouverture des portes).
- 12 Sub-jutsu : 5 B (poids 4), 4 A (poids 2), 3 S (poids 1).

Règles choisies faute de précision (modifiables dans `rules`) :
- tirage Chunin et tirage « conserver » : rangs B/A/S pondérés (≈ 65 % B, 26 % A, 10 % S) ;
- 6 techniques équipables ;
- la spécialité donne ses 4 compétences dès le choix.

## Tests

`godot --headless --path . res://tests/progression_test.tscn` : les 20 tests de la spec + sauvegarde,
autorité serveur, admin, Tenketsu, tirages (64 vérifications).
