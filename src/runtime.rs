//! The flat lamp's facing rule — pure, no game access, unit-tested by `cargo test`.
//!
//! Upstream `FlatLamp.getStateForPlacement` sets `facing` to
//! `context.getNearestLookingDirection().getOpposite()`, and the plate shape sits
//! on the `facing` side, so a lamp clicked by a player looking north is placed
//! with `facing=south` (the plate toward the player). [`nearest_look`] is a
//! faithful port of this pin's `Direction.orderedByNearest(entity)[0]`
//! (`horizon/crates/horizon-world/src/level/place.rs:82`), and [`lamp_facing`]
//! takes its opposite. [`placement_state`] is the block-state string the game
//! parses back, so the whole rule — angles to state — is provable without a
//! running game.

/// The id of the carried block this rule answers for.
pub const LAMP: &str = "xtonesreworked:flat_lamp";

/// The six directions a lamp's plate can face (the `facing` property values).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Facing {
    /// The plate is on the bottom face.
    Down,
    /// The plate is on the top face.
    Up,
    /// The plate is on the north face (`-Z`).
    North,
    /// The plate is on the south face (`+Z`).
    South,
    /// The plate is on the west face (`-X`).
    West,
    /// The plate is on the east face (`+X`).
    East,
}

impl Facing {
    /// The value the blockstate's `facing` property takes.
    pub const fn name(self) -> &'static str {
        match self {
            Self::Down => "down",
            Self::Up => "up",
            Self::North => "north",
            Self::South => "south",
            Self::West => "west",
            Self::East => "east",
        }
    }

    /// The direction facing the other way, as `Direction.opposite` does.
    pub const fn opposite(self) -> Self {
        match self {
            Self::Down => Self::Up,
            Self::Up => Self::Down,
            Self::North => Self::South,
            Self::South => Self::North,
            Self::West => Self::East,
            Self::East => Self::West,
        }
    }
}

/// The direction a placer with these view angles looks along, rounded to the
/// nearest axis: `Direction.orderedByNearest(entity)[0]`, ported branch for
/// branch from `place.rs:82`, with `std`'s sine and cosine in place of the
/// game's own table (the two differ only at an exact axis boundary).
///
/// `yaw` and `pitch` are degrees: yaw 0 looks south, 90 west, 180 north, 270
/// east, and pitch 90 looks straight down.
#[must_use]
pub fn nearest_look(yaw: f32, pitch: f32) -> Facing {
    let pitch_rad = f64::from(pitch) * (std::f64::consts::PI / 180.0);
    let yaw_rad = -f64::from(yaw) * (std::f64::consts::PI / 180.0);
    let pitch_sin = pitch_rad.sin();
    let pitch_cos = pitch_rad.cos();
    let yaw_sin = yaw_rad.sin();
    let yaw_cos = yaw_rad.cos();
    let x_pos = yaw_sin > 0.0;
    let y_pos = pitch_sin < 0.0;
    let z_pos = yaw_cos > 0.0;
    let x_yaw = if x_pos { yaw_sin } else { -yaw_sin };
    let y_mag = if y_pos { -pitch_sin } else { pitch_sin };
    let z_yaw = if z_pos { yaw_cos } else { -yaw_cos };
    let x_mag = x_yaw * pitch_cos;
    let z_mag = z_yaw * pitch_cos;
    let ax = if x_pos { Facing::East } else { Facing::West };
    let ay = if y_pos { Facing::Up } else { Facing::Down };
    let az = if z_pos { Facing::South } else { Facing::North };
    // Only the game's first entry is needed, so the two branches whose first
    // entry is the same are folded (the table's remaining five are the
    // opposites of these three, in the game's order).
    if x_yaw > z_yaw {
        if y_mag > x_mag { ay } else { ax }
    } else if y_mag > z_mag {
        ay
    } else {
        az
    }
}

/// The `facing` a lamp placed by a placer with these view angles takes: the
/// opposite of the nearest looking direction, which puts the plate toward the
/// placer.
#[must_use]
pub fn lamp_facing(yaw: f32, pitch: f32) -> Facing {
    nearest_look(yaw, pitch).opposite()
}

/// The state the game is asked to place: the block's own default state with
/// `facing` set, which leaves `lit=false` as the default does.
#[must_use]
pub fn placement_state(facing: Facing) -> String {
    format!("{LAMP}[facing={}]", facing.name())
}

#[cfg(test)]
mod tests {
    use super::*;

    /// A lamp clicked by a player looking north must face south, toward the
    /// player — the two e2e clicks (a north-looking one, then a west-looking one
    /// on an east post) must not both read the declared default.
    #[test]
    fn a_placed_lamp_faces_the_placer() {
        assert_eq!(lamp_facing(180.0, 0.0), Facing::South, "looking north");
        assert_eq!(lamp_facing(90.0, 0.0), Facing::East, "looking west");
        assert_eq!(lamp_facing(0.0, 0.0), Facing::North, "looking south");
        assert_eq!(lamp_facing(270.0, 0.0), Facing::West, "looking east");
    }

    /// The e2e aims slightly down at the clicked face (about -20 degrees); the
    /// vertical component must not take the answer over.
    #[test]
    fn a_slightly_downward_aim_still_takes_the_horizontal_axis() {
        assert_eq!(lamp_facing(180.0, -20.0), Facing::South);
        assert_eq!(lamp_facing(90.0, -20.0), Facing::East);
    }

    /// Looking straight down or up puts the plate on the floor or the ceiling,
    /// as `orderedByNearest` answers the vertical axis.
    #[test]
    fn a_steep_aim_faces_up_or_down() {
        assert_eq!(lamp_facing(180.0, 90.0), Facing::Up, "looking down");
        assert_eq!(lamp_facing(180.0, -90.0), Facing::Down, "looking up");
    }

    /// The state string is the one the game parses: the block id, `facing` set,
    /// `lit` left at the declaration's default.
    #[test]
    fn the_placement_state_names_the_block_and_the_facing() {
        assert_eq!(
            placement_state(Facing::South),
            "xtonesreworked:flat_lamp[facing=south]"
        );
        assert_eq!(
            placement_state(Facing::Up),
            "xtonesreworked:flat_lamp[facing=up]"
        );
        for facing in [
            Facing::Down,
            Facing::Up,
            Facing::North,
            Facing::South,
            Facing::West,
            Facing::East,
        ] {
            assert_eq!(facing.name(), facing.opposite().opposite().name());
            assert_ne!(facing.name(), facing.opposite().name());
        }
    }
}
