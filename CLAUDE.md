# CLAUDE.md

## Références Shinobi Striker

Le système de référence Shinobi Striker est documenté dans `_SS_REFERENCE\Claude\README.md`.

- `_SS_REFERENCE` (outils d'extraction, index, FModel, extractions brutes) reste **LOCAL ONLY** et ignoré par Git :
  ne jamais le commiter.
- Pour rechercher, inspecter et extraire des références Shinobi Striker, utiliser les outils de `_SS_REFERENCE\tools\`
  (`ss.cmd search | inspect | extract`) plutôt que faire des extractions massives.

## Assets Shinobi Striker du jeu (`_ss_local`)

- Les assets SS **convertis pour le jeu** (persos, pièces du créateur, décors, VFX) vivent dans `_ss_local/` et
  **sont versionnés** dans le dépôt GitHub (privé, non distribué au public). Les ajouter / commiter normalement.
- Conversion : `nsdump glb | glbstatic | glbmat` (voir `core/graphics/README.md`), scripts `_ss_local\export_env.ps1`
  et `_ss_local\creator\export_creator.ps1`.
- Ne jamais commiter les dossiers de travail locaux : `_SS_REFERENCE/`, `.data/`, `ss_dumps/`, `Logs/`.
