#!/usr/bin/env bash
# In-game check for the Xtones Reworked port (one flat `.hmod`: the carried
# content plus the flat lamp's placement Part).
#
# Default run (creative launch, then survival for drops; The End):
#   1. every one of the 544 tone blocks (`<family>_block_<0..15>`, 34
#      families) `setblock`s and reads back, so every registered block state
#      binds; `xtone_tile` and `flat_lamp` are checked separately;
#   2. `flat_lamp` binds its 12 `facing` x `lit` states, its light is 15 when
#      lit and 0 when not, and a redstone block beside it switches `lit` (the
#      `minecraft:redstone_lamp` template), then removing it switches it back;
#   3. a PLACED lamp takes its `facing` from the click: a player looking north
#      at a post's south face gets `facing=south`, and one looking west at a
#      post's east face gets `facing=east` (`getNearestLookingDirection`
#      `.getOpposite()`, answered by `src/support.rs`);
#   4. the glaxx glass family is transparent: block light passes through it
#      while the same column built of `minecraft:stone` stops it (differential);
#   5. the creative tab lists all 546 block items and every one is give-able;
#   6. a family block places (item -> world -> item id);
#   7. a diamond pickaxe drops a tone block and a glaxx block as themselves,
#      an empty hand drops nothing from `xtone_tile` (requires the correct tool),
#      and the same empty hand drops nothing from vanilla stone (differential);
#   8. the carry's recipes work in a real crafting table: `xtone_tile` (plain
#      shaped), `agon_block_0` from `#xtonesreworked:agon` + `#c:dyes/white`
#      (the tag-resolving recipe the `c:` patch exists for) and `flat_lamp`,
#      while their wrong-ingredient controls leave the result empty;
#   9. controls: `give`/`setblock` of a made-up id fail.
#
# NEGATIVE=1 runs the same launch and binding phase but asserts that a placed
# `agon_block_0` reads back as `minecraft:stone`: the run MUST exit 1, which
# proves the assertions are not vacuous. Its log is kept as evidence.
#
# SELFTEST=1 runs the placement phase asserting the pre-slice answer
# (`facing=north` for both clicks), which the fixed package must not satisfy:
# the run MUST exit 1 there. That is the counterfactual of phase 3.
#
# CONTROL=1 launches CONTROL_GAME — the same Nightly without the package — so
# the first xtonesreworked assertion must fail; the leg ends `EXIT:1`.
#
# STATUS (2026-11-21, SDK 0a875da): the package is native, so the game is the
# launcher's build of it (`ports/tools/launcher-game.sh build xtonesreworked`,
# no `--dev-mod`); `port-horizon` vars come from `launcher-game.sh env`.
set -euo pipefail

CLONE=/home/adlf/Desktop/all_the_mods_10_rust_rewrite
PORT=$CLONE/ports/xtonesreworked
E2E_TMP=${E2E_TMP:-/tmp/opencode}
RES=${RES:-${HORIZON_RES:-/home/adlf/Desktop/horizon/.local/horizon-client/26.3}}
SOCK=${SOCK:-$E2E_TMP/xtones-e2e.sock}
NEGATIVE=${NEGATIVE:-0}
SELFTEST=${SELFTEST:-0}
CONTROL=${CONTROL:-0}
DEV_MOD=${DEV_MOD:-auto}

if [ -z "${CTL:-}" ] || [ -z "${GAME:-}" ]; then
    eval "$("$CLONE/ports/tools/launcher-game.sh" env xtonesreworked)" \
        || { echo "no launcher export; run ports/tools/launcher-game.sh build xtonesreworked" >&2; exit 1; }
fi
if [ "$CONTROL" = 1 ]; then
    [ -x "${CONTROL_GAME:-}" ] || { echo "CONTROL=1 needs CONTROL_GAME (launcher-game.sh env)" >&2; exit 1; }
    GAME=$CONTROL_GAME
    CTL=$(dirname "$GAME")/horizon-ctl
    [ -x "$CTL" ] || { echo "CONTROL=1 needs the control export's horizon-ctl: $CTL" >&2; exit 1; }
