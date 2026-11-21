//! Xtones Reworked — the carried decorative blocks, plus the flat lamp's placement rule.
//!
//! The 546 blocks and their models, textures, recipes, loot and tags are content in this
//! same package (`assets/`, `data/`). The one behaviour upstream writes in Java is the flat
//! lamp: `lit` follows a redstone signal (the `minecraft:redstone_lamp` template carries it)
//! and `facing` comes from the placer's look direction, which a content declaration cannot
//! answer. [`runtime`] holds that rule as pure data and its tests; [`support`] answers the
//! game's one moment for `xtonesreworked:flat_lamp` only.

pub mod runtime;
mod support;

use mod_api::{
    self, BlockPart, BlockState, Hooks, LevelHost, Registrar, RegistrationContext,
    StateForPlacementEvent,
};

/// The flat lamp's Part: the game asks it for the lamp's block only.
#[derive(Clone, Copy, Debug)]
struct FlatLamp;

#[mod_api::horizon_part]
impl BlockPart for FlatLamp {
    /// A lamp is about to be placed: answer its state with `facing` taken from the
    /// placer's look direction, as upstream's `getStateForPlacement` does.
    fn state_for_placement(
        &self,
        level: &dyn LevelHost,
        event: &mut StateForPlacementEvent<'_>,
    ) -> Option<Option<BlockState>> {
        support::state_for_placement(level, event)
    }
}

#[derive(Default)]
struct Mod;

#[mod_api::horizon_mod]
impl Hooks for Mod {
    /// Attach the lamp's placement Part to the carried block. Nothing is registered:
    /// the blocks, items and data are content in this same package.
    fn register(&self, r: &mut dyn Registrar, _cx: &RegistrationContext) {
        let key = r.block_key(runtime::LAMP);
        r.block_part(key, FlatLamp);
    }
}
