#!/usr/bin/env python3
"""Re-apply the hand patches on top of a fresh `horizon-port-pack check` carry.

The carry tool deletes `carry/` and `outside/` on every run, so the hand
decisions live here, not in the generated files. Run this after the carry, from
the port directory (the package is the port root since the SDK migration):

    python3 tools/apply_patches.py .

What it changes, and why (all facts come from the jar's own blockstates and the
upstream 1.1.1 source, see ../notes.md):

* tone blocks (`<family>_block_<n>`) - upstream `XBlock`: plain `Block`,
  `strength(6f)` = hardness 6 / blast resistance 6, requires the correct tool.
  The property-only template guess gives `minecraft:stone`, whose hardness is
  1.5, so the hardness is raised to 6.0 (resistance 6 is already stone's).
* `xtone_tile` - upstream plain `Block` with `strength(3f)`: hardness 3.0 and
  resistance 3.0 (stone's 6.0 would be too tough).
* `glaxx_block_*` - upstream `XGlass`: `TransparentBlock`, `strength(0.3f)`,
  glass sound, no occlusion, requires the correct tool. The property-only guess
  cannot see the class and would use `minecraft:stone`; the template is set to
  `minecraft:glass`, which copies the transparent class, the 0.3 hardness, the
  glass sound and the no-occlusion flags, plus `requires_tool` for the upstream
  `requiresCorrectToolForDrops()`.
* `flat_lamp` - upstream `FlatLamp`: `facing` x `lit`, light 15 when lit,
  `lit` follows a redstone signal, plate shape 3 px on the `facing` side. The
  carry maps `facing,lit` to `minecraft:furnace`; a furnace template carries its
  block entity, so the template is moved to `minecraft:redstone_lamp` (the
  `lit` state and its redstone behaviour) and `facing` is declared as the
  block's own six-value property with the upstream shapes. Placement
  orientation is answered by `src/support.rs` (`BlockPart::state_for_placement`
  with `runtime::lamp_facing`), not by this declaration.
* one creative tab with all 546 block items in upstream registration order
  (the tab itself is code upstream, so the jar has no data file for it).
* the 16 `c:dyes/<colour>` convention tags the recipes use: 26.3 ships no `c:`
  tags, and an unknown tag makes the recipe load but never match.
* the port-owned `horizon-mod.toml` (id, version, the exact `[native]` pins).
"""

import json
import pathlib
import sys

FAMILIES = [
    "agon", "azur", "bitt", "cray", "fort", "glaxx", "iszm", "jelt", "korp",
    "kryp", "lair", "lave", "mint", "myst", "reds", "reed", "roen", "sols",
    "sync", "tank", "vect", "vena", "zane", "zech", "zest", "zeta", "zion",
    "zkul", "zoea", "zome", "zone", "zorg", "ztyl", "zyth",
]

DYE_COLOURS = [
    "white", "orange", "magenta", "light_blue", "yellow", "lime", "pink",
    "gray", "light_gray", "cyan", "purple", "blue", "brown", "green", "red",
    "black",
]

# Upstream FlatLamp shapes, converted from its 0..16 pixel boxes to block units.
LAMP_SHAPES = {
    "north": [[0.0, 0.0, 13.0 / 16.0, 1.0, 1.0, 1.0]],
    "south": [[0.0, 0.0, 0.0, 1.0, 1.0, 3.0 / 16.0]],
    "up": [[0.0, 0.0, 0.0, 1.0, 3.0 / 16.0, 1.0]],
    "down": [[0.0, 13.0 / 16.0, 0.0, 1.0, 1.0, 1.0]],
    "east": [[0.0, 0.0, 0.0, 3.0 / 16.0, 1.0, 1.0]],
    "west": [[13.0 / 16.0, 0.0, 0.0, 1.0, 1.0, 1.0]],
}


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + "\n")


