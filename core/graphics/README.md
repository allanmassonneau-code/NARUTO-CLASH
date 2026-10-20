# Rendu « Shinobi Striker » (core/graphics)

Base graphique commune du jeu. Tout ce qui est visuel (personnages, props, maps, futurs
cheveux / vêtements / jutsu) doit prendre ses matériaux et son éclairage ici.

| Fichier | Rôle | Référence SS |
|---|---|---|
| `shaders/ss_toon.gdshader` | Toon deux tons BC (éclairé) / SC (ombre), seuil dur, brush d'ombre « UC » (taches + hachures), rim | `M_CustChara` / `MI_CHR_Base` (MSM_NarutoShadeChr), `T_SHD_TypeD_UC` |
| `shaders/ss_outline.gdshader` | Outline inverted hull des persos, épaisseur constante à l'écran | `/Game/NarutoShading/M_Line` (DistanceScale -0.1, FOV, ObjectScale) |
| `shaders/ss_post_outline.gdshader` | Lignes post-process (cassures de profondeur + plis de normales), fondu 80–200 m | `M_N1Outline_code`, `MI_N1OutlineEnv_*` (ENV_Threshold 0.4–0.5, ENV_Alpha_NFP) |
| `shaders/ss_sky.gdshader` | Ciel anime : dégradé, nuages plats deux tons, soleil dur | couleurs du height fog Konoha |
| `ss_env_presets.gd` | Presets lumière / brouillard / grading par village | `LM_KonohaVillage_BORUTO_Environments_Light` / `_Postprocess`, `LUT_*` |
| `ss_graphics.gd` | API : `character_material`, `prop_material`, `foliage_material`, `shade_of`, `build_environment`, `configure_sun`, `attach_post_outline`, `convert_tree` | paires BC→SC mesurées sur `T_CHR_Naruto_BC/SC` |
| `ss_stage.gd` | Nœud à poser dans une scène faite à la main : applique un preset + convertit ses StandardMaterial3D | — |

## Assets Shinobi Striker locaux

Les textures SS (brush d'ombre, sols/murs de Konoha et de la forêt, LUT) sont lues **à l'exécution**
depuis `res://_SS_REFERENCE/extracted/` (dossier local, ignoré par Git, avec un `.gdignore` pour que
l'éditeur ne l'importe pas). Rien n'est copié dans le projet. Sans ce dossier (clone neuf, build
exporté), `SSGraphics` bascule sur des textures procédurales : le jeu tourne toujours.

Pour ajouter une texture : l'extraire avec `shinobi_extract` (ou `_SS_REFERENCE\tools\ss.cmd extract`),
puis ajouter son chemin dans `SSGraphics.TEXTURES` (et sa taille de répétition dans `TEXTURE_TILE`).

## Assets SS convertis (`_ss_local/`, versionné)

`_ss_local/` (persos, pièces du créateur, décors, VFX convertis) **est versionné** dans le dépôt GitHub
privé (voir `CLAUDE.md`) et embarqué dans le build du jeu, dont le téléchargement est protégé par mot de
passe (usage perso). Le preset d'export n'embarque pas les outils de conversion : scènes `_probe`
(`_ss_local/_*.gd`, `_ss_local/_*.tscn`), `kit.txt`, scripts `*.ps1` et `_ss_local/creator/tables/`.
Seuls les dossiers de travail (`_SS_REFERENCE/`, `.data/`, `ss_dumps/`, `Logs/`) restent locaux.

## Vrais personnages Shinobi Striker

Les persos sont les **vrais meshes SS** (squelette, skinning, animations, palettes BC/SC d'origine),
convertis depuis la copie Steam par la commande ajoutée à l'outil local :

```
_SS_REFERENCE\tools\ShinobiStrikerReader\build_tool\bin\nsdump.exe glb <dossier>\<id>.glb "figur:Naruto Uzumaki" <dossier>\anims.txt
nsdump glbfigur <filtre>                 # figures et pièces (avatars du créateur inclus)
nsdump glbanims <squelette> [filtre]     # clips d'un squelette
```

Sortie dans `res://_ss_local/characters/<id>/` (versionné) : `<id>.glb`, textures `tex/`, et
`<id>.glb.ss.json` (matériaux toon). `anims.txt` associe un clip SS à un nom de pose du jeu
(`idle`, `run`, `jab`, `guard`…). `SSCharacters` charge le GLB, `ShinobiModel` l'utilise à la place
des primitives (`ShinobiLook.ss_model`, vide = avatar du créateur `avatar_male`). Sans fichiers
locaux, retour automatique aux primitives.

## Créateur de personnage Shinobi Striker

`_ss_local\creator\` : tables du créateur extraites (`tables\DT_Custom*.txt`, `DT_PartsColors`),
`build_catalog.ps1` → `catalog.json`, `export_creator.ps1` → `parts\` (corps `SK_CHR_Face` + clips,
coiffures / hauts / bas non teintés avec leur masque `ColorMask_RGB`). `SSAvatars` assemble un
avatar (pièces greffées sur le squelette du corps, os en plus ajoutés au repos) et applique la
teinte SS dans `ss_character.gdshader` (R peau, G couleur 0, B couleur 1). L'apparence est un
dictionnaire cosmétique (`CharacterProfile.appearance`, action `set_appearance`, validé par
`sanitize_appearance`) ; l'onglet **Apparence** de l'écran SHINOBI l'édite. Les mobs reçoivent un
avatar SS stable par type (`MobCatalog`), le joueur sans apparence un avatar stable par profil.

## Vrais décors Shinobi Striker

`nsdump glbstatic <ziel.glb> <StaticMesh> [texOrdner]` décode un StaticMesh SS (LOD0, palette BC,
teinte `AA_BaseMixColor` / `AA_ShadowColor`) en GLB centré, base à y = 0. Le kit Konoha se
réexporte avec `_ss_local\export_env.ps1` (liste dans `_ss_local\env\konoha\kit.txt`). `SSProps`
charge ces meshes ; `WorldDecor` les utilise pour le visuel du village (porte de Konoha, maisons,
résidence du Hokage, murs, échoppes, lanternes, caisses…) et des terrains de chasse (kit `forest` :

arbres du village de Konoha, rochers moussus, buissons, herbes et fleurs de la forêt de Konoha). Les sols
utilisent les vrais matériaux SS en UV monde (`SSProps.ground_material` : terre et dalles de Konoha,
sol de l'arène de la forêt). **Les collisions restent celles des
primitives**, identiques avec ou sans assets locaux (serveur et autres joueurs non affectés).

## Utilisation

```gdscript
mesh.material = SSGraphics.character_material(look.hair_color)      # perso (outline inclus)
mi.material_override = SSGraphics.prop_material(color, &"wood")    # prop texturé SS
world_env.environment = SSGraphics.build_environment(SSEnvPresets.KONOHA_DAY)
SSGraphics.configure_sun(sun, SSEnvPresets.KONOHA_DAY)
```

Les couleurs d'ombre viennent de `SSGraphics.shade_of()` : une couleur identique à une pastille de la
palette SS de Naruto reprend exactement son ombre SS ; sinon une règle calée sur ces paires est appliquée
(teintes chaudes → plus rouges et saturées, blancs → gris bleuté, couleurs sombres plus profondes).
