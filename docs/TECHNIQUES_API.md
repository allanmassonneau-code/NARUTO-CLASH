# Techniques — API des kits (bible de game design)

> **Kits Shinobi Striker.** Tous les sorts sont de vrais jutsu de Naruto Shinobi Striker. La répartition est
> dans `tools/ss_kits.txt` (kit, rang, ID SS) ; `powershell -File tools\ss_kits.ps1` écrit
> `data/progression/content.json` (noms et descriptions SS en français, recharges SS),
> `data/progression/ss_jutsu.json` (données SS utilisées) et `data/progression/ss_kit_assets.json` (icône, dossier
> SS, type : lus par `SSIcons`, `SSAudio`). Puis `godot --headless --path . -s tools/build_progression_db.gd`.
> Les fiches par kit (`tools/ss_kit_briefs/<kit>.md`) décrivent chaque jutsu à coder. `tools/progression_content.py`
> (ancienne bible) n'est plus la source des sorts : ne pas le relancer sans réappliquer `ss_kits.ps1`.

Chaque technique de la bible (`docs/BIBLE_JUTSU.md`) est un script. Un fichier par kit :
`content/techniques/natures/<nature>.gd`, `content/techniques/clans/<clan>.gd`,
`content/techniques/sub_jutsu/rank_<b|a|s>.gd` (listés dans `content/techniques/technique_index.gd`).
Référence complète et commentée : **`content/techniques/natures/katon.gd`**.

```gdscript
extends RefCounted
const KIT_ID := &"katon"            # nature id, "clan_<id>", ou "sub_rank_b"...
const SIGNATURE = null              # ou une classe interne `extends KitSignature`
const TECHNIQUES := {&"katon_d_braise_tracante": BraiseTracante, ...}  # ids = data/progression/bible.json

class K:                            # règles partagées du kit (static func)
class BraiseTracante extends Technique:
	func configure(a: AbilityData) -> void:   # frame data : startup_time, recovery_time, cast_move_multiplier,
		a.startup_time = 0.12                  # max_range (= portée de visée), anim (jab, hook, kick, slash, thrust,
		a.anim = &"throw"                      # palm, chidori, seal, breath, stomp, throw, guard, heal, dash, leap)
	func cast(t: Tk) -> void:                 # au moment où le sort sort
		...
```

Chakra et cooldown viennent de la bible (provisoires par rang) ; `configure` peut changer `a.cooldown`.
Une technique ne doit jamais planter : vérifier `is_instance_valid` / `t.is_enemy(e)` dans les callbacks différés.

## `Tk` (core/techniques/tk.gd)
Champs : `caster`, `dir` (direction verrouillée), `aim` (point visé, borné à max_range), `origin`, `rank`, `color`, `id`.
- Nombres : `t.dmg(mult)` = dégâts de base du rang (12/16/22/30/42) × mult × bonus. Toujours relatif.
- Requêtes : `enemies_in(c, r)`, `allies_in(c, r, self?)`, `nearest_enemy(c, r)`, `target_at_aim(r)`,
  `enemies_in_cone(from, dir, len, deg)`, `enemies_in_line(from, dir, len, width)`, `is_enemy`, `is_ally`,
  `distance(a, b)`, `clear_point(from, dir, dist)`, `fighters()`.
- Coups : `hit(e, dmg, opts)` — opts : `stun, root, slow, silence, burn, genjutsu, seal` (secondes), `push` (m),
  `push_from`, `launch` (s), `unblockable`. Passe par tout le pipeline (garde, parade, contre, substitution).
  `area(c, r, dmg, opts)`, `cone(len, deg, dmg, opts[, from, dir])`, `line(len, width, dmg, opts[, from, dir])`,
  `melee(reach, deg, dmg, opts)` → renvoient les ennemis touchés.
  `heal(f, n)`, `shield(f, n, s)`, `status(f, StatusController.Type.X, s)`, `cleanse(f, hard)`.
- Déplacements forcés : `push(f, dir, dist)`, `pull(f, point, dist)`, `launch(f, s)` (ténacité : ×0.25, pas de launch),
  `dash(dist, dir, duration, immaterial)` (lanceur), `blink(point[, who])`.
- Objets : `object(c, opts)`, `zone(c, r, life, opts)`, `wall(c, dir, len, life, opts)`, `telegraph(c, r, delay, fn(t))`,
  `tether(target, max_dist, life, {on_tick, on_break, interval})`, `clone(at, s)`, `objects(kind, technique)`
  (par défaut ceux de cette technique, `&""` = toutes les techniques du lanceur).
  opts objet : `radius, lifetime, health (-1 indestructible), look (KitObject.Look.DISC/RING/WALL/PILLAR/ORB/DECOY/GLYPH/NONE),
  kind, color, blocks_projectiles, blocks_movement, targetable, tick_interval, data,
  on_enter(f, o), on_exit(f, o), on_tick(o), on_expire(o), on_destroy(o, reason), on_projectile(team, point) -> bool`.
- Projectiles : `projectile(opts)` → `TkProjectile` : `speed, range, radius, dir, from, pierce, homing (rad/s), homing_target,
  lob_to (cloche jusqu'au point), hit_in_flight, hits_allies, size, color, data,
  on_hit(e, p) -> bool (true = continue), on_end(point, p, reason), on_tick(p, dt)`. `p.end("recast")`, `p.ground_point()`,
  `p.direction` modifiable (rebond, guidage).
- Temps : `after(s, fn(t))`, `channel(n, interval, pulse(t, i), done(t, completed), move_mult)`,
  `recast(window, fn(t)[, on_expire])` (2e appui gratuit).
- État de kit : `mark(e, key, stacks, s, max, label)`, `marks(e, key)`, `consume_mark(e, key)` ;
  ressources du lanceur `res/add_res/spend_res/take_all_res(key)` (déclarées dans la signature : `fighter.kit.define_resource(key, max, label, color, decay)`) ;
  `buff(key, s, props)` / `debuff(e, key, s, props)` — props : `damage_dealt, damage_taken, heal_taken, speed, basic_damage, chakra_regen`
  (multiplicateurs), `lifesteal` (fraction), `tenacity, cc_immune, untargetable` (flags), `uses`,
  `on_deal(target, hit, dmg) -> float?`, `on_take(hit, dmg) -> float?`, `on_tick(dt)`, `on_end()`, `label, color` (HUD).
- Retour visuel : `fx(name, at, radius[, color])` avec name ∈ burst, explosion, wave, spikes, column, implosion, bolt,
  cracks, rocks, smoke, dust, crows, ember, spheres, ring, sparks ; `text(f, "MOT")`.

## Signature (`KitSignature`)
`setup(f)` (déclarer les ressources), `tick(f, dt)`, `on_deal(f, target, hit, dmg) -> float?`, `on_take(f, hit, dmg) -> float?`.
Active pour tout combattant dont `data.kits` contient `KIT_ID` (clan + natures du profil).

## Approximations autorisées (vue du dessus, jeu local)
Vision / brouillard / illusions côté client → debuffs lisibles (`slow`, `silence`, `genjutsu`, modifiers étiquetés) ;
« charger » → `startup_time` plus long ; invocations → objets / `clone`. Garder l'identité de la mécanique décrite.

## Tests
`godot --headless --fixed-fps 60 --path . res://tests/techniques_test.tscn -- kit=<id>` : lance chaque technique contre
deux mannequins (recast compris) ; exige un effet observable et **aucun `SCRIPT ERROR`** dans la sortie.