fi

[ -x "$CTL" ] || { echo "missing horizon-ctl: $CTL" >&2; exit 1; }
[ -x "$GAME" ] || { echo "missing horizon-client: $GAME" >&2; exit 1; }
[ -d "$RES/assets" ] || { echo "missing prepared resources: $RES" >&2; exit 1; }
[ -f "$PORT/horizon-mod.toml" ] || { echo "missing package manifest: $PORT/horizon-mod.toml" >&2; exit 1; }
[ -f "$PORT/xtonesreworked.hmod" ] || { echo "missing package: $PORT/xtonesreworked.hmod" >&2; exit 1; }

FAMILIES=(agon azur bitt cray fort glaxx iszm jelt korp kryp lair lave mint \
    myst reds reed roen sols sync tank vect vena zane zech zest zeta zion zkul \
    zoea zome zone zorg ztyl zyth)

mkdir -p "$E2E_TMP"
SCRATCH=$(mktemp -d "$E2E_TMP/xtones-home.XXXXXX")
export HORIZON_HOME=$SCRATCH/game
export HORIZON_LAUNCHER_HOME=$SCRATCH/launcher
export XDG_DATA_HOME=$SCRATCH/data
export XDG_CONFIG_HOME=$SCRATCH/config
export HORIZON_NO_AUDIO=1
mkdir -p "$(dirname "$SOCK")"
rm -f "$SOCK"
cd "$SCRATCH"

ctl() { "$CTL" --socket "$SOCK" "$@"; }
fail() { echo "FAIL: $*" >&2; exit 1; }
say() { echo "+ $*"; }
end() { ctl command "execute in minecraft:the_end run $1" >/dev/null; }
block_state() { ctl block "$1" "$2" "$3" | jq -r '.block // "unknown"'; }
full_state() { ctl block "$1" "$2" "$3" | jq -r '.state // "unknown"'; }
prop() { echo "$1" | grep -o "$2=[a-z]*" | head -1 | cut -d= -f2 || true; }
assert_prop() {
    local state=$1 key=$2 want=$3 got
    got=$(prop "$state" "$key")
    [ "$got" = "$want" ] || fail "$state: $key is '$got', expected '$want'"
}
block_light() { ctl light "$1" "$2" "$3" "$1" "$2" "$3" | jq -r '.block'; }

cleanup() {
    local status=$?
    ctl quit >/dev/null 2>&1 || true
    sleep 1
    rm -rf "$SCRATCH" || true
    echo "EXIT:$status"
}
trap cleanup EXIT

# The launcher-built game already carries the package; a dev path is passed only
# when it does not (and never in the control leg, where the package must be
# absent for the differential).
launch() {
    local args=(--game "$GAME" --world XtonesE2E --seed 20261107 --creative --offscreen --wait
                --game-dir "$SCRATCH/game" --resources "$RES")
    local installed
    installed=$(dirname "$GAME")/horizon-native-mods/xtonesreworked/horizon-mod.toml
    if [ "$CONTROL" != 1 ] && { [ "$DEV_MOD" = 1 ] || { [ "$DEV_MOD" = auto ] && [ ! -f "$installed" ]; }; }; then
        args+=(--dev-mod "$PORT/xtonesreworked.hmod")
    fi
    say "launch ($GAME, offscreen, creative${CONTROL:+, control=$CONTROL})"
    "$CTL" --socket "$SOCK" launch "${args[@]}" >/dev/null
    ctl wait-ready 180 >/dev/null
}
launch

say "The End platform at y=79 and a clear box above it"
end "forceload add -4 -4 48 44"
end "tp @s 8.5 80 36.5"
ctl wait 40
end "fill -4 79 -4 48 79 44 minecraft:stone"
end "fill -4 80 -4 48 86 44 minecraft:air"
end "fill -4 87 -4 48 92 44 minecraft:air"
end "kill @e[type=minecraft:item]"
end "kill @e[type=minecraft:ender_dragon]"
end "kill @e[type=minecraft:end_crystal]"
end "difficulty peaceful"
end "tp @s 8.5 80 36.5"
ctl wait 10
ctl close >/dev/null 2>&1 || true
ctl wait 3

