# Licence notice — `xtonesreworked` (Xtones Reworked)

This package carries content from **Xtones Reworked 1.1.1-1.21.1**
(`xtonesreworked-1.1.1-1.21.1.jar`, mod id `xtonesreworked`), authored by
**TobsenD**.

## Upstream project

- Repository: <https://github.com/TobsenD/XTones-Reworked> (branch `main`)
- The mod's own page: <https://www.curseforge.com/minecraft/mc-mods/xtones-reworked>

## What the artefact declares — read from the files, not from a project page

| Evidence | Value |
|---|---|
| `META-INF/neoforge.mods.toml` → `license` | `MIT` |
| `META-INF/neoforge.mods.toml` → `authors` | `TobsenD` |
| Jar contents | **no** `LICENSE`/`COPYING`/`NOTICE` file of its own |
| Upstream repository `LICENSE` (branch `main`) | the **MIT** text, `Copyright (c) 2022 TobsenD` |

So the port is **MIT → licence rank 0 (permissive)**. The jar declares MIT but
ships no licence text, so the notice has to come from the upstream repository;
it is reproduced here verbatim and travels with the package.

## What travels with this package

- `LICENSE` — the upstream MIT text, byte-identical to
  <https://github.com/TobsenD/XTones-Reworked/blob/main/LICENSE>
  (`Copyright (c) 2022 TobsenD`). MIT requires the copyright and permission
  notice to be included in all copies or substantial portions of the software,
  and this package carries the mod's 549 textures, 547 models and 580 recipes,
  so the notice is inside the archive — the content loader ignores a root
  `LICENSE*` file at runtime, which is exactly why it has to be in the bytes.
- `LICENSE-NOTICE.md` — this file.
- `notes.md` (in the port, not in the archive) — provenance, the carry verdict
  and every deviation.

The `assets/` and `data/` in this package are the upstream mod's own MIT files,
carried to 26.3; no Java source is copied, and the jar itself is evidence under
`ports/_shared/carry-work/xtonesreworked/` — never committed, never shipped.

## Obligations that follow from MIT

1. Redistribution and modification are permitted; the copyright and permission
   notice travel with the package (this file and `LICENSE`).
2. The software is provided **as is**, without warranty; the licence's
   disclaimer applies unchanged.
3. The port is a **carry**: the 546 blocks, 580 recipes, loot tables, tags and
   lang file are the jar's, and the behaviour the carry cannot express
   (`flat_lamp` placement orientation and its 4-tick off delay) is listed in
   `notes.md`.
