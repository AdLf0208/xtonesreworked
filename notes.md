# Xtones Reworked — port notes

Ported from **Xtones Reworked 1.1.1-1.21.1** (mod id `xtonesreworked`, MIT,
Modrinth project `YDluI37t`, upstream `TobsenD/XTones-Reworked`) for Minecraft
Java 26.3 on the campaign pin **Horizon `0a875da91dbb0fdcb7ba8c42c11341aa229af51a`**
(Nightly 2026-11-20) / horizon-mixins `e59da9094f0c2fdda6c627fe9eff22dec6a906f0`.
The port started on `41f822b6`/`5a64af93` as a content-only carry and moved to the
flat SDK package at `0a875da` when the lamp's placement rule was implemented.

**Licence: MIT → rank 0 (permissive).** The port is local-only until the
maintainer approves publishing (ARCHITECTURE.md §8); the assets and data are the
upstream mod's own MIT files.

**Upstream project:** <https://github.com/TobsenD/XTones-Reworked> (branch
`main`, MIT, `Copyright (c) 2022 TobsenD`). The jar declares `license = "MIT"`
and `authors = "TobsenD"` in `META-INF/neoforge.mods.toml` but ships **no**
`LICENSE`/`COPYING`/`NOTICE` file of its own, so the notice comes from the
repository and is reproduced verbatim.

**The MIT notice ships inside the package.** The archive carries the mod's 549
textures, 547 models and 580 recipes, and MIT requires the copyright and
permission notice in all copies or substantial portions, so `LICENSE` (the
upstream text) and `LICENSE-NOTICE.md` sit at the package root (the SDK build
packs root `LICENSE*`; `tools/notice.py` still appends them if a tool build ever
drops them, and is a no-op when they are already there).

