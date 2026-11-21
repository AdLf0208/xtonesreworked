#!/usr/bin/env python3
"""Craft the Xtones recipes in a real crafting table.

Called by tools/e2e.sh with the open game's control socket. Uses the harness's
crafting grid (`ctl screen`: slots 100-108 row-major, result 200), gives the
ingredients, and asserts:

1. six `minecraft:stone_slab` + one `minecraft:stone` -> eight
   `xtonesreworked:xtone_tile` (the plain shaped recipe, and the crafted stack
   reaches the inventory);
2. six stone slabs + a stick in the centre -> an empty result (the stone is
   required);
3. eight `xtonesreworked:agon_block_1` around one white dye -> eight
   `xtonesreworked:agon_block_0`; this is the `agon_block_0_alternate` recipe,
   which names `#xtonesreworked:agon` and `#c:dyes/white`, so it proves both the
   carried item tag and the hand-written convention tag resolve;
4. eight agon blocks around a stick -> an empty result (the dye tag is
   required);
5. eight `xtonesreworked:xtone_tile` around one stone slab -> eight
   `xtonesreworked:agon_block_0` (the family base recipe);
6. two `minecraft:iron_ingot` + one `minecraft:glowstone_dust` + three stone
   slabs -> two `xtonesreworked:flat_lamp`, and a stone in a slab's place stays
   empty.

The table is replaced before every case, so a failed/untaken result cannot
leak into the next grid. Exits 1 with the observed result on the first
mismatch.
"""
import json
import subprocess
import sys

RING = [100, 101, 102, 103, 105, 106, 107, 108]
CENTRE = 104
TILE_SLABS = [100, 101, 103, 105, 107, 108]
BOTTOM_ROW = [106, 107, 108]


