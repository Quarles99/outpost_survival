- Complex world simulation
- history
- magic
- long term progression in the same world
- modding support
- vertical z levels
- things to improve from DF:
	- gameplay not reliant on frame rate
	- better naming conventions
	- better UI
	- more intuitive progression
	- magic system
	- sound effects
	- building

## Architectural impact (assessed 2026-07-25, not a plan - nothing built)

Honest read against the current codebase, item by item:

- **Vertical z-levels is the expensive one.** It invalidates or forces a
  rework of several load-bearing pieces at once: `IsoUtils`'s two-axis
  `grid_to_screen`/`screen_to_grid` (`TILE_WIDTH=128`/`TILE_HEIGHT=64` assumes
  one flat plane), `WorldGrid`'s single-`Vector2i`-keyed occupancy plus the
  tree/rock registries (would need a third axis or a per-level grid), the
  entire `z_index`-layered draw scheme documented at length in `CLAUDE.md`
  (`IsoGround` at -2, farm plots at -1, everything else at 0 - z-levels would
  make `z_index` do double duty for both draw-order-within-a-level and
  which-level-is-on-top), and `NavigationRegion2D` baking
  (`Base._rebake_navigation`), which is strictly 2D. This is a foundational
  rewrite, not an incremental feature - by far the biggest single risk in this
  list.
- **Complex world sim / history** is comparatively cheap. It's largely
  additive over the existing autoload pattern (`GameState`, `WorldGrid`,
  `DayNightCycle` already model persistent, ticking global state) - a new
  autoload or two in the same shape, not a rearchitecture.
- **Modding support** wants resource-driven catalogs instead of hardcoded
  data. `BuildingCatalog`'s static-Dictionary-of-options shape is already
  halfway there; the gap is exposing that data as loadable external resources
  rather than compiled-in constants.
- **Magic** already has a foothold in the combat system - spell sounds and
  mage units exist (`combat_unit.gd`'s `_mage_should_hold_back`), so this
  isn't starting from zero.