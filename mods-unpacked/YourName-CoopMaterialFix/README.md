# Coop Material Fix for Brotato

Version: 1.3.0  
Target: Brotato 1.1.15.4 / ModLoader 6.x

## What v1.2 fixes

Negative character material-drop effects are personal in co-op:

- `gold_drops` (for example `-50% materials dropped`)
- `enemy_gold_drops` (for example `-50% materials dropped from enemies`)

A teammate no longer loses materials because another character owns one of these
negative effects.

The affected CHARACTER description line is also labelled:

- `-50% materials dropped (only applies to you)`
- `-50% materials dropped from enemies (only applies to you)`

The label is intentionally added at `Effect.get_text()`, the single shared choke
point used by both the base game (`EffectLine._display_effect`) and other mods'
tooltip systems (e.g. ImprovedTooltips). Only negative material-drop effects
authored on characters are ever displayed by that system, which keeps the label
character-only by construction; an item or third-party mod that happens to use
a negative `gold_drops` key is not falsely labelled.

## Intended examples

Streamer + normal character:
- normal character receives a normal share
- Streamer receives the share implied by Streamer's own negative `gold_drops`

Fisherman + normal character:
- enemy material drops are created without Fisherman's personal negative effect
- normal character receives a normal enemy-material share
- Fisherman's own enemy-material share receives Fisherman's penalty
- tree/neutral materials do NOT receive Fisherman's enemy-only penalty
- it does not matter who killed the enemy

## How it works

Vanilla computes world material value from party-averaged material-drop effects.
v1.2 temporarily removes only the negative CHARACTER-owned `gold_drops` /
`enemy_gold_drops` part while a real world material drop is calculated.

The material node is tagged internally with its origin:
- enemy
- neutral/tree
- other

When the material is collected, vanilla still performs:
- picker-specific material value changes
- Metal Detector / double-material logic
- vanilla round-robin co-op splitting
- normal XP Gain after add_xp

The mod captures only the final per-player material/XP share and applies the
affected character's removed negative modifier to that player's share.

Fractional results are carried over. A 50% penalty on repeated 1-material shares
therefore behaves like a true 50% over time instead of truncating every pickup to 0.

## Builder / uncollected materials

This is fixed by the v1.2 architecture.

Because a teammate's personal negative modifier is no longer allowed to delete
materials at world-spawn time, Builder sees the unpenalized shared floor-material
pool. Builder's normal conversion code then runs unchanged.

For correctness of enemy-vs-neutral source tracking across the bonus-material bag,
the mod temporarily uses Brotato's normal end-wave material collection path when
the game's "optimize end waves" option is enabled, then immediately restores the
option. At most 50 active material blobs exist in vanilla.

## Edge-case audit

Covered:
- solo: vanilla behavior (fix bypassed)
- 2-4 player co-op
- one or multiple affected players
- general and enemy-only penalties on the same player
- enemy kill ownership: irrelevant; source is the enemy, not the killer
- trees / neutral units: enemy-only penalty is not applied
- direct non-drop material income (Harvesting, character grants, etc.): untouched
- `get_gold_value()` direct harvesting/charmed-enemy calculation: deliberately untouched
- 1-value pickups: fractional carry preserves the long-run percentage
- 50-material on-ground cap: mixed-source blobs retain exact source composition
- bonus-material bag across waves: source composition is retained
- Builder conversion: receives the unpenalized shared floor pool
- positive material-drop effects: remain shared exactly as vanilla calculates them
- non-character material-drop effects: remain shared
- `neutral_gold_drops`: unchanged / shared
- Metal Detector: still rolled by vanilla before the personal share is applied
- picker `increase_material_value`: still calculated by vanilla first
- XP Gain: still calculated inside vanilla `add_xp()` after the personal material share
- distance-scaled enemy materials: vanilla scaling remains intact
- unit effect-behavior material modifiers: vanilla scaling remains intact
- dead players / vanilla round-robin player indexing: preserved
- unknown/custom material spawns: classified as OTHER, so enemy-only penalties are never guessed

Known compatibility limitations:
- another mod extending the same methods can be load-order sensitive:
  `Main.spawn_loot`, `Main.on_player_wanted_to_spawn_gold`,
  `Main.get_gold_value`, `Main.spawn_gold`, `Main.on_gold_picked_up`,
  `Main.clean_up_room`, `RunData.add_gold`, `RunData.add_xp`,
  `RunData.apply_common_gold_pickup_effects`, or `CharacterData.get_effects_text`
- source composition is runtime bookkeeping; a hypothetical mod that serializes
  active in-wave material nodes without this mod's bookkeeping will fall back to OTHER
- custom mods that create enemy loot by calling `Main.spawn_gold()` directly instead
  of the normal `spawn_loot(..., EntityType.ENEMY, ...)` path are treated as OTHER
- the UI suffix is English-only
- future Brotato versions must be retested before widening the compatible version

## Before publishing

Replace `YourName` in:
- folder name `YourName-CoopMaterialFix`
- `manifest.json`
- `mod_main.gd`

The folder must remain `<namespace>-<name>`.

## Recommended in-game validation matrix

1. Normal + Normal
2. Streamer + Normal
3. Streamer + Streamer
4. Fisherman + Normal
5. Fisherman + Streamer
6. Fisherman + Explorer/Cryptid/Buccaneer
7. Jack (+enemy materials) + Fisherman
8. Streamer + Builder, leaving many materials on the floor
9. Fisherman + Builder, leaving enemy materials on the floor
10. Fisherman + tree-heavy build: tree materials should not be enemy-penalized
11. Let >50 materials accumulate to force blob merging
12. Leave mixed enemy/tree materials uncollected, collect them from the bonus bag next wave
13. Test with "optimize end waves" both enabled and disabled
14. Verify the two UI suffixes
15. Check `%appdata%/Brotato/logs/modloader.log` and `godot.log`


## v1.3.0 correctness update

- `RunData.add_gold` override now matches the vanilla signature exactly:
  `add_gold(value: int, player_index: int)`. Base calls pass exactly two
  arguments. (v1.2 passed three arguments to a two-argument base function,
  which is engine-dependent behavior and could silently break all material
  income depending on the engine build.)
- `add_gold` / `add_xp` batch capture now guards out-of-range player indexes
  and falls back to the vanilla call instead of indexing the batch arrays.
- `_cmf_get_personal_penalty` guards null characters and null effect lists.
- Shared-effect aggregation converts effect values safely so non-numeric
  effect storage (used by some third-party mods) can not poison the math.
- README label note corrected to the actual implementation point
  (`Effect.get_text()`).
- Version bumped consistently to 1.3.0 across zip name, manifest, and code.

## v1.2.2 loader/package update

Uses the current ModLoader 6.2 entrypoint/API style (`_init()`,
`ModLoaderMod.install_script_extension`) and current manifest layout.

For local Steam testing, extract this package into the Brotato game root so this
path exists directly:

`Brotato/mods-unpacked/YourName-CoopMaterialFix/manifest.json`
