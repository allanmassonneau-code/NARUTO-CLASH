# Passer NARUTO-CLASH sur Unreal Engine 5 — tuto complet

Ce guide explique ce qui se transfère tel quel, ce qu'il faut refaire, dans quel ordre, et comment on
travaille ensemble (toi + Claude) sur un projet UE5.

---

## 0. Ce qu'il faut savoir avant de commencer

| Ce qu'on a aujourd'hui (Godot) | Sur UE5 |
|---|---|
| Modèles GLB (persos SS, créateur, décors Konoha, Storm convertis) | **Réutilisables** : UE5 importe le GLB (glTF) directement |
| Textures PNG, sons WAV, musiques | **Réutilisables** tels quels |
| Données (`content.json`, `ss_jutsu.json`, catalogues) | **Réutilisables** : importées en DataTables / DataAssets |
| Code GDScript (combat, 180 sorts, progression, réseau, UI) | **À réécrire** en C++ / Blueprint (la logique et les règles restent, le code non) |
| Shaders Godot (toon SS, contours, VFX) | **À refaire** en matériaux UE5 + Niagara |
| Scènes `.tscn` (monde, menus) | **À reconstruire** dans l'éditeur UE5 |

En clair : **les assets et le game design passent, le code et les scènes se refont**. Le travail de
design (kits SS, mécaniques, progression, équilibrage) est le plus précieux et il est entièrement conservé
(dans `content.json`, `tools/ss_kits.txt`, les fiches `tools/ss_kit_briefs/` et le code actuel qui sert de
spécification).

Point important : Shinobi Striker tourne sous **UE 4.16**, mais ses fichiers sont « cuits » pour le jeu :
on ne peut pas les ouvrir directement dans un éditeur UE5. Il faut toujours passer par l'export
(`nsdump glb`, FModel…) — exactement ce qu'on fait déjà.

Rappel : ces assets (SS, Storm) viennent de jeux commerciaux. Usage privé uniquement, pas de distribution
publique du jeu ni des assets.

---

## 1. Installer l'environnement

1. **Epic Games Launcher** → onglet Unreal Engine → Bibliothèque → installer **UE 5.5** (ou la dernière 5.x).
   Cocher « Editor symbols for debugging » si tu veux déboguer le C++.
2. **Visual Studio 2022** (déjà installé sur ton PC) : dans le Visual Studio Installer, ajouter la charge de
   travail **« Développement de jeux en C++ »** + le composant **« Unreal Engine installer »**, le
   **.NET Framework 4.8 SDK** et un **Windows SDK 10/11** récent.
