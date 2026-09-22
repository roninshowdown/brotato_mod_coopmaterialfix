# CoopMaterialFix

Brotato mod: makes negative character material-drop modifiers personal in
co-op instead of penalizing the whole party.

Version: 1.3.0
Target: Brotato 1.1.15.4 / ModLoader 6.2

Status: working, deployed, in live use.

## The problem

Vanilla computes world material value from party-averaged material-drop
effects. If one character has a negative `gold_drops` or `enemy_gold_drops`
modifier (e.g. Streamer, Fisherman), the whole co-op party loses materials —
not just that character.

## The fix

Negative CHARACTER-owned `gold_drops` / `enemy_gold_drops` effects are
temporarily removed while a real world material drop is calculated, then
re-applied only to the affected character's own final per-player share.
Vanilla still performs picker-specific value changes, Metal Detector,
round-robin co-op splitting, and XP gain unchanged.

Material nodes are tagged by origin (enemy / neutral-tree / other) so
enemy-only penalties (Fisherman) never bleed onto tree/neutral materials,
regardless of who lands the kill.

Full mechanism, edge-case audit, and compatibility notes:
[`mods-unpacked/YourName-CoopMaterialFix/README.md`](mods-unpacked/YourName-CoopMaterialFix/README.md)

## Repo layout

```
mods-unpacked/YourName-CoopMaterialFix/   mod source (ModLoader 6.2 layout)
  manifest.json
  mod_main.gd
  extensions/
    main.gd                     world-drop value adjustment, gold source bookkeeping
    singletons/run_data.gd       personal penalty + pickup capture/re-add
    items/global/effect_line.gd  UI label via Effect.get_text
makezip.py                       packages mods-unpacked/ into a distributable zip
```

## Install (local test)

1. Steam -> Brotato -> Manage -> Browse local files.
2. Close Brotato completely.
3. Copy `mods-unpacked/YourName-CoopMaterialFix/` into the Brotato game root, so
   this path exists:
   `Brotato/mods-unpacked/YourName-CoopMaterialFix/manifest.json`
4. Launch Brotato -> Mods -> enable CoopMaterialFix -> restart.

Logs on failure: `%APPDATA%\Brotato\logs\modloader.log`, `godot.log`.
