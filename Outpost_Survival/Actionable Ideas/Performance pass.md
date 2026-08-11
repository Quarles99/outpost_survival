- Optimize code for efficiency
- Compress large files
- Delete unused code

## Progress (2026-07-25) - partially done, kept open

**Done:**
- **Export filter fix** (the highest-leverage item). `export_presets.cfg`'s Web
  preset had `export_filter="all_resources"` with no exclude, which bundled the
  *entire* `sound/` tree (1.6 GB, 4,229 files) into every build even though only
  33 were actually `preload()`d. Copied those 29 combat/gather SFX files (the 4
  root-level UI/level-up sounds were already outside the bloated packs) into a
  new `sound/sfx/` folder, repointed every `preload()` in `character.gd`/
  `combat_unit.gd` at it, then set `exclude_filter` on the two giant source
  packs (`sound/FilmCow Recorded SFX/*`, `sound/Free Fantasy SFX Pack By
  TomMusic/*`). Verified with a real `--export-release` run (not just reasoning
  about it): 362 MB -> 40 MB, all 29 sfx files present in the pack, zero files
  from either giant pack leaked in.
  - Note: `include_filter` does **not** override `exclude_filter` for ordinary
    resource files the way the Godot export dialog's layout suggests - tested
    empirically, a file matching both filters still gets dropped. That's why
    the fix moved the used files out of the excluded trees instead of trying
    to carve them back in with `include_filter`.
- Deleted `scenes/workstation/Workstation.tscn` (referenced only in a comment)
  and 16 dead `iso_*.svg`/legacy top-down `.svg` files (everything except
  `iso_selection_ring.svg`, which `Character.tscn` still uses).
- Deleted the 3 unused `IsometricTRPGAssetPack_{MapIndicators,OutlinedEntities,
  UI}.png` sheets and the 7 unused `UIBundleFree/UIBundleFree/*.png` sheets
  (only `freefantasy.png` is live, via `resources/theme/ui_theme.tres`) plus
  the whole `UIBundleFree/__MACOSX/` junk directory.
- Removed `Workstation.RESOURCE_VISUALS` (an empty dict) from `workstation.gd`
  and simplified `refresh_visual()` accordingly (the dict-lookup branch was
  always false). Updated the stale comments that referenced it.
- Left `DayNightCycle.phase_progress()` in place (small, self-contained, and
  the Day/Night HUD tooltip added in the tooltip-delay fix is a natural future
  consumer) rather than deleting it.

**Explicitly deferred - not done this session:**
- **The `combat_unit.gd` per-frame O(n²) cluster** - `_live_enemies()`
  (`combat_unit.gd:1817`) re-filters a fresh Array on every call across 9 call
  sites, and `BattlefieldTerrain.blocks_line_of_sight()` is a flat double loop
  with no bounding-box/distance early-out, run per ranged unit per frame
  against ~145-150 obstacle polygons (~12,000 `segment_intersects_segment`
  calls/frame at 12 ranged units). This is the biggest remaining CPU win in the
  project. Deferred because `combat_unit.gd` carries 190 uncommitted lines this
  session started with (now committed as of the Step 0 checkpoint) - deserves
  its own reviewed session rather than entangling with unrelated work.
- **`iso_ground.gd`'s one-`Sprite2D`-plus-one-`AtlasTexture`-per-tile
  construction** (3,136 of each at the current 56x56 map). A `TileMapLayer`/
  `MultiMeshInstance2D` rewrite would collapse that to one of each, but tiles
  share a base texture and Godot culls offscreen canvas items - this is
  **identified, not measured**, don't assume it's an actual bottleneck without
  profiling first.
- Two cheap-but-unimportant per-frame wastes, noted but not fixed:
  `rts_camera.gd`'s zoom-distance audio update runs every `_process` frame
  even when zoom hasn't changed (belongs in the zoom handler instead), and
  `formation.gd` allocates two filtered Arrays per frame per formation.