3. (Optionnel, recommandé) **JetBrains Rider** : plus confortable que VS pour Unreal, mais pas obligatoire.
4. **Git LFS** : un projet UE5 est plein de fichiers binaires lourds (`.uasset`, `.umap`). Sur GitHub il faut
   activer Git LFS (`git lfs install`, puis `git lfs track "*.uasset" "*.umap"`). Attention au quota LFS de
   GitHub (stockage et bande passante payants au-delà de quelques Go) : pour un gros projet, **Perforce**
   (gratuit jusqu'à 5 utilisateurs) ou **Azure DevOps** (LFS illimité) sont plus adaptés.
5. Pour un **serveur dédié** (multijoueur en ligne), il faudra plus tard compiler **UE5 depuis les sources**
   (GitHub d'Epic, compte Epic lié) : la version du launcher ne fait pas de build serveur.

---

## 2. Créer le projet

1. Lancer UE5 → **Games** → template **Third Person** → **C++** (pas Blueprint seul) → nom `NarutoClash`.
   Le C++ est indispensable pour le système de sorts et le multijoueur ; on garde les Blueprints pour le
   contenu et les réglages.
2. Activer les plugins (Edit → Plugins) :
   - **Gameplay Abilities** (GAS : la base des sorts, voir §5) ;
   - **glTF Importer** / **Interchange** (import GLB, normalement actif) ;
   - **Python Editor Script Plugin** + **Editor Scripting Utilities** (automatisation, voir §9) ;
   - **Niagara** (VFX), **Enhanced Input**, **Common UI** (menus), **Online Subsystem** (réseau).
3. Arborescence conseillée dans `Content/` :
   ```
   Content/
     Characters/   Avatar SS (créateur), PNJ, mobs, boss
     Animations/   squelette commun + clips retargetés
     Jutsu/        un dossier par kit : Katon/, Suiton/, Clans/Sabaku/…, Sub/
     VFX/          Niagara + textures SS
     Audio/        sfx, musiques, ambiances
     Environment/  Konoha, forêt, autres villages
     UI/           widgets, icônes SS
     Data/         DataTables (jutsu, kits, progression)
   ```

---

## 3. Importer les assets

### 3.1 Modèles et animations (GLB)
- Glisser le `.glb` dans le Content Browser (ou **Import**). UE crée : Skeletal Mesh, Skeleton, Physics
  Asset, matériaux, textures et les animations (AnimSequence) contenues dans le GLB.
- Échelle : nos GLB sont en mètres, UE5 travaille en centimètres → l'importeur convertit (sinon *Import
  Uniform Scale* = 100).
- Sources :
  - Persos SS / créateur : `_ss_local/characters/`, `_ss_local/creator/parts/` (corps + pièces sur le même
    squelette `SK_CHR_Face`).
  - Persos Storm : `D:\games\STOCK NARUTO CLASH\Export_Godot\<jeu>\Personnages\…` (le nom « Godot » du
    dossier n'a pas d'importance, ce sont des GLB standards).
  - Décors : `_ss_local/env/…` et `Export_Godot\<jeu>\Decors\`.

### 3.2 Un seul squelette pour tout le monde (retargeting)
SS et Storm n'ont pas le même squelette. UE5 a un outil pour ça :
1. Créer un **IK Rig** pour chaque squelette (SS avatar, Storm).
2. Créer un **IK Retargeter** source → cible.
3. Exporter les animations Storm (jutsu, ultimes, combos) **vers le squelette de l'avatar SS**.
Résultat : l'avatar du créateur peut jouer les 118 animations du Naruto de Storm, etc.

### 3.3 Textures, sons, musiques
- PNG → glisser-déposer (Texture2D). Icônes : `_ss_local/icons/`.
- WAV → glisser-déposer (Sound Wave). Sons : `_ss_local/sfx/`, musiques `_ss_local/music/`.
  Les boucles (musiques, ambiances) : cocher *Looping*.

### 3.4 Données
- `data/progression/content.json` et `ss_jutsu.json` → convertis en CSV/JSON au format DataTable
  (un script Python le fait, §9), puis **DataTable** avec une structure C++ `FJutsuRow` (id, nom,
  description, rang, kit, chakra, recharge, icône, type SS…).

---

## 4. Rendu « Shinobi Striker » (cel-shading)

À refaire en matériaux UE5 (ce qu'on a codé dans `core/graphics/shaders/` sert de modèle) :
- **Matériau toon perso** : deux tons BC (éclairé) / SC (ombre) avec seuil dur, brush d'ombre (texture UC),
  masque `ColorMask_RGB` pour teindre peau / couleur 0 / couleur 1 (créateur).
- **Contours** : inverted hull (matériau sur une copie du mesh poussée le long des normales) pour les persos,
  et un **post-process** (profondeur + normales) pour les décors.
- **Ciel / lumière** : Sky Atmosphere + Exponential Height Fog + couleurs du preset Konoha
  (`core/graphics/ss_env_presets.gd`).
- Astuce : en UE5, désactiver Lumen et passer en éclairage plus simple donne un rendu plus « anime » et
  beaucoup plus de FPS.

---

## 5. Le combat et les 180 sorts : Gameplay Ability System (GAS)

GAS est le système d'Epic pour exactement ce qu'on a : compétences, coûts, recharges, buffs, statuts,
réseau. Correspondances avec le code actuel :

| Godot (actuel) | UE5 / GAS |
|---|---|
| `CombatCharacter` | `ACharacter` + `UAbilitySystemComponent` |
| Santé / chakra / endurance (`health`, `energy`) | `UAttributeSet` (Health, Chakra, Stamina, Shield) |
| `AbilityData` (startup, recovery, cooldown, coût) | `UGameplayAbility` + Montage + `GameplayEffect` de coût/recharge |
| Statuts (stun, root, slow, silence…) | **Gameplay Tags** (`Status.Stun`…) + `GameplayEffect` à durée |
| Buffs / debuffs (`t.buff`, `damage_taken`, `heal_taken`) | `GameplayEffect` avec modificateurs d'attributs |
| `Tk` (API des kits : `hit`, `area`, `projectile`, `zone`, `recast`…) | Une bibliothèque C++ `UJutsuLibrary` + des **Ability Tasks** |
| Projectiles `TkProjectile` | Acteurs `AJutsuProjectile` (Projectile Movement Component) |
| Zones / murs / clones `KitObject` | Acteurs `AJutsuZone`, `AJutsuWall`… |
| Kits (`content/techniques/*.gd`) | Une classe d'Ability (C++ ou Blueprint) par sort, regroupées par kit dans un DataAsset |

Méthode conseillée :
1. Écrire en C++ la base : AttributeSet, les statuts (tags), `UJutsuLibrary` (équivalent de `Tk`),
   projectiles et zones génériques.
2. Recréer chaque sort comme une Gameplay Ability, en reprenant **la logique du fichier GDScript actuel**
   (même mécanique, mêmes multiplicateurs).
3. Animations de sort = **Anim Montages** (avec *Anim Notifies* au moment où le sort « sort »).

---

## 6. Multijoueur

- UE5 gère la réplication nativement (acteurs, propriétés, RPC) et GAS est conçu pour le réseau
  (prédiction côté client).
- Modèle : serveur autoritaire (comme aujourd'hui avec Godot), un **serveur dédié** pour le monde partagé.
- Comptes / sauvegarde : aujourd'hui `core/net/account_store.gd` + profils JSON ; sur UE5 on garde un petit
  backend (le même) ou on passe à un service (EOS — Epic Online Services, gratuit).

---

## 7. Monde, UI, audio, VFX

- **Monde** : World Partition pour le monde ouvert (village + terrains de chasse), Landscape pour le sol,
  les props SS/Storm placés à la main ou par script (on a déjà les positions du village dans
  `world/world_decor.gd`).
- **UI** : UMG + Common UI ; écran SHINOBI, créateur, HUD et menu des techniques à refaire en widgets
  (icônes SS déjà prêtes).
- **Audio** : Sound Cues ou **MetaSounds** ; reprendre les règles de `core/fx/ss_audio.gd` (son de lancement
  / d'impact par jutsu, pas selon le sol, musique par zone).
- **VFX** : **Niagara**, avec les flipbooks SS (`_ss_local/vfx/`) ; les profils par élément
  (`core/graphics/ss_vfx_profiles.gd`) donnent la recette de chaque sort.

---

## 8. Plan de migration (ordre conseillé)

| Étape | Contenu | Résultat |
|---|---|---|
| 1 | Projet C++ + plugins + Git LFS / Perforce | Projet vide qui compile |
| 2 | Import de l'avatar SS + squelette + animations de base | Perso jouable qui court / saute |
| 3 | Matériau toon + contours | Look Shinobi Striker |
| 4 | GAS : attributs, statuts, taijutsu, dash, substitution | Combat de base |
| 5 | `UJutsuLibrary` + 1 kit complet (Katon) | Premier kit jouable, valide la méthode |
| 6 | Les 27 autres kits (en parallèle, kit par kit) | 180 sorts |
| 7 | Créateur de personnage + progression (DataTables) | Boucle de progression |
| 8 | Village de Konoha + terrains de chasse + mobs | Monde ouvert |
| 9 | Multijoueur + serveur dédié + comptes | En ligne |
| 10 | UI, audio, VFX Niagara, optimisation | Version complète |

Compter plusieurs semaines à plusieurs mois selon le temps passé. Le plus long : les 180 sorts (étape 6) et
le multijoueur (étape 9).

---

## 9. Comment Claude développe sous UE5

Ce que je peux faire seul, depuis ce PC :
- **Écrire et compiler le C++** : classes (personnage, GAS, sorts, projectiles, réseau), et compiler en ligne de
  commande avec `Build.bat` / UnrealBuildTool, lire les erreurs et corriger.
- **Automatiser l'éditeur en Python** (`UnrealEditor-Cmd.exe <projet> -run=pythonscript -script=…`) :
  import en masse des GLB / PNG / WAV, création des DataTables depuis `content.json`, création de
  matériaux et d'instances, placement d'objets dans une map.
- **Lancer les tests** sans fenêtre : `UnrealEditor-Cmd.exe <projet> -ExecCmds="Automation RunTests NarutoClash" -unattended -nullrhi`
  (équivalent de nos `tests/*.tscn` actuels), et des **captures d'écran** du jeu pour vérifier le rendu
  (`-game` + `HighResShot`).
- **Configurer** le projet (`Config/*.ini`), les inputs, le réseau, les builds (packaging en ligne de
  commande avec `RunUAT BuildCookRun`).
- **Convertir les assets** SS / Storm comme maintenant (nsdump, ton convertisseur XFBIN).

Ce qui est plus difficile pour moi :
- **Les graphes Blueprint** sont des fichiers binaires : je ne peux pas les écrire « à la main » comme du
  code. Solution : je mets la logique en C++ et j'expose des propriétés éditables ; les Blueprints ne servent
  qu'à régler des valeurs ou brancher des assets (ce que je peux aussi faire par script Python).
- **Le travail visuel fin** dans l'éditeur (placer un décor à l'œil, régler une animation) : je peux le faire
  par script et vérifier par captures, mais toi dans l'éditeur tu iras plus vite pour ces retouches.

Organisation qui marche bien :
1. Je code un système en C++ + un script Python qui crée les assets, je compile et je teste.
2. Tu ouvres l'éditeur, tu testes en jeu et tu me dis ce qui ne va pas (captures bienvenues).
3. Les gros lots (les 28 kits) se font en parallèle, un kit par session ou par agent, comme on l'a fait sur
  Godot.

---

## 10. Ce que je recommande pour démarrer

1. Installer UE 5.5 + Visual Studio (charge « jeux en C++ »).
2. Me dire où créer le projet (par ex. `D:\PROJET NARUTO JEU SOZIN\NARUTO-CLASH-UE5`) et quel hébergement
   (GitHub + LFS, ou Perforce).
3. Je crée le projet C++, j'importe l'avatar SS et ses animations, et on valide ensemble le perso jouable
   avec le rendu toon (étapes 1 à 3). Ensuite on attaque le combat.
4. Le projet Godot actuel reste la **référence** (règles, valeurs, mécaniques) pendant toute la migration.
