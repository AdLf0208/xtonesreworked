#!/usr/bin/env bash
# `flat_lamp` placement-orientation probe — the directional assertion, on its own.
#
# Upstream `FlatLamp.getStateForPlacement` takes
# `context.getNearestLookingDirection().getOpposite()`: the plate faces the
# player, so a lamp clicked from the south of a north wall gets `facing=south`
# and one clicked from the west of an east face gets `facing=west`. A content
# declaration alone cannot answer that moment (the state never changes), so this
# probe is what proves the native half is live.
#
#   DEV_MOD=<content dir | package.hmod>   the package to load (its only mod)
#   CTL / GAME / RES                       the game (default: the shared pin build)
#   EXPECT=auto|north                      auto = `south`/`west` (the fixed rule);
#                                          north = the pre-slice default, which a
#                                          fixed package MUST fail (SELFTEST)
#   CONTROL=1                              launch without the package at all
#
# Both placements are made against exactly one solid neighbour, so `ctl place`
# cannot aim at a floor instead of the clicked wall face; the player's position
# is what "clicking north" / "clicking east" means here.
#
# Last line of every run is `EXIT:<status>` (the e2e-log gate reads it).
set -euo pipefail

CLONE=/home/adlf/Desktop/all_the_mods_10_rust_rewrite
PORT=$CLONE/ports/xtonesreworked
RES=${RES:-${HORIZON_RES:-/home/adlf/Desktop/horizon/.local/horizon-client/26.3}}
SOCK=${SOCK:-/tmp/opencode/xtones-placement.sock}
EXPECT=${EXPECT:-auto}
DEV_MOD=${DEV_MOD:-auto}
CONTROL=${CONTROL:-0}

if [ -z "${CTL:-}" ] || [ -z "${GAME:-}" ]; then
    eval "$("$CLONE/ports/tools/shared-bin.sh" env)"
fi

[ -x "$CTL" ] || { echo "missing horizon-ctl: $CTL" >&2; exit 1; }
[ -x "$GAME" ] || { echo "missing horizon-client: $GAME" >&2; exit 1; }
[ -d "$RES/assets" ] || { echo "missing prepared resources: $RES" >&2; exit 1; }

SCRATCH=$(mktemp -d /tmp/opencode/xtones-placement.XXXXXX)
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
facing() {
    ctl block "$1" "$2" "$3" | jq -r '.state // "unknown"' \
        | grep -o 'facing=[a-z]*' | head -1 | cut -d= -f2
}

cleanup() {
    local status=$?
    ctl quit >/dev/null 2>&1 || true
    sleep 1
    rm -rf "$SCRATCH" || true
    echo "EXIT:$status"
}
trap cleanup EXIT

say "launch ($GAME, offscreen, creative)"
args=(--game "$GAME" --world XtonesPlacement --seed 20261121 --creative --offscreen --wait
      --game-dir "$SCRATCH/game" --resources "$RES")
installed=$(dirname "$GAME")/horizon-native-mods/xtonesreworked/horizon-mod.toml
if [ "$CONTROL" != 1 ] && { [ "$DEV_MOD" = 1 ] || { [ "$DEV_MOD" = auto ] && [ ! -f "$installed" ]; }; }; then
    [ -n "${DEV_CONTENT:-}" ] || fail "DEV_CONTENT must name the content directory or package to load"
    args+=(--dev-mod "$DEV_CONTENT")
fi
"$CTL" --socket "$SOCK" launch "${args[@]}" >/dev/null
ctl wait-ready 180 >/dev/null

say "The End platform at y=79, and two holes so each lamp has one clicked wall"
end "forceload add -8 -8 24 24"
end "tp @s 10.5 80 10.5"
ctl wait 40
end "fill -8 79 -8 24 79 24 minecraft:stone"
end "fill -8 80 -8 24 88 24 minecraft:air"
end "kill @e[type=minecraft:item]"
end "kill @e[type=minecraft:ender_dragon]"
end "kill @e[type=minecraft:end_crystal]"
end "difficulty peaceful"
# Case A: a post at (10,80,4); its SOUTH face is the only solid neighbour of the
# target (10,80,5) — the floor under the target is removed on purpose.
end "setblock 10 80 4 minecraft:stone"
end "setblock 10 79 5 minecraft:air"
# Case B: a post at (16,80,5) whose EAST face is the only solid neighbour of the
# target (17,80,5); the player stands east of it and looks west, so the plate
# must face east.
end "setblock 16 80 5 minecraft:stone"
end "setblock 17 79 5 minecraft:air"
ctl command "gamemode creative @s" >/dev/null
ctl give xtonesreworked:flat_lamp 4 >/dev/null || fail "cannot give flat_lamp (is the package loaded?)"
ctl wait 5

say "click the post's south face from the south: the plate must face the player (facing=south)"
ctl command "tp @s 10.5 80 7.5" >/dev/null
ctl wait 5
ctl look 180 20 >/dev/null
ctl wait 5
[ "${DIAG:-0}" = 1 ] && { echo "diag before A: $(ctl state | jq -c '{yaw:.player.yaw,pitch:.player.pitch,eye:.player.eye}')"; echo "diag looking-at A: $(ctl looking-at)"; }
ctl place 10 80 5 --item xtonesreworked:flat_lamp >/dev/null \
    || fail "cannot place the lamp against the north post's south face"
ctl wait 5
north_click=$(facing 10 80 5)
[ "${DIAG:-0}" = 1 ] && echo "diag after A: $(ctl state | jq -c '{yaw:.player.yaw,pitch:.player.pitch}')"
echo "click north -> facing=$north_click"

say "click the east face of the post at (16,80,5) from the east: the plate must face east"
ctl command "tp @s 20.5 80 5.5" >/dev/null
ctl wait 5
ctl look 90 20 >/dev/null
ctl wait 5
ctl place 17 80 5 --item xtonesreworked:flat_lamp >/dev/null \
    || fail "cannot place the lamp against the west post's east face"
ctl wait 5
west_look=$(facing 17 80 5)
[ "${DIAG:-0}" = 1 ] && echo "diag after B: $(ctl state | jq -c '{yaw:.player.yaw,pitch:.player.pitch}')"
echo "click the east face (looking west) -> facing=$west_look"

if [ "$EXPECT" = north ]; then
    echo "SELFTEST: this run asserts the pre-slice answer (facing=north for both), which a fixed package must not satisfy"
    [ "$north_click" = north ] && [ "$west_look" = north ] \
        || fail "SELFTEST expected the pre-slice 'north'/'north', read '$north_click'/'$west_look'"
    fail "SELFTEST: the placement assertions did not fail on a package that answers the click"
fi

[ "$north_click" = south ] || fail "a north-looking click reads facing=$north_click, expected south"
[ "$west_look" = east ] || fail "a west-looking click on an east post reads facing=$west_look, expected east"
[ "$north_click" != "$west_look" ] || fail "both clicks read facing=$north_click; the placement state did not follow the click"
echo "PASS: flat_lamp placement follows the click — north-looking -> facing=south, west-looking at an east post -> facing=east"