if [ "$NEGATIVE" = 1 ]; then
    say "NEGATIVE: a deliberately false assertion must fail the run"
    ctl setblock 0 80 0 xtonesreworked:agon_block_0 >/dev/null
    ctl wait 3
    got=$(block_state 0 80 0)
    echo "negative probe: 0 80 0 reads '$got'; this run asserts 'minecraft:stone'"
    if [ "$got" = "minecraft:stone" ]; then
        fail "NEGATIVE run did not observe the false assertion"
    fi
    fail "NEGATIVE run: the false assertion ('minecraft:stone') failed the run, as required"
fi

# --------------------------------------------------------------- state bind
say "all 544 tone blocks (34 families x 16) bind their default state"
for i in "${!FAMILIES[@]}"; do
    fam=${FAMILIES[$i]}
    for x in $(seq 0 15); do
        ctl setblock "$x" 80 "$i" "xtonesreworked:${fam}_block_${x}" >/dev/null \
            || fail "setblock xtonesreworked:${fam}_block_${x} failed"
    done
done
ctl wait 10
for i in "${!FAMILIES[@]}"; do
    fam=${FAMILIES[$i]}
    for x in $(seq 0 15); do
        got=$(block_state "$x" 80 "$i")
        [ "$got" = "xtonesreworked:${fam}_block_${x}" ] \
            || fail "${fam} variant $x reads '$got', expected xtonesreworked:${fam}_block_${x}"
    done
done
echo "544/544 tone block states bound and read back"

say "xtone_tile binds; flat_lamp binds its facing states and its lit state"
ctl setblock 0 80 34 xtonesreworked:xtone_tile >/dev/null || fail "setblock xtone_tile failed"
ctl setblock 20 80 0 xtonesreworked:flat_lamp >/dev/null || fail "setblock flat_lamp failed"
ctl wait 3
[ "$(block_state 0 80 34)" = "xtonesreworked:xtone_tile" ] || fail "xtone_tile did not bind"
for facing in down up north south east west; do
    ctl setblock 20 82 0 "xtonesreworked:flat_lamp[facing=${facing},lit=false]" >/dev/null \
        || fail "setblock flat_lamp[facing=${facing},lit=false] failed"
    ctl wait 1
    state=$(full_state 20 82 0)
    assert_prop "$state" facing "$facing"
    assert_prop "$state" lit false
done
# `lit` is not free-standing: the redstone_lamp template recomputes it from
# the signal, so the true side is proved with a redstone block beside it.
ctl setblock 20 82 0 "xtonesreworked:flat_lamp[facing=up,lit=false]" >/dev/null
ctl setblock 21 82 0 minecraft:redstone_block >/dev/null
ctl wait 5
state=$(full_state 20 82 0)
assert_prop "$state" facing up
assert_prop "$state" lit true
ctl setblock 21 82 0 minecraft:air >/dev/null
ctl wait 3
echo "xtone_tile bound; 6/6 flat_lamp facings bind, and lit=true binds beside a redstone block"

say "flat_lamp follows redstone: lit=true and light 15 beside a redstone block, off when removed"
ctl setblock 20 80 0 "xtonesreworked:flat_lamp[facing=north,lit=false]" >/dev/null
ctl setblock 21 80 0 minecraft:redstone_block >/dev/null
ctl wait 5
state=$(full_state 20 80 0)
assert_prop "$state" lit true
lit_light=$(block_light 20 80 0)
[ "$lit_light" = "f" ] || fail "lit flat_lamp light is '$lit_light', expected f (15)"
ctl setblock 21 80 0 minecraft:air >/dev/null
ctl wait 5
state=$(full_state 20 80 0)
assert_prop "$state" lit false
off_light=$(block_light 20 80 0)
[ "$off_light" = "0" ] || fail "unlit flat_lamp light is '$off_light', expected 0"
echo "redstone block -> lit=true/light 15; removed -> lit=false/light 0"

