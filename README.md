# Ninja Battle

Competitive top-down arena brawler (Battlerite-like) in the Naruto universe. Godot 4.3, typed GDScript.
Gameplay first, placeholder visuals (capsules, cubes, debug shapes).

## Play
Open the folder in Godot 4.3+ and press F5 (main scene: character select).

Modes: **1v1 vs bot**, **2v2 (you + bot ally) vs 2 bots**. Best of 5 (first to 3 rounds), no respawn.

| Input | Action |
|---|---|
| WASD / ZQSD (physical keys) | Move |
| Mouse | Aim / facing |
| LMB / RMB / Space / Q(A on AZERTY) / E / R | Jutsu slots (R = ultimate, 100 energy). Hold LMB to keep attacking |
| F (hold) | Guard: frontal hits deal 30% and no CC, slower movement; breaks after 45 blocked damage |
| F + LMB | Perfect parry (0.22 s window): an enemy basic attack is negated and its attacker stunned 1.2 s |
| X or middle mouse | Cancel during startup (feint) |
| F1 / F2 / F3 | Debug overlay / aim line / collision shapes |
| F6 / F7 / F8 | Cheats: infinite HP / infinite energy / no cooldowns |
| F5 / Esc | Restart match / back to menu |

## Combat rules
- Inputs are buffered for 0.25 s; the next hit of a combo can cut the previous recovery short,
  and mobility / counters cancel any attack recovery.
- Knockbacks that end in a wall (arena wall, rock, sand wall) slam: 6 damage + 0.6 s stun.
- Stuns landing within 2 s of a previous stun last half as long (no endless stun chains).
- Chakra orb: appears at the centre 10 s into a round (respawns 22 s after being taken).
  The fighter landing the last hit heals 20 (true heal) and gains 25 energy.
- Sudden death: from 1:00 a ring closes on the centre over 35 s; outside it you take 12 dps.
- Enemy casts show a red telegraph on the ground and a cast bar above their head.

## Roster
- **Naruto** — pressure: Taijutsu, Rasengan (dash strike), Shunshin, Kawarimi (counter-teleport), Kage Bunshin Rush (stun), Rasenshuriken.
- **Sasuke** — midrange: Kunai, Katon, Shunshin, Sharingan Counter (stuns attacker), Chidori, Kirin (delayed area).
- **Sakura** — bruiser/healer: Chakra Punch, Ōkashō (stun area), Leap, Mystical Palm (recoverable heal), Shannarō Kick (knockback), Byakugō (true heal).
- **Kakashi** — technical: Kunai, Raikiri, Shunshin, Kawarimi, Ninken (root area), Kamui (delayed area).

## Architecture
- `characters/base/combat_character.gd` — composition root + central damage pipeline (`receive_hit`).
- `core/abilities/` — `AbilityData` (frame data, costs, hit props), `AbilityController` (STARTUP→ACTIVE→RECOVERY, cooldowns, input buffer, cancel/interrupt), `AbilityEffects` (generic executors per kind).
- `core/status_effects/status_controller.gd` — single source of truth for Stun/Root/Immaterial/Counter.
- `core/combat/health_component.gd` — current / max / recoverable health.
- `core/input/` — `IntentSource` → `GameplayIntent`; player and bot share the same path.
- `core/ai/bot_controller.gd`, `core/match/match_manager.gd`, `ui/hud/`, `ui/menu/`.
- All balancing lives in `characters/<name>/<name>_data.tres` (editable in the inspector).

## Tests
```
godot --headless --fixed-fps 60 --path . res://tests/smoke_test.tscn
```
Unit checks (health, energy, statuses, Kawarimi, interrupt, feint) + a full 2v2 bot match.

## Online
Dedicated, server-authoritative: the server simulates every fighter, clients send inputs and
mirror 30 Hz snapshots; the local fighter's movement is predicted and reconciled.

```
# 1v1 server (UDP 7777) and 2v2 server (UDP 7778)
godot --headless --path . -- --server --mode=1v1 --port=7777
godot --headless --path . -- --server --mode=2v2 --port=7778
```
In game: menu → Online → server address → "Online 1v1" / "Online 2v2". Players queue; a match starts
when 2 (1v1) or 4 (2v2) players are waiting. A player who disconnects is replaced by a bot.

Dev autopilot (headless bot clients, used for network tests):
```
godot --headless --path . -- --autojoin=127.0.0.1 --mode=1v1 --bot-client --quit-after-match
```