**Class + tier** (the ATM10 reviewed table, `docs/modpacks/atm10-mods.csv:487`):
**content / data**. The tier's shape is the **carry-over** one — the jar's
`assets/` and `data/` upgraded to 26.3, with the blocks declared from vanilla
templates in `data/xtonesreworked/horizon/block/` — plus the data tier's
**server half** for the one behaviour a declaration cannot express: `flat_lamp`
placement orientation ([`Slice 4`](#slice-4--flat_lamp-placement-orientation-2026-11-21-sdk-0a875da)
below). The ledger row's class/tier is unchanged; the package is now native
because that half needs `BlockPart::state_for_placement`.

## Package kind — one flat SDK package, `api = "0.2"` (2026-11-21)

```text
ports/xtonesreworked/
  horizon-mod.toml   # id, version 1.1.2-1.21.1, api 0.2, [native] pins 0a875da/e59da90
  Cargo.toml         # horizon-mod-api from .horizon/sdk/ (fetched per clone, never packed)
  src/lib.rs         # one #[mod_api::horizon_mod] impl Hooks: the lamp's Part
  src/runtime.rs     # pure facing rule + tests (cargo test, no game)
  src/support.rs     # the glue: BlockPart::state_for_placement
  assets/, data/     # the carried content (3,357 files)
  LICENSE, LICENSE-NOTICE.md
  xtonesreworked.hmod
  tools/             # apply_patches, verify_content, craft_check, notice,
                     # placement_probe, e2e
```

`cargo horizon-mod check xtonesreworked.hmod` reports `xtonesreworked 1.1.2-1.21.1
(native-mod, format native-1/0a875da…/e59da90…, for 26.3)`, 1,471,108 bytes,
SHA-256 `2334f5e4…`, `CHECK_EXIT:0`; `fits` answers `0a875da  made for` and
`0b14f8a  fits`. The earlier content-only package (`1.1.1-1.21.1`, `kind = "mod"`)
is the published entry and stays valid; this slice is an **Update** of it.


## Version and source (no deviation)

The exact ATM10 8.x jar: `xtonesreworked-1.1.1-1.21.1.jar`,
1,276,690 bytes, SHA-1 `2daa001d39b43ba379991b944e022ab365c74cfd`,
SHA-256 `850fa3fdb66bd4abe722b473712cb72f716031e2b26e590e1034e43f5ce75b11`.

Resolved from the pack's own Crash Assistant export
(`AllTheMods/ATM-10/config/crash_assistant/modlist.json`, entry
`xtonesreworked-1.1.1-1.21.1.jar`, `modrinthHash` = that SHA-1) and downloaded
from the CurseForge CDN file id 7032490, because the Modrinth project lists no
1.21.1 file and `version_file/<sha1>` returns 404. Full evidence:
[`../_shared/carry-work/xtonesreworked/SOURCE.md`](../_shared/carry-work/xtonesreworked/SOURCE.md).
This is the pack's version, so **not** a fallback/deviation.

## Upstream analysis (analysis aid only)

Repo `https://github.com/TobsenD/XTones-Reworked`, branch `main`, pushed
2025-10-01, MIT. Files read: `XtonesReworkedMod.java` (creative tab),
`block/ModBlocks.java`, `block/custom/{XBlock,XGlass,FlatLamp}.java`, one family
file per class kind (`AgonBlocks.java`, `GlaxxBlocks.java`). Behaviours
extracted:

- 34 tone families × 16 variants: `XBlock`, a plain `Block` with
  `strength(6f)` and `requiresCorrectToolForDrops()`.
- `glaxx_block_0..15`: `XGlass`, a `TransparentBlock` with `strength(0.3f)`,
  glass sound, `noOcclusion()`, `requiresCorrectToolForDrops()`, and models with
  `render_type: translucent`.
- `xtone_tile`: a plain `Block` with `strength(3f)`.
- `flat_lamp`: `FlatLamp`, `facing` (6) × `lit` (bool), light 15 when lit,
  `lit` recomputed from `hasNeighborSignal` (off 4 ticks later), placement from
  `getNearestLookingDirection().getOpposite()`, and a 3-pixel plate shape on the
  `facing` side. `minecraft:redstone_lamp` carries the `lit` behaviour and its
  light; the `facing` property and the shapes are declared by hand.
- one creative tab, icon `xtone_tile`, all 546 block items, title key
  `itemGroup.xtonesreworked`.

The jar's own data is the content source; no Java code was translated.

## Content shape and carry verdict

Toolchain: `horizon-port-pack` and `cargo-horizon-mod` built from the pin
(`--locked --offline`, `CARGO_INCREMENTAL=0`, in a build slot). Evidence:
[`../_shared/evidence/xtonesreworked/check-cli.txt`](../_shared/evidence/xtonesreworked/check-cli.txt),
[`carry-cli.txt`](../_shared/evidence/xtonesreworked/carry-cli.txt),
[`hmod-check.txt`](../_shared/evidence/xtonesreworked/hmod-check.txt).

`check <jar> content` says **Partly. 546 blocks, 580 recipes port; not 1 block
with behaviour of its own**, and its class census names exactly `FlatLamp`
(`neighborChanged`, `tick`) as the only code feature — no events, no block
entities, no menus, no entities, no Mixins. That is the tier's expected shape:
the 545 other blocks are plain registrations.

`carry work --resources /home/adlf/Desktop/horizon/.local/horizon-client/26.3
xtonesreworked` then carried (identical to the `check` carry, diffed file by
file):

| Item | Count / result |
|---|---|
| files copied | **3,357** |
| block declarations | **546** (`0 left out`, `0 with differences`) |
| item definitions added | **546** (1.21.4 `items/` form) |
| recipes upgraded | **580** (`0 kept`) |
| loot tables upgraded | **16** (`0 added`) |
| ITEMS | 0 extra items, 0 convention tags |
| outside | 3 files from other namespaces |

Carried files: 546 blockstates, 547 block models (`flat_lamp_on` is a model,
not a block), 546 item models, 546 `items/` definitions, 549 textures, 580
recipes, 546 loot tables, the 34 family item tags (16 values each), the 7
`minecraft` block tags (`mineable/*`, `needs_*_tool`), one
`c:tags/item/glass_blocks`, and one `en_us` lang file with the jar's 547 keys.
Nothing the jar carries for the mod's own namespace was skipped.

The `check` report's `skipped` line is the one Java feature (FlatLamp), not
content: all 546 blocks came over. The carry cannot know block classes without
an oracle, so it guessed from blockstate property names — which is why the
three real fidelity decisions are applied by hand below.

`outside/` (3 files, integration-only, not the mod's own content):
`data/framedblocks/tags/block/frameable.json`,
`data/neoforged/tags/item/glass.json`,
`data/neoforged/tags/item/stained_glass.json`. They name FramedBlocks and
NeoForge `neoforged:` convention tags; neither namespace is carried, and the
content fence forbids them. Inert without those mods at 26.3.

## Deliberate patches on top of the carry

`tools/apply_patches.py content` (idempotent, run after every carry; the carry
deletes its output folder each time). It prints its counts and fails if the
declaration count is not 546:

- **528 tone blocks** (`<family>_block_<n>`): `minecraft:stone`, hardness
  **6.0** and `requires_tool` (upstream `XBlock.strength(6f)`; the carry's stone
  template would have left hardness 1.5). Stone's 6.0 blast resistance already
  matches `strength(6f)`, and its sound is the upstream default (`STONE`).
- **16 `glaxx_block_*`**: template **`minecraft:glass`** (upstream `XGlass` is a
  `TransparentBlock` with no occlusion and glass sound), hardness 0.3,
  resistance 0.3, `sounds: minecraft:glass`, `requires_tool`. Without this the
  carry's property-only guess was `minecraft:stone`: opaque and stone-sounded,
  which is the wrong look and the wrong light behaviour. The upstream models
  already carry `render_type: translucent`, which Horizon's model loader reads.
- **`xtone_tile`**: hardness **3.0**, resistance **3.0**, `requires_tool`
  (upstream `strength(3f)`; stone's resistance 6.0 would be too tough).
- **`flat_lamp`**: template **`minecraft:redstone_lamp`** instead of the
  carry's `minecraft:furnace` (a furnace template would bring its block entity
  and menu). The redstone lamp supplies the upstream behaviour — `lit` follows
  `hasNeighborSignal`, and the lit state emits 15 — while `facing` is declared
  as the block's own six-value enum (default `north`) with the upstream
  3-pixel plate shapes for all six values. Hardness 3.0, resistance 3.0,
  `sounds: minecraft:lantern`, `requires_tool` (upstream `strength(3f)` and
  `SoundType.LANTERN`).
- **one creative tab** (`data/xtonesreworked/horizon/creative_tab/xtones.json`):
  the upstream tab is code, so the jar has no data file; all 546 block items in
  upstream registration order, icon `xtone_tile`, title key
  `itemGroup.xtonesreworked` (the jar's own lang key).
- **16 `c:dyes/<colour>` item tags** (`data/c/tags/item/dyes/*.json`, one
  vanilla dye each). The jar's alternate recipes use all 16; 26.3 ships no `c:`
  tags, and an unknown tag makes a recipe load but never match.
- the port-owned `horizon-mod.toml` (id, version, description, authors, API 0.2,
  side both, `registries`, and the `[native]` pins since Slice 4).

`tools/verify_content.py . <jar> <outside>` re-checks the result at the package
root: every jar count matches and every blockstate/model/texture reference
resolves (see below; `outside/` was moved to
`../_shared/evidence/xtonesreworked/carry/outside/` when the package became flat).

## Slice 4 — `flat_lamp` placement orientation (2026-11-21, SDK `0a875da`)

**The gap, verbatim from the list below:**

> - **`flat_lamp` placement orientation.** The declared `facing` property has no
>   `getStateForPlacement`/`rotate`/`mirror` in a content mod, so a placed lamp
>   keeps the declared default (`facing=north`); upstream takes
>   `getNearestLookingDirection().getOpposite()` and rotates/mirrors with
>   structure transforms. Its `lit` state and light are fully live. This is the
>   campaign's documented directional-block carry limitation, not a missing block.

**Why this family.** It is the only implementable gap left in this port's list:
the lamp's two gaps (placement, the 4-tick off delay) are the only behaviours the
jar has, and placement is the one a player meets on every placement. It fits the
**data** tier as that tier's documented **server half** — no block entity, no
menu, no renderer, no new block — and it is provable in game with an assertion a
declaration cannot satisfy (the state must change with the click).

**Shape.** `BlockPart::state_for_placement` is attached to
`xtonesreworked:flat_lamp` only. The rule is a straight port of this pin's own
vanilla implementation, `Direction.orderedByNearest(entity)[0]`
(`horizon/crates/horizon-world/src/level/place.rs:82`), then its opposite:

- `src/runtime.rs` — `nearest_look(yaw, pitch)` (the branch-for-branch port, with
  `std` sine/cosine for the game's table), `lamp_facing(yaw, pitch)` (its
  opposite, as upstream's `getNearestLookingDirection().getOpposite()`), and
  `placement_state(facing)` → `xtonesreworked:flat_lamp[facing=<dir>]`. Pure, no
  `mod_api` types, 4 `cargo test` cases.
- `src/support.rs` — answers only when `level.state_block(event.state)` is the
  lamp, resolves the state string with `level.block_state_id`, and leaves every
  other block's placement to vanilla (`None`).
- `src/lib.rs` — one `#[mod_api::horizon_mod] impl Hooks`, whose `register`
  attaches the Part with `r.block_key(...)` + `r.block_part(...)`. Nothing is
  registered: the blocks, items and data stay content in the same package.

**Red proof, unit (TDD, before the rule existed):**

```text
error[E0425]: cannot find function `lamp_facing` in this scope
  --> src/runtime.rs:87:20
   |
87 |         assert_eq!(lamp_facing(180.0, -90.0), Facing::Down, "looking up");
   |                    ^^^^^^^^^^^ not found in this scope
error: could not compile `mod-xtonesreworked` (lib test) due to 10 previous errors
```

**Red proof, in game (the published pre-slice package, `fe19a9a0…`, on the shared
game; log `../_shared/evidence/xtonesreworked/placement-red.log`):**

```text
+ click the post's south face from the south: the plate must face the player (facing=south)
click north -> facing=north
+ click the east face of the post at (16,80,5) from the east: the plate must face east
click east -> facing=north
FAIL: a north-looking click reads facing=north, expected south
EXIT:1
```

Both clicks read the declared default — a content declaration cannot pass the
assertion, which is why the shape is the Part.

**How the click is made (measured, and the one trap of this slice).** `ctl place`
aims the crosshair itself, but the placement context is built from the rotation
the *server* has, which is one aim behind: the first version placed the lamp with
the previous heading (`up`/`south` in the first green attempt). The e2e therefore
sets the heading with `ctl look <yaw> <pitch>` and waits 5 ticks before each
click; the measured post-click rotations were `yaw -180, pitch 23.7` and
`yaw 90, pitch 17.5`, and the lamp answered `south`/`east`.

**Green (all at `0a875da`/`e59da90`, delivered file SHA-256 `2334f5e4…`):**

| Check | Result |
|---|---|
| `cargo test --offline` | **4 passed**, 0 failed (`sdk-test.log`) |
| `cargo clippy --all-targets --offline -- -D warnings` | `CLIPPY_EXIT:0`, 0 warnings (`sdk-clippy.log`) |
| `cargo fmt --check` | `FMT_EXIT:0` (`sdk-fmt.log`) |
| `cargo horizon-mod build` ×2, `rm -f Cargo.lock` before each | both `BUILD_EXIT:0`; the two builds **and** the delivered file are `cmp`-identical (`build-first.log`, `build-second.log`, `cmp.txt`) |
| `cargo horizon-mod check xtonesreworked.hmod` | `native-mod, format native-1/0a875da…/e59da90…`, **1,471,108 B**, SHA-256 `2334f5e4…`, `CHECK_EXIT:0` (`sdk-check.log`) |
| `cargo horizon-mod fits … --build 0a875da` | `0a875da  made for`, `FITS_PIN_EXIT:0` (`sdk-fits-0a875da.log`) |
| `cargo horizon-mod fits … --build 0b14f8a` (a different build, so not a tautology) | `0b14f8a  fits`, `FITS_OTHER_EXIT:0` (`sdk-fits-0b14f8a.log`) |
| `python3 ports/tools/verify-sdk-package.py xtonesreworked` | **1/1** (package, runtime byte-identical, no packed lock, 4 tests, clippy, check, fits, skills) |
| launcher `native-build` at the pin | `Compiling xtonesreworked (1 of 1)` (`.…-e2e/launcher-build.log`) |
| `tools/e2e.sh` on that build | **PASS + `EXIT:0`** (`.…-e2e/e2e-launcher.log`) |
| `SELFTEST=1 tools/e2e.sh` | **`FAIL:` + `EXIT:1`** at the pre-slice expectation (`.…-e2e/e2e-launcher-selftest.log`) |
| `CONTROL=1 tools/e2e.sh` (the same Nightly without the package) | **`FAIL:` + `EXIT:1`** at the first block (`setblock …agon_block_0 failed`), `.…-e2e/e2e-launcher-control.log` |
| `tools/placement_probe.sh` (focused leg) | PASS on this package; `EXPECT=north` fails (`…-e2e/placement-probe-selftest.log`) |
| `python3 ports/tools/check-e2e-logs.py xtonesreworked-e2e --strict` | `logs=4 ok=4 missing-exit=0 bad-exit=0` |

The e2e transcript of the new phase:

```text
+ flat_lamp placement: the plate faces the click, not the declared default
click the south face of (40,80,20) looking north -> facing=south
click the east face of (44,80,22) looking west -> facing=east
flat_lamp: north-looking click -> facing=south, west-looking click at an east post -> facing=east
```

**Content unchanged.** `tools/verify_content.py` against the jar still reports every
count equal (546 blockstates/models/items/loot, 547 models, 549 textures, 580
recipes, 547 lang keys, 34+7 tags) and every model/texture reference resolved
(`verify-content.txt`); the package's `assets/`+`data/` are the same bytes as the
published 1.1.1 package. The only code is the lamp's Part: `uses.json` names the
`state_for_placement` hook, `block_states`/`level` capabilities.

**Coverage (this slice's family):**

| family | state |
|---|---|
| `flat_lamp` placement orientation | **tested** — e2e phase "flat_lamp placement", `facing=south` from a north-looking click and `facing=east` from a west-looking click at an east post; unit `a_placed_lamp_faces_the_placer`, `a_slightly_downward_aim_still_takes_the_horizontal_axis`, `a_steep_aim_faces_up_or_down` |
| `flat_lamp` `lit` + light 15 | **tested** (previous slice) — redstone block on/off, light `f`/`0` |
| `flat_lamp` off delay (4 ticks upstream) | **not ported** — the `redstone_lamp` template switches off immediately; a content/template limitation, recorded below |
| `flat_lamp` structure rotate/mirror | **not ported** — no template worldgen in this jar to prove it against; vanilla's property-level mirroring still applies when a structure uses the state. Recorded, not claimed |
| carried recipes (580) | **4 shapes tested in game** (tile, family base, family alternate with `#xtonesreworked:agon` + `#c:dyes/white`, lamp) with wrong-ingredient controls; the 576 remaining instances are those shapes over 34 families × 16 variants / 16 dyes, verified equal to the jar's files by `verify_content.py`, **not each crafted** — a recipe-sweep is the next slice (see below) |


## Gaps and deviations

- **`flat_lamp` placement orientation — closed in Slice 4.** The declared
  `facing` property has no `getStateForPlacement` in a content declaration, so it
  used to keep the declared default (`facing=north`). The lamp's Part now answers
  `getNearestLookingDirection().getOpposite()` from the placer's view
  (`src/runtime.rs` + `src/support.rs`), proven in game (`facing=south` from a
  north-looking click, `facing=east` from a west-looking one). **Structure
  rotate/mirror remain unproven**: the jar ships no template that places a lamp,
  so the port makes no claim beyond the engine's own property-level transform.
- **`flat_lamp` off delay.** Upstream schedules the off change 4 ticks after the
  signal falls; the `minecraft:redstone_lamp` template switches off at once.
  On-transition is immediate in both.
- **Map colours** follow the templates (stone/glass); upstream declares none, so
  there is no upstream colour to compare.
- `data/minecraft/tags/block/mineable/axe.json` is an empty `replace:false`
  addition in the jar; carried as-is (harmless).
- **The glass family's drops are upstream's own quirk, carried faithfully.**
  The jar sets `requiresCorrectToolForDrops()` on `XGlass` but lists no
  `glaxx_block_*` in any `minecraft:mineable/*` tag, so no tool is ever
  "correct" and breaking one drops nothing (the plain self-drop table is never
  reached). The e2e asserts exactly that, with the tone block (in
  `#minecraft:mineable/pickaxe`) dropping itself as the differential. Adding the
  family to the pickaxe tag would deviate from the jar, so it is recorded here
  instead of applied.
- The `neoforged:`/`framedblocks:` integration tags stay in `outside/` (above).
- No advancements, sounds or worldgen exist in the jar, so none are missing.

Skills: superpowers/using-superpowers,brainstorming,writing-plans,test-driven-development,systematic-debugging,verification-before-completion; BeautifulRust/rust-best-practices (the Slice 4 rule, its tests and the glue)

## Verification

> **Current package (2026-11-21, SDK `0a875da`).** `xtonesreworked.hmod`
> **1,471,108 B**, SHA-256
> `2334f5e41cba8d2eef24d3d70e1696e32761010298cf724c4541a6d366d51ed7`, version
> **1.1.2-1.21.1**, **4,474 entries**, `native-mod` on
> `0a875da…`/`e59da90…`. `cargo test` **4/4**, clippy/fmt clean, two
> `cmp`-identical builds, `check` and both `fits` EXIT 0,
> `verify-sdk-package.py` **1/1**, launcher-built game `PASS` + `EXIT:0` with
> `SELFTEST=1` and `CONTROL=1` at `EXIT:1`,
> `check-e2e-logs.py xtonesreworked-e2e --strict` **4/4**. Evidence:
> [`../_shared/evidence/xtonesreworked/`](../_shared/evidence/xtonesreworked/)
> and [`../_shared/evidence/xtonesreworked-e2e/`](../_shared/evidence/xtonesreworked-e2e/).
> Everything below this banner is the **content-only history** (`41f822b6`/`0b14f8a`).

**History — the content-only carry (pin `41f822b659789780f58d32c63ddfb6887ea1b8bf`).**

| Check | Evidence |
|---|---|
| `horizon-port-pack check <jar> content` | **Partly. 546 blocks, 580 recipes port; not 1 block with behaviour of its own** (exit 0); `check-cli.txt`, `check.json` |
| `horizon-port-pack carry work --resources …/26.3 xtonesreworked` | 3,357 files, 580 recipes upgraded, 546 item definitions, **546 blocks (0 left out, 0 differences)**, 3 outside; `carry-cli.txt`, `carry-report.json` |
| `tools/verify_content.py content` | **PASS**: every jar count matches (546 blockstates/models/items/loot, 580 recipes, 549 textures, 547 lang keys, 34 item + 7 block tags), every model/texture reference resolves, and recipe/loot/tag **contents** equal the jar's; `verify-content.txt` |
| `cargo-horizon-mod build` (pin) + `tools/notice.py` | `Built ./target/horizon-mod/xtonesreworked.hmod` — **1,465,028 B**, SHA-256 `5952a00793cfc9b1eb999569a3e69be7a5a1cd4e1fb6e4453e3c06ed1198ea00`, **4,469 entries** (4,467 + `LICENSE`, `LICENSE-NOTICE.md`); `hmod-info.txt` |
| `cargo-horizon-mod check` | ok: `xtonesreworked 1.1.1-1.21.1 (mod, API 0.2, both)` … `no code: content only, nothing to run`, unsigned; `hmod-check.txt` |
| `tools/e2e.sh` (default, shared game) | **exit 0**, `PASS:` below; log `e2e-default.log`; screenshot `grid.png` |
| `NEGATIVE=1 tools/e2e.sh` | **exit 1** at the deliberately false assertion, as required; `e2e-negative.log` |

The e2e runs on the **shared unmodded game** at the pin
(`ports/_shared/bin/horizon-41f822b6/`, `shared-bin.sh verify` ok) with
`--dev-mod ports/xtonesreworked/content`: a content-only port has no native
module, so there is no per-port game build. The game's own content root
(`.horizon-cache/mod-content/<stamp>/`) is what the tab/model checks read.

Transcript (abridged; the full log has every `setblock`/read and every recipe):

```
+ launch (shared …/horizon-41f822b6, offscreen, creative, --dev-mod content)
544/544 tone block states bound and read back
xtone_tile bound; 6/6 flat_lamp facings bind, and lit=true binds beside a redstone block
redstone block -> lit=true/light 15; removed -> lit=false/light 0
light through glaxx: d; through stone: 0
occlusion: glaxx False (glass), tone True (stone)
model-state and render-definition rows exist for tone, glass, lamp and tile
creative tab: 546/546 entries
36 sampled items give (xtone_tile, flat_lamp and one variant per family)
xtonesreworked:agon_block_0 placed
tags: tone in #minecraft:mineable/pickaxe, glaxx in none (as the jar ships them)
{"block":"minecraft:air","block_before":"xtonesreworked:agon_block_0","drops":{"xtonesreworked:agon_block_0":1}}
{"block":"minecraft:air","block_before":"xtonesreworked:glaxx_block_1","drops":{}}
6 stone slabs + stone -> xtone_tile -> {"count": 8, "item": "xtonesreworked:xtone_tile", ...}
6 stone slabs + stick -> null
8 agon blocks + white dye -> agon_block_0 -> {"count": 8, "item": "xtonesreworked:agon_block_0", ...}
8 agon blocks + stick -> null
8 xtone_tiles + stone slab -> agon_block_0 -> {"count": 8, ...}
2 iron + glowstone dust + 3 slabs -> flat_lamp -> {"count": 2, "item": "xtonesreworked:flat_lamp", ...}
2 iron + glowstone dust + 2 slabs + stone -> null
recipe PASS: xtone_tile, the #xtonesreworked:agon + #c:dyes/white recipe, …
unknown block/item ids are refused
no missing model/texture and no refused recipe in the log; screenshot saved (grid.png)
PASS: 544/544 tone block states bind plus xtone_tile, 6/6 flat_lamp facings and
lit=true; flat_lamp follows redstone (lit 15 / off 0); glaxx passes light while
stone stops it; the creative tab lists 546 items and they give; a family block
places; a pickaxe drops a tagged tone block while glaxx (in no mineable tag, as
the jar ships it) drops nothing; an empty hand drops neither xtone_tile nor
vanilla stone; xtone_tile, the #xtonesreworked:agon + #c:dyes/white recipe and
flat_lamp craft in a table while their controls stay empty; unknown ids are
refused; the log has no missing model, texture or recipe
```

The control that proves the assertions can fail:

```
+ NEGATIVE: a deliberately false assertion must fail the run
negative probe: 0 80 0 reads 'xtonesreworked:agon_block_0'; this run asserts 'minecraft:stone'
FAIL: NEGATIVE run: the false assertion ('minecraft:stone') failed the run, as required
```

The default run itself also contains the controls the brief asks for: a
made-up id is refused by `give`/`setblock`, the empty hand drops nothing from a
tone-family material while the same hand drops nothing from vanilla stone
(differential), glaxx's sealed light box is compared against a stone box, and
every recipe has a wrong-ingredient control.

Re-run the e2e with:

```sh
eval "$(ports/tools/shared-bin.sh env)"
CTL=$CTL GAME=$GAME ports/xtonesreworked/tools/e2e.sh        # PASS, exit 0
NEGATIVE=1 CTL=$CTL GAME=$GAME ports/xtonesreworked/tools/e2e.sh   # exit 1
```

## Gate re-run at the SDK pin `0b14f8a` (2026-11-20, history)

The content-only package was unchanged and its gate was green at the pin the
campaign built against then. Superseded by Slice 4 at `0a875da` (the package is
now native and version 1.1.2-1.21.1).

| Check | Result |
|---|---|
| `rm -f Cargo.lock`; `cargo test` / `clippy` / `fmt` | **n/a** — content-only port: no `Cargo.toml`, no `src/` |
| `cargo horizon-mod build` twice + `tools/notice.py`, `cmp` | **identical** (and identical to the delivered `.hmod`); `unzip -l` has **no `Cargo.lock`** (4,469 entries) |
| `cargo horizon-mod check xtonesreworked.hmod` | `xtonesreworked 1.1.1-1.21.1 (mod, API 0.2, both)` … `1,465,028 bytes, SHA-256 5952a007…`, `no code: content only, nothing to run`, `CHECK_EXIT:0` (`../_shared/evidence/xtonesreworked/sdk-check.log`) |
| `cargo horizon-mod fits xtonesreworked.hmod --build 0b14f8a` | *"is a content mod … `fits` doesn't apply."*, `FITS_EXIT:2` = the tool's not-applicable status (`sdk-fits.log`) |
| `python3 ports/tools/verify-sdk-package.py xtonesreworked` | **1/1** (package, content-only, check, fits, skills gate all `ok`) |
| `tools/e2e.sh` at `0b14f8a` (control game, `--dev-mod content`) | **PASS + `EXIT:0`** — the whole scenario, unchanged (`../_shared/evidence/xtonesreworked-e2e/e2e-launcher.log`) |
| `NEGATIVE=1 tools/e2e.sh` at `0b14f8a` | **`FAIL:` + `EXIT:1`** at the deliberately false assertion, as required (`…-e2e/e2e-launcher-negative.log`) |
| `python3 ports/tools/check-e2e-logs.py xtonesreworked-e2e --strict` | `logs=2 ok=2 missing-exit=0 bad-exit=0`, exit 0 |

The game is the **unmodified Nightly at `0b14f8a`**
(`~/.cache/horizon-e2e/0b14f8a/control/`, the same binary the launcher's control
leg uses) with the prepared 26.3 resources from that Nightly, so the leg is at the
SDK pin rather than the older shared `41f822b6`/`1d63e0a5` game the table above
records. No content byte changed for this run. `launcher-game.sh build` refuses a
content-only package (exit 5: *"load it with `--dev-mod content` on a shared
game, not with native-build"*, `…-e2e/launcher-game-refusal.log`), which is why the
leg is the control export of the same Nightly and not a native build.

## Artifacts

- `ports/xtonesreworked/xtonesreworked.hmod` — the delivered package,
  **1,471,108 B**, SHA-256
  `2334f5e41cba8d2eef24d3d70e1696e32761010298cf724c4541a6d366d51ed7`, version
  **1.1.2-1.21.1**, **4,474 entries** (the 4,467 content entries + the two
  licence files + this package's `Cargo.toml`, `src/lib.rs`, `src/runtime.rs`,
  `src/support.rs` and `uses.json`), no packed
  `Cargo.lock`; byte-identical on two rebuilds from the package root.
- `ports/xtonesreworked/` (the package root) — `horizon-mod.toml` (the only
  manifest, with the `[native]` pins), `Cargo.toml`, `src/` (the lamp's Part and
  its pure rule), `assets/`, `data/`, `LICENSE`, `LICENSE-NOTICE.md`. The carry's
  `check.json`, `carry-report.json` and `outside/` moved to
  `../_shared/evidence/xtonesreworked/carry/` when the package became flat.
- `ports/xtonesreworked/tools/` — `apply_patches.py` (re-applies the hand
  decisions after a carry; writes the native manifest), `verify_content.py`
  (static jar-vs-content check), `craft_check.py` (the table cases), `notice.py`
  (keeps the upstream MIT notice in the built archive; a no-op when the SDK build
  already packed the root `LICENSE*`), `placement_probe.sh` (the focused
  `flat_lamp` directional leg, `EXPECT=north` for its counterfactual) and `e2e.sh`
  (default, `SELFTEST=1`, `CONTROL=1`, `NEGATIVE=1`).
- `ports/_shared/carry-work/xtonesreworked/` — the jar, `SOURCE.md` (version,
  hashes, download and why it is CurseForge-only), `work/` (inventory + carry).
- `ports/_shared/evidence/xtonesreworked/` — the ladder at `0a875da`
  (`sdk-test.log`, `sdk-clippy.log`, `sdk-fmt.log`, `build-first.log`,
  `build-second.log`, `cmp.txt`, `sha256-build1.txt`, `sha256-build2.txt`,
  `sdk-check.log`, `sdk-fits-0a875da.log`, `sdk-fits-0b14f8a.log`,
  `hmod-info.txt`, `verify-content.txt`), `placement-red.log` (the pre-slice
  in-game red), the carry's `check-cli.txt`, `check.json`, `carry-report.json`,
  `carry-cli.txt`, `carry/` (the three `outside/` files and the retired content
  manifest), `e2e-default.log`, `e2e-negative.log` (history) and `grid.png`;
  `ports/_shared/evidence/xtonesreworked-e2e/` — `launcher-build.log`
  (`Compiling xtonesreworked (1 of 1)`), `e2e-launcher.log` (`PASS` + `EXIT:0`),
  `e2e-launcher-selftest.log`, `e2e-launcher-control.log`,
  `placement-probe-selftest.log`.

## Next slice

**Recipe sweep — the 576 carried recipe instances that are verified statically but
not crafted one by one.** Gap line: the coverage row in Slice 4 above
(*"the 576 remaining instances are those shapes over 34 families × 16 variants /
16 dyes … **not each crafted**"*). It fits the **data** tier (a carried recipe is
data), needs no new API, and is fail-capable the same way the current table cases
are. In-game assertion: for **each of the 34 families**, craft its base recipe
(8 `xtonesreworked:xtone_tile` + 1 `minecraft:stone_slab` → 8
`xtonesreworked:<family>_block_0`) in a real table and read the result **id and
count** plus the consumed grid; counterfactual: the same grid with a stick in the
slab's place must leave the result empty for every family. Suggested shape: a
`tools/recipe_sweep.py` called from `tools/e2e.sh` (≈34 crafts, ~6–8 minutes),
with the four existing shape cases kept as the fast subset.