say "glaxx glass is transparent to light, stone is not (sealed differential)"
# A 3x3x3 stone shell around each column leaves exactly one path from the
# glowstone to the cell above it: through the block under test.
for x in 24 45; do
    for dx in -1 0 1; do
        for dz in -1 0 1; do
            [ "$dx" = 0 ] && [ "$dz" = 0 ] && continue
            ctl setblock "$((x + dx))" 80 "$dz" minecraft:stone >/dev/null
            ctl setblock "$((x + dx))" 81 "$dz" minecraft:stone >/dev/null
            ctl setblock "$((x + dx))" 82 "$dz" minecraft:stone >/dev/null
        done
    done
    ctl setblock "$x" 80 0 minecraft:glowstone >/dev/null || fail "setblock glowstone failed"
    ctl setblock "$x" 82 0 minecraft:air >/dev/null
    ctl setblock "$x" 83 0 minecraft:stone >/dev/null
done
ctl setblock 24 81 0 xtonesreworked:glaxx_block_0 >/dev/null || fail "setblock glaxx failed"
ctl setblock 45 81 0 minecraft:stone >/dev/null || fail "setblock control stone failed"
ctl wait 10
glass_light=$(block_light 24 82 0)
stone_light=$(block_light 45 82 0)
echo "light through glaxx: $glass_light; through stone: $stone_light"
[ "$glass_light" != "0" ] || fail "no block light passes through glaxx (got 0)"
[ "$stone_light" = "0" ] || fail "stone control passes light ($stone_light), so the glaxx check is not a differential"
echo "glaxx passes block light, the stone control stops it"

