// The one game-facing helper of this package: the lamp's `getStateForPlacement`.
//
// Upstream `FlatLamp.getStateForPlacement(BlockPlaceContext)` builds its default
// state with `facing = context.getNearestLookingDirection().getOpposite()`.
// `BlockPart::state_for_placement` is asked for every placement, so this answers
// only when the state is the lamp's own and leaves every other block to vanilla.
//
// The rule itself (angles -> facing -> state string) is in `runtime`, where
// `cargo test` proves it without a game; this module only reads the event and
// resolves the string through the level.

use mod_api::{BlockState, LevelHost, StateForPlacementEvent};

use crate::runtime;

/// The state the lamp is placed in: its own default state with `facing` set from
/// the placer's look direction, or `None` to leave the placement to vanilla
/// (another block, or a state name the game could not resolve).
pub(crate) fn state_for_placement(
    level: &dyn LevelHost,
    event: &StateForPlacementEvent<'_>,
) -> Option<Option<BlockState>> {
    let block = level.state_block(event.state)?;
    if block != runtime::LAMP {
        return None;
    }
    let facing = runtime::lamp_facing(event.context.yaw, event.context.pitch);
    let state = level.block_state_id(&runtime::placement_state(facing))?;
    Some(Some(state))
}