def main():
    sock, ctl, x, y, z = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5]

    def run(*args):
        out = subprocess.run([ctl, "--socket", sock, *args], text=True, capture_output=True)
        try:
            return json.loads(out.stdout)
        except json.JSONDecodeError:
            raise SystemExit(f"ctl {' '.join(args)}: {out.stdout}{out.stderr}")

    def wait(ticks=4):
        run("wait", str(ticks))

    def slots():
        screen = run("screen")
        if "slots" not in screen:
            raise SystemExit(f"no menu is open: {screen}")
        return screen["slots"]

    def find(item):
        for slot in slots():
            if slot.get("item") == item:
                return slot["slot"]
        raise SystemExit(f"missing ingredient {item} in the inventory")

    def open_table():
        wait()
        run("interact", x, y, z)
        wait(5)

    def result():
        """The result slot's stack, or None: an empty slot has `item: null`."""
        stack = [s for s in slots() if s["slot"] == 200]
        if not stack or not stack[0].get("item"):
            return None
        return stack[0]

    def place(item, mode, targets):
        slot = find(item)
        run("click-slot", str(slot))
        wait(1)
        for target in targets:
            if mode == "right":
                run("click-slot", str(target), "right")
            else:
                run("click-slot", str(target))
            wait(1)
        run("click-slot", str(slot))
        wait(2)

    def setup(items):
        try:
            run("close")
        except SystemExit:
            pass
        wait(5)
        # Replace the table so its block entity, and therefore the crafting
        # grid, is fresh for this case.
        run("setblock", x, y, z, "minecraft:air")
        run("setblock", x, y, z, "minecraft:crafting_table")
        wait(2)
        run("command", f"tp @s {float(x) - 0.5} {y} {float(z) + 0.5}")
        wait(3)
        run("command", "clear @s")
        for item, count in items:
            run("give", item, str(count))
        wait(3)
        open_table()

    failures = []

    def check(label, items, placements, want_item, want_count, take=False):
        setup(items)
        for item, mode, targets in placements:
            place(item, mode, targets)
        got = result()
        print(f"{label} ->", json.dumps(got))
        if not got or got.get("item") != want_item or got.get("count") != want_count:
            failures.append(f"{label}: expected {want_count} {want_item}, got {got}")
            return None
        if take:
            run("click-slot", "200")
            wait(5)
            run("click-slot", "9")
            wait(3)
            made = run("inventory")["counts"].get(want_item, 0)
            if made < want_count:
                failures.append(f"{label}: the crafted stack reached the inventory as {made}, not {want_count}")
        return got

    def empty_control(label, items, placements):
        setup(items)
        for item, mode, targets in placements:
            place(item, mode, targets)
        got = result()
        print(f"{label} ->", json.dumps(got))
        if got is not None:
            failures.append(f"{label}: control crafted {got['item']}")

    # 1. The plain shaped recipe that makes the family ingredient.
    check(
        "6 stone slabs + stone -> xtone_tile",
        [("minecraft:stone_slab", 6), ("minecraft:stone", 1)],
        [
            ("minecraft:stone_slab", "right", [str(slot) for slot in TILE_SLABS]),
            ("minecraft:stone", "right", [str(CENTRE)]),
        ],
        "xtonesreworked:xtone_tile",
        8,
        take=True,
    )

    # 2. Its control: a stick where the stone belongs.
    empty_control(
        "6 stone slabs + stick",
        [("minecraft:stone_slab", 6), ("minecraft:stick", 1)],
        [
            ("minecraft:stone_slab", "right", [str(slot) for slot in TILE_SLABS]),
            ("minecraft:stick", "right", [str(CENTRE)]),
        ],
    )

    # 3. The tag-resolving alternate recipe (mod item tag + c: dyes tag).
    check(
        "8 agon blocks + white dye -> agon_block_0",
        [("xtonesreworked:agon_block_1", 8), ("minecraft:white_dye", 1)],
        [
            ("xtonesreworked:agon_block_1", "right", [str(slot) for slot in RING]),
            ("minecraft:white_dye", "right", [str(CENTRE)]),
        ],
        "xtonesreworked:agon_block_0",
        8,
        take=True,
    )

    # 4. Its control: an item that is in neither tag.
    empty_control(
        "8 agon blocks + stick",
        [("xtonesreworked:agon_block_1", 8), ("minecraft:stick", 1)],
        [
            ("xtonesreworked:agon_block_1", "right", [str(slot) for slot in RING]),
            ("minecraft:stick", "right", [str(CENTRE)]),
        ],
    )

    # 5. The family base recipe, from the tile made in case 1.
    check(
        "8 xtone_tiles + stone slab -> agon_block_0",
        [("xtonesreworked:xtone_tile", 8), ("minecraft:stone_slab", 1)],
        [
            ("xtonesreworked:xtone_tile", "right", [str(slot) for slot in RING]),
            ("minecraft:stone_slab", "right", [str(CENTRE)]),
        ],
        "xtonesreworked:agon_block_0",
        8,
    )

    # 6. The lamp, and a wrong row.
    check(
        "2 iron + glowstone dust + 3 slabs -> flat_lamp",
        [("minecraft:iron_ingot", 2), ("minecraft:glowstone_dust", 1),
         ("minecraft:stone_slab", 3)],
        [
            ("minecraft:iron_ingot", "right", [str(103), str(105)]),
            ("minecraft:glowstone_dust", "right", [str(CENTRE)]),
            ("minecraft:stone_slab", "right", [str(slot) for slot in BOTTOM_ROW]),
        ],
        "xtonesreworked:flat_lamp",
        2,
    )
    empty_control(
        "2 iron + glowstone dust + 2 slabs + stone",
        [("minecraft:iron_ingot", 2), ("minecraft:glowstone_dust", 1),
         ("minecraft:stone_slab", 2), ("minecraft:stone", 1)],
        [
            ("minecraft:iron_ingot", "right", [str(103), str(105)]),
            ("minecraft:glowstone_dust", "right", [str(CENTRE)]),
            ("minecraft:stone_slab", "right", [str(106), str(108)]),
            ("minecraft:stone", "right", [str(107)]),
        ],
    )

    run("close")
    wait(3)
    if failures:
        for failure in failures:
            print(f"FAIL: {failure}", file=sys.stderr)
        raise SystemExit(1)
    print(
        "recipe PASS: xtone_tile, the #xtonesreworked:agon + #c:dyes/white "
        "recipe, the family base recipe and flat_lamp craft, and the "
        "wrong-ingredient controls leave the result empty"
    )


if __name__ == "__main__":
    main()