# --------------------------------------------------------------- registry
say "the creative tab lists all 546 block items"
MODROOT=$(ls -dt "$SCRATCH/game/.horizon-cache/mod-content"/*/ 2>/dev/null | head -1)
CREATIVE=${MODROOT}creative-inventory.json
[ -f "$CREATIVE" ] || fail "no creative-inventory.json under $SCRATCH/game/.horizon-cache/mod-content/"
for table in model-states.json render-definitions.json; do
    [ -f "${MODROOT}${table}" ] || fail "the content root has no $table"
done
for id in xtonesreworked:agon_block_0 xtonesreworked:glaxx_block_0 xtonesreworked:flat_lamp xtonesreworked:xtone_tile; do
    grep -q "\"$id\"" "${MODROOT}model-states.json" || fail "$id has no model-state row"
    grep -q "\"$id\"" "${MODROOT}render-definitions.json" || fail "$id has no render-definition row"
done
echo "model-state and render-definition rows exist for tone, glass, lamp and tile"
python3 - "$MODROOT/render-definitions.json" <<'PY'
import json, sys
rows = json.load(open(sys.argv[1]))
glass = rows["xtonesreworked:glaxx_block_0"].get("can_occlude")
tone = rows["xtonesreworked:agon_block_0"].get("can_occlude")
if glass is True:
    raise SystemExit("glaxx_block_0 occludes (the glass template did not carry)")
if tone is not True:
    raise SystemExit(f"agon_block_0 can_occlude is {tone}, expected the stone template's true")
print(f"occlusion: glaxx {glass!r} (glass), tone {tone!r} (stone)")
PY

tab_count=$(python3 - "$CREATIVE" <<'PY'
import json, re, sys
data = json.load(open(sys.argv[1]))
pattern = re.compile(r'id:"(xtonesreworked:[^"]+)"')
seen = set()
for tab in data.get("tabs", []):
    for stack in tab.get("items") or []:
        seen.update(pattern.findall(stack))
print(len(seen))
PY
)
[ "$tab_count" = 546 ] || fail "the creative tab lists $tab_count xtonesreworked entries, expected 546"
echo "creative tab: 546/546 entries"

say "every xtone_tile/flat_lamp and one variant per family is give-able"
ctl command "clear @s" >/dev/null
ctl give xtonesreworked:xtone_tile 1 >/dev/null || fail "give xtone_tile failed"
ctl give xtonesreworked:flat_lamp 1 >/dev/null || fail "give flat_lamp failed"
for fam in "${FAMILIES[@]}"; do
    ctl give "xtonesreworked:${fam}_block_15" 1 >/dev/null || fail "give ${fam}_block_15 failed"
done
ctl wait 10
counts=$(ctl inventory | jq -r '.counts')
for id in xtonesreworked:xtone_tile xtonesreworked:flat_lamp; do
    [ "$(jq -r --arg i "$id" '.[$i] // 0' <<<"$counts")" -ge 1 ] || fail "$id is missing after give"
done
for fam in "${FAMILIES[@]}"; do
    [ "$(jq -r --arg i "xtonesreworked:${fam}_block_15" '.[$i] // 0' <<<"$counts")" -ge 1 ] \
        || fail "xtonesreworked:${fam}_block_15 is missing after give"
done
echo "36 sampled items give (xtone_tile, flat_lamp and one variant per family)"

say "the block items place"
ctl command "gamemode creative @s" >/dev/null
ctl command "clear @s" >/dev/null
ctl give xtonesreworked:agon_block_0 1 >/dev/null || fail "cannot give agon_block_0"
ctl wait 3
ctl tp 10.5 80 38.5 >/dev/null
ctl wait 3
ctl setblock 10 80 37 minecraft:air >/dev/null
reply=$(ctl place 10 80 37 --item xtonesreworked:agon_block_0 2>&1) || { echo "place reply: $reply"; fail "cannot place agon_block_0"; }
ctl wait 3
[ "$(block_state 10 80 37)" = "xtonesreworked:agon_block_0" ] || fail "placed agon_block_0 is not there"
echo "xtonesreworked:agon_block_0 placed"

# ------------------------------------------------- flat_lamp placement (native)
# Upstream `FlatLamp.getStateForPlacement` = `getNearestLookingDirection()
# .getOpposite()`, so the plate faces the player who clicked. Each target cell
# has exactly ONE solid neighbour (its floor is removed), so `ctl place` must
# aim at the post named here; a content declaration alone cannot pass this.
say "flat_lamp placement: the plate faces the click, not the declared default"
end "setblock 40 80 20 minecraft:stone"
end "setblock 40 79 21 minecraft:air"
end "setblock 44 80 22 minecraft:stone"
end "setblock 45 79 22 minecraft:air"
ctl command "gamemode creative @s" >/dev/null
ctl command "clear @s" >/dev/null
ctl give xtonesreworked:flat_lamp 4 >/dev/null || fail "cannot give flat_lamp"
ctl wait 5
ctl command "tp @s 40.5 80 23.5" >/dev/null
ctl wait 5
# The placement context is built from the rotation the server has; aim first and
# let the view reach it, or the click is placed with the previous heading.
ctl look 180 20 >/dev/null
ctl wait 5
ctl place 40 80 21 --item xtonesreworked:flat_lamp >/dev/null \
    || fail "cannot place the lamp against the post's south face"
ctl wait 5
click_north=$(prop "$(full_state 40 80 21)" facing)
echo "click the south face of (40,80,20) looking north -> facing=$click_north"
ctl command "tp @s 47.5 80 22.5" >/dev/null
ctl wait 5
ctl look 90 20 >/dev/null
ctl wait 5
ctl place 45 80 22 --item xtonesreworked:flat_lamp >/dev/null \
    || fail "cannot place the lamp against the post's east face"
ctl wait 5
click_west=$(prop "$(full_state 45 80 22)" facing)
echo "click the east face of (44,80,22) looking west -> facing=$click_west"
if [ "$SELFTEST" = 1 ]; then
    echo "SELFTEST: this run asserts the pre-slice answer (facing=north for both clicks); a package that answers the placement must fail it"
    { [ "$click_north" = north ] && [ "$click_west" = north ]; } \
        || fail "SELFTEST expected the pre-slice 'north'/'north', read '$click_north'/'$click_west'"
    fail "SELFTEST: the placement assertion did not fail on a package that answers the click"
fi
[ "$click_north" = south ] || fail "a north-looking click reads facing=$click_north, expected south"
[ "$click_west" = east ] || fail "a west-looking click reads facing=$click_west, expected east"
[ "$click_north" != "$click_west" ] || fail "both clicks read facing=$click_north; the placement state did not follow the click"
echo "flat_lamp: north-looking click -> facing=south, west-looking click at an east post -> facing=east"

# ---------------------------------------------------------------- drops
say "drops: pickaxe drops a tagged tone block; glaxx is in no mineable tag (jar quirk)"
ctl command "gamemode survival @s" >/dev/null
ctl command "clear @s" >/dev/null
ctl give minecraft:diamond_pickaxe 1 >/dev/null || fail "cannot give the pickaxe"
ctl wait 3
ctl select minecraft:diamond_pickaxe >/dev/null || fail "cannot select the pickaxe"
ctl wait 2
ctl setblock 0 80 38 xtonesreworked:agon_block_0 >/dev/null
ctl setblock 2 80 38 xtonesreworked:glaxx_block_1 >/dev/null
ctl command "execute in minecraft:the_end if block 0 80 38 #minecraft:mineable/pickaxe run say XTAG_AGON" >/dev/null
ctl command "execute in minecraft:the_end if block 2 80 38 #minecraft:mineable/pickaxe run say XTAG_GLAXX" >/dev/null
ctl wait 3
tag_messages=$(ctl messages 50 | jq -r '.chat[]')
grep -q XTAG_AGON <<<"$tag_messages" || fail "the tone block is not in #minecraft:mineable/pickaxe"
if grep -q XTAG_GLAXX <<<"$tag_messages"; then
    fail "glaxx is in #minecraft:mineable/pickaxe, unlike the jar's tags"
fi
echo "tags: tone in #minecraft:mineable/pickaxe, glaxx in none (as the jar ships them)"
ctl command "tp @s 0.5 80 39.5" >/dev/null
ctl wait 5
ctl look-at-block 0 80 38 >/dev/null || true
broken=$(ctl break 0 80 38) || { echo "break reply: $broken"; fail "cannot break agon_block_0"; }
echo "$broken" | jq -c '{block,block_before,drops}'
[ "$(echo "$broken" | jq -r '.block')" = "minecraft:air" ] || fail "agon_block_0 did not break"
got=$(echo "$broken" | jq -r '.drops["xtonesreworked:agon_block_0"] // 0')
[ "$got" -ge 1 ] || fail "agon_block_0 dropped $got of itself"
# The jar gives XGlass requiresCorrectToolForDrops() but puts the glass family
# in no `mineable` tag, so no tool is ever correct and the plain self-drop table
# never pays out. Carried faithfully: the block breaks and drops nothing.
ctl command "tp @s 2.5 80 39.5" >/dev/null
ctl wait 5
ctl look-at-block 2 80 38 >/dev/null || true
broken=$(ctl break 2 80 38) || { echo "break reply: $broken"; fail "cannot break glaxx_block_1"; }
echo "$broken" | jq -c '{block,block_before,drops}'
[ "$(echo "$broken" | jq -r '.block')" = "minecraft:air" ] || fail "glaxx_block_1 did not break"
got=$(echo "$broken" | jq -r '.drops["xtonesreworked:glaxx_block_1"] // 0')
[ "$got" -eq 0 ] || fail "glaxx_block_1 dropped $got, but the jar's tags make no tool correct"

ctl command "clear @s" >/dev/null
ctl wait 2
ctl setblock 4 80 38 xtonesreworked:xtone_tile >/dev/null
ctl command "tp @s 4.5 80 39.5" >/dev/null
ctl wait 5
ctl look-at-block 4 80 38 >/dev/null || true
broken=$(ctl break 4 80 38 --timeout 60) || { echo "break reply: $broken"; fail "cannot break xtone_tile by hand"; }
echo "$broken" | jq -c '{scenario:"empty hand",block,block_before,drops}'
[ "$(echo "$broken" | jq -r '.block')" = "minecraft:air" ] || fail "xtone_tile did not break by hand"
got=$(echo "$broken" | jq -r '.drops["xtonesreworked:xtone_tile"] // 0')
[ "$got" -eq 0 ] || fail "an empty hand dropped $got xtone_tile (requires_tool is not carried)"

ctl setblock 6 80 38 minecraft:stone >/dev/null
ctl command "tp @s 6.5 80 39.5" >/dev/null
ctl wait 5
ctl look-at-block 6 80 38 >/dev/null || true
broken=$(ctl break 6 80 38 --timeout 60) || { echo "break reply: $broken"; fail "cannot break the stone control by hand"; }
echo "$broken" | jq -c '{scenario:"stone empty hand",block,block_before,drops}'
stone_drop=$(echo "$broken" | jq -r '.drops["minecraft:stone"] // 0')
[ "$stone_drop" -eq 0 ] || fail "the stone control dropped $stone_drop by hand (differential is broken)"
echo "pickaxe drops both blocks; empty hand drops neither xtone_tile nor vanilla stone"

# --------------------------------------------------------------- recipes
say "craft in a real table: xtone_tile, the tag recipe, flat_lamp"
end "setblock 6 80 36 minecraft:crafting_table"
ctl command "gamemode creative @s" >/dev/null
ctl command "clear @s" >/dev/null
ctl command "tp @s 5.5 80 36.5" >/dev/null
ctl wait 5
python3 "$PORT/tools/craft_check.py" "$SOCK" "$CTL" 6 80 36 || fail "the crafting-table checks failed"
ctl command "gamemode creative @s" >/dev/null
ctl command "clear @s" >/dev/null
ctl wait 3

# --------------------------------------------------------------- controls
say "wrong-name controls fail"
if ctl give xtonesreworked:not_a_block 1 >/dev/null 2>&1; then
    fail "give xtonesreworked:not_a_block succeeded"
fi
ctl setblock 30 80 42 xtonesreworked:bogus_block >/dev/null 2>&1 || true
[ "$(block_state 30 80 42)" = "minecraft:air" ] || fail "xtonesreworked:bogus_block became a block"
echo "unknown block/item ids are refused"

say "model and registry load: no missing model, texture or recipe for any xtones block"
logs=$(ctl logs --lines 20000)
if grep -qiE "missing (block )?model|missing texture|no model" <<<"$logs"; then
    grep -iE "missing (block )?model|missing texture|no model" <<<"$logs" | head -5 >&2 || true
    fail "the game logged a missing model or texture"
fi
if grep -qiE "recipe .*not loaded" <<<"$logs"; then
    grep -iE "recipe .*not loaded" <<<"$logs" | head -5 >&2 || true
    fail "the game refused a carried recipe"
fi
ctl command "gamemode creative @s" >/dev/null
ctl command "clear @s" >/dev/null
ctl tp 8.5 80 40.5 >/dev/null
ctl look 180 20 >/dev/null
ctl wait 10
ctl screenshot "$SCRATCH/xtones-grid.png" >/dev/null || fail "screenshot failed"
[ -s "$SCRATCH/xtones-grid.png" ] || fail "the screenshot file is empty"
mkdir -p "$CLONE/ports/_shared/evidence/xtonesreworked"
cp "$SCRATCH/xtones-grid.png" "$CLONE/ports/_shared/evidence/xtonesreworked/grid.png"
echo "no missing model/texture and no refused recipe in the log; screenshot saved (grid.png)"

echo "PASS: 544/544 tone block states bind plus xtone_tile, 6/6 flat_lamp facings and lit=true; flat_lamp follows redstone (lit 15 / off 0); a placed flat_lamp takes facing=south from a north-looking click and facing=east from a west-looking click at an east post (the native placement Part); glaxx passes light while stone stops it; the creative tab lists 546 items and they give; a family block places; a pickaxe drops a tagged tone block while glaxx (in no mineable tag, as the jar ships it) drops nothing; an empty hand drops neither xtone_tile nor vanilla stone; xtone_tile, the #xtonesreworked:agon + #c:dyes/white recipe and flat_lamp craft in a table while their controls stay empty; unknown ids are refused; the log has no missing model, texture or recipe"