def patch_block(path, name, changed):
    decl = json.loads(path.read_text())
    if name.startswith("glaxx_block_"):
        decl["template"] = "minecraft:glass"
        decl["properties"] = {
            "hardness": 0.3,
            "explosion_resistance": 0.3,
            "sounds": "minecraft:glass",
            "requires_tool": True,
        }
        changed["glass"] += 1
    elif name == "flat_lamp":
        decl = {
            "template": "minecraft:redstone_lamp",
            "properties": {
                "hardness": 3.0,
                "explosion_resistance": 3.0,
                "sounds": "minecraft:lantern",
                "requires_tool": True,
            },
            "state_properties": {
                "facing": {
                    "type": "enum",
                    "values": ["north", "east", "south", "west", "up", "down"],
                }
            },
            "default_state": {"facing": "north"},
            "shapes": {"property": "facing", "values": LAMP_SHAPES},
        }
        changed["lamp"] += 1
    elif name == "xtone_tile":
        decl["template"] = "minecraft:stone"
        decl["properties"] = {
            "hardness": 3.0,
            "explosion_resistance": 3.0,
            "requires_tool": True,
        }
        changed["tile"] += 1
    else:
        decl["template"] = "minecraft:stone"
        decl["properties"] = {"hardness": 6.0, "requires_tool": True}
        changed["tone"] += 1
    write_json(path, decl)


def write_manifest(content):
    """The port-owned manifest: the carry's own header is a generated stub."""
    (content / "horizon-mod.toml").write_text(
        "# Xtones Reworked 1.1.1-1.21.1 carried to the Horizon SDK format (mod API 0.2),\n"
        "# now with the flat lamp's placement rule in Rust.\n"
        "# Licence: MIT (the upstream mod's own; see LICENSE and LICENSE-NOTICE.md).\n"
        'id = "xtonesreworked"\n'
        'name = "Xtones Reworked"\n'
        'version = "1.1.2-1.21.1"\n'
        'description = "34 tone families of 16 decorative blocks, the xtone tile and the flat lamp"\n'
        'authors = ["TobsenD"]\n'
        'api = "0.2"\n'
        'side = "both"\n'
        'capabilities = ["registries"]\n'
        'license = "MIT"\n'
        'homepage = "https://github.com/TobsenD/XTones-Reworked"\n'
        "\n"
        "[native]\n"
        'game = "26.3"\n'
        'horizon = "0a875da91dbb0fdcb7ba8c42c11341aa229af51a"\n'
        'mixins = "e59da9094f0c2fdda6c627fe9eff22dec6a906f0"\n'
    )


def main():
    content = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    block_dir = content / "data" / "xtonesreworked" / "horizon" / "block"
    if not block_dir.is_dir():
        raise SystemExit(f"no carried block declarations at {block_dir}")

    changed = {"tone": 0, "glass": 0, "tile": 0, "lamp": 0}
    names = []
    for path in sorted(block_dir.glob("*.json")):
        name = path.stem
        names.append(name)
        patch_block(path, name, changed)

    expected = 2 + len(FAMILIES) * 16
    if len(names) != expected:
        raise SystemExit(
            f"{len(names)} block declarations, expected {expected} "
            "(xtone_tile + flat_lamp + 34 families x 16)"
        )

    tab = {
        "title": "itemGroup.xtonesreworked",
        "icon": "xtonesreworked:xtone_tile",
        "items": ["xtonesreworked:xtone_tile", "xtonesreworked:flat_lamp"]
        + [
            f"xtonesreworked:{family}_block_{variant}"
            for family in FAMILIES
            for variant in range(16)
        ],
    }
    write_json(content / "data" / "xtonesreworked" / "horizon" / "creative_tab" /
               "xtones.json", tab)

    write_manifest(content)

    for colour in DYE_COLOURS:
        write_json(
            content / "data" / "c" / "tags" / "item" / "dyes" / f"{colour}.json",
            {"replace": False, "values": [f"minecraft:{colour}_dye"]},
        )

    print(
        "patched {tone} tone, {glass} glass, {tile} tile, {lamp} lamp blocks; "
        "1 creative tab ({items} items); {dyes} c:dyes tags".format(
            items=len(tab["items"]), dyes=len(DYE_COLOURS), **changed
        )
    )


if __name__ == "__main__":
    main()
