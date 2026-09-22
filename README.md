# 🥔 CoopMaterialFix

**Negative material-drop penalties should hurt the character who has them — not your whole co-op party.**

![Version](https://img.shields.io/badge/version-1.3.0-orange)
![Brotato](https://img.shields.io/badge/Brotato-1.1.15.4-c9622f)
![ModLoader](https://img.shields.io/badge/ModLoader-6.2-blue)
![Status](https://img.shields.io/badge/status-working-brightgreen)
![Players](https://img.shields.io/badge/co--op-2--4_players-9b59b6)

---

## 💥 The problem

In vanilla Brotato co-op, a single character's negative material modifier is
applied to the **whole party's** material income — not just that character's.

| Character | Modifier | Vanilla behavior |
|---|---|---|
| 🎥 Streamer | `-50% materials dropped` | **Everyone** drops fewer materials |
| 🎣 Fisherman | `-50% materials from enemies` | **Everyone's** enemy drops shrink |

Play Streamer or Fisherman with a friend, and you're quietly griefing their run.

## ✅ The fix

CoopMaterialFix intercepts the drop calculation, strips out negative
CHARACTER-owned `gold_drops` / `enemy_gold_drops` effects while the *shared*
world material value is computed, then re-applies each penalty **only** to
that character's own final share.

```
🪙 material drops
  ├─ 🧑 Player A (Streamer, -50%)  → penalty applies to A only
  └─ 🧑 Player B (Normal)          → full, unpenalized share
```

Enemy vs. tree/neutral origin is tracked per material node, so Fisherman's
enemy-only penalty never bleeds onto tree drops — no matter who lands the
kill.

```
👹 Enemy killed  → 🪙 drop tagged ENEMY   → Fisherman penalty applies
🌳 Tree chopped  → 🪙 drop tagged NEUTRAL → Fisherman penalty does NOT apply
```

Everything else — Metal Detector, round-robin pickup splitting, XP gain,
Builder's floor-material conversion — runs through **unmodified vanilla
code**, untouched.

## 🏷️ In-game labels

Affected character lines are annotated so the effect is never a mystery:

> `-50% materials dropped` **(only applies to you)**
> `-50% materials dropped from enemies` **(only applies to you)**

## 🧩 Compatibility

| | |
|---|---|
| ✅ Solo | Untouched — fix is a co-op-only code path |
| ✅ 2–4 player co-op | Fully supported |
| ✅ Multiple affected players | Each penalty applies independently |
| ✅ ImprovedTooltips | Chains cleanly (shared `Effect.get_text()` hook) |
| ⚠️ Other `main.gd` / `run_data.gd` extenders | Load-order sensitive — see full audit below |

<details>
<summary>📋 Full edge-case audit (click to expand)</summary>

- 1-value pickups keep fractional carry-over — a 50% penalty stays a true
  50% over time instead of truncating every pickup to 0
- 50-material on-ground cap: mixed-source blobs keep exact source composition
- Bonus-material bag across waves: source composition retained
- Builder conversion receives the unpenalized shared floor pool
- Positive / non-character / `neutral_gold_drops` effects: unaffected, shared as vanilla intends
- Metal Detector and picker `increase_material_value`: still rolled by vanilla first
- XP gain: calculated inside vanilla `add_xp()`, after the personal material share
- Unknown/custom material spawns classified as OTHER — enemy-only penalties never guessed

Full writeup with method-level detail:
[`mods-unpacked/YourName-CoopMaterialFix/README.md`](mods-unpacked/YourName-CoopMaterialFix/README.md)

</details>

## 📦 Repo layout

```
mods-unpacked/YourName-CoopMaterialFix/
├── manifest.json
├── mod_main.gd
└── extensions/
    ├── main.gd                     # world-drop value adjustment, gold source bookkeeping
    ├── singletons/run_data.gd      # personal penalty + pickup capture/re-add
    └── items/global/effect_line.gd # UI label via Effect.get_text
makezip.py                          # packages mods-unpacked/ into a distributable zip
```

## 🚀 Install (local test)

1. Steam → Brotato → Manage → **Browse local files**
2. Close Brotato completely
3. Copy `mods-unpacked/YourName-CoopMaterialFix/` into the Brotato game root:

   ```
   Brotato/mods-unpacked/YourName-CoopMaterialFix/manifest.json  ✅ this path must exist
   ```
4. Launch Brotato → **Mods** → enable **CoopMaterialFix** → restart

🪵 Something not showing up? Check `%APPDATA%\Brotato\logs\modloader.log`.

## 🔨 Build

```bash
python makezip.py
```

Outputs `YourName-CoopMaterialFix-<version>.zip`, ready for Workshop upload.

> Before publishing under your own name, replace `YourName` in the folder
> name, `manifest.json`, and `mod_main.gd`.

---

<sub>Target: Brotato 1.1.15.4 · ModLoader 6.2 · Godot 3.7</sub>
