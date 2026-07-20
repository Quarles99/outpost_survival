extends Node2D
class_name IsoGround

## Tiny Pixel Art tileset (art/Tiny Pixel Art/Isometric_MedievalFantasy_Tiles.png)
## - a proper 16x17px isometric "cube" tile grid, replacing the Fantasy Pack
## Floor tiles (see Outpost_Survival/Actionable Ideas/Implement New Art.md's
## completion write-up for why that attempt got reverted).
##
## Using the whole 16x17 cube (grass top + its dirt "wall" beneath) as the
## ground tile - the first attempt - was wrong: every tile's dirt wall is
## always visible along its own edge, so tiling it produces a permanent
## lattice of dirt seams between every tile ("grass mesas in a dirt trench",
## not a flat field) instead of grass connecting to grass. The fix is to
## drop the wall entirely and use only the tile's flat top face - rows 0-7
## of the cube, a clean 16x8 (exactly 2:1) diamond on its own, confirmed via
## alpha bbox - scaled uniformly (no wall depth left to force-fit
## non-uniformly like the Fantasy Pack tiles needed). GRASS is the
## grass-topped face (sheet column 1, x=16-32); WORN is the plain dirt face
## right next to it (column 0, x=0-16), same crop.
##
## A single 16x8 diamond scaled up to fill a whole 128x64 world cell needs
## 8x scale - roughly double every building's ~4x (Pixel Isometric 16x16
## pack) and Tree/RockDecoration's ~3.5x, since neither art pack actually
## has a bigger native ground crop to use instead (confirmed via an
## alpha-bbox scan - both are on a strict 16x16 px grid). So the ground read
## as noticeably chunkier than everything standing on it. Fixed the same way
## the Farm plot below is: pre-baked composite PNGs
## (res://art/Tiny Pixel Art/ground_tile_composite.png) that repeat the same
## 16x8 crop 2x2 within a single texture, so the *scale* needed to fill one
## 128x64 cell drops to 4x (matching buildings) while the on-screen result
## (one seamless cell) is unchanged.
const GRASS_TEXTURE := preload("res://art/Tiny Pixel Art/ground_tile_composite.png")
const TILE_SCALE := Vector2(4, 4)
const TILE_OFFSET := Vector2(-16, -8)
const GRASS_REGION := Rect2(0, 0, 32, 16)
const WORN_REGION := Rect2(32, 0, 32, 16)

@export var width: int = 9
@export var depth: int = 9
@export var start_x: int = 0
@export var start_y: int = 0

## Fixed seed so the dirt/grass pattern is stable across every load of the
## same map rather than reshuffling on each scene instantiation - the
## ground is fully regenerated fresh every time (not part of save data), so
## an unseeded/time-based noise would visibly shift the terrain under
## already-placed buildings between sessions, which reads as a bug even
## though it's purely cosmetic.
const NOISE_SEED := 20260718

## Ambient dirt patches: low-frequency noise so each patch spans several
## tiles as one irregular blob (replacing the old per-tile hash scatter,
## which only ever produced isolated single-tile speckle - not what worn
## dirt actually looks like next to grass). Threshold keeps dirt a
## minority of the map; tuned by eye via an in-engine screenshot, not
## derived from the noise's exact distribution shape.
const PATCH_FREQUENCY := 0.075
const PATCH_THRESHOLD := 0.74

## A handful of distinct, clearly-readable dirt clearings - kept separate
## from the ambient patch noise above so the map always has a few open
## dirt areas regardless of how the ambient noise happens to fall, rather
## than hoping it coalesces into one on its own.
const CLEARING_COUNT := 4
const CLEARING_MIN_RADIUS := 1.5
const CLEARING_MAX_RADIUS := 3.0
## Per-angle radius jitter (as a fraction of the clearing's own radius),
## sampled from _edge_noise rather than the clearing's own random radius,
## so the boundary reads as an irregular worn edge instead of a perfect
## circle.
const CLEARING_EDGE_NOISE_FREQUENCY := 0.6
const CLEARING_EDGE_JITTER_FRACTION := 0.4

## Short winding dirt trails, built as a biased random walk (the direction
## drifts gradually rather than re-rolling fully each step) so they curve
## like a trodden path instead of a ruled straight line or a fully erratic
## scribble.
const PATH_COUNT := 3
const PATH_MIN_LENGTH := 10
const PATH_MAX_LENGTH := 18
const PATH_TURN_RANGE := 0.5
## Chance per step a path also widens onto one random orthogonal neighbor -
## keeps most of a path a single tile wide with the occasional wider tread,
## rather than a uniform two-tile-wide corridor.
const PATH_WIDEN_CHANCE := 0.25

var _patch_noise := FastNoiseLite.new()
var _edge_noise := FastNoiseLite.new()
## Cells forced to dirt by a clearing or path, regardless of what the
## ambient patch noise says at that cell - a Dictionary used as a Set
## (value is always true, only key membership matters).
var _forced_dirt: Dictionary = {}
## Vector2i -> the AtlasTexture backing that cell's tile (not the Sprite2D
## itself - the region is the only thing that ever needs mutating after
## _build(), for mark_canopy/clear_canopy below) - Expand map size 4x.md's
## "make the tile under the tree dirt to reflect canopy cover". Populated
## in _place_tile so a canopy toggle is an O(1) lookup rather than a full
## rebuild.
var _tile_atlases: Dictionary = {}
## Cells forced to dirt by a mature tree's canopy (see mark_canopy/
## clear_canopy) - kept as its own Set, separate from _worn_path_cells
## below, so the two dynamic "why is this dirt" reasons compose instead of
## clobbering each other: a path worn under a tree that's since grown a
## canopy shouldn't revert to grass just because foot traffic there
## happened to decay away, and vice versa. See _refresh_tile_region.
var _canopy_cells: Dictionary = {}
## Cells forced to dirt by WorldGrid's foot-traffic wear tracking (Dynamic
## path building system.md) - same Set-of-Vector2i shape as _canopy_cells,
## composed the same way in _refresh_tile_region.
var _worn_path_cells: Dictionary = {}


func _ready() -> void:
	## The top-face-only crop is an exact flat 2:1 diamond with no leftover
	## depth to overlap neighbors with, so this no longer strictly needs
	## y-sort the way the full-cube version did - kept anyway since it's
	## free and safe (matches every other y-sorted layer's convention).
	y_sort_enabled = true
	_build()


func _build() -> void:
	for child in get_children():
		child.queue_free()
	_tile_atlases.clear()
	_canopy_cells.clear()
	_worn_path_cells.clear()

	_patch_noise.seed = NOISE_SEED
	_patch_noise.frequency = PATCH_FREQUENCY
	_edge_noise.seed = NOISE_SEED + 1
	_edge_noise.frequency = CLEARING_EDGE_NOISE_FREQUENCY

	var rng := RandomNumberGenerator.new()
	rng.seed = NOISE_SEED
	_forced_dirt.clear()
	_carve_clearings(rng)
	_carve_paths(rng)

	for i in width:
		var gx := start_x + i
		for j in depth:
			var gy := start_y + j
			_place_tile(gx, gy)


func _place_tile(gx: int, gy: int) -> void:
	var tile := Sprite2D.new()
	tile.centered = false
	tile.offset = TILE_OFFSET
	tile.scale = TILE_SCALE
	tile.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var atlas := AtlasTexture.new()
	atlas.atlas = GRASS_TEXTURE
	atlas.region = WORN_REGION if _is_dirt(gx, gy) else GRASS_REGION
	tile.texture = atlas
	## No rotation (breaks the fixed upper-left lighting every asset here is
	## painted with) - a horizontal flip is the cheap, safe way to break up
	## the repeat instead. Independent of the dirt/grass decision above -
	## still keyed off the same coordinate hash as before, just no longer
	## also driving which region is picked.
	var spatial_hash := absi(gx * 3 + gy * 7)
	tile.flip_h = spatial_hash % 2 == 0
	tile.position = IsoUtils.grid_to_screen(Vector2(gx, gy))
	add_child(tile)
	_tile_atlases[Vector2i(gx, gy)] = atlas


## Forces a single cell to the dirt/worn region regardless of the ambient
## noise/clearings/paths - called by WorldGrid when a tree at this cell
## matures (see WorldGrid.plant_tree/_on_tree_matured), so a canopy visibly
## kills the grass beneath it. A no-op for a cell outside the built grid
## (_tile_atlases has no entry) - defensive only, every caller today only
## ever passes a WorldTree's own grid_cell, which WorldGrid already
## constrains to bounds_min/bounds_max.
func mark_canopy(cell: Vector2i) -> void:
	_canopy_cells[cell] = true
	_refresh_tile_region(cell)


## Reverts a cell to whatever it would naturally be (still dirt if it's
## also inside a clearing/path/ambient patch, a worn foot-traffic path, or
## another tree's canopy - see _refresh_tile_region - grass otherwise) -
## called once the tree that was marking it canopy is harvested away (see
## WorldGrid._on_tree_depleted).
func clear_canopy(cell: Vector2i) -> void:
	_canopy_cells.erase(cell)
	_refresh_tile_region(cell)


## Forces a single cell to the dirt/worn region because foot traffic has
## worn it into a path (WorldGrid's wear tracking, see Dynamic path
## building system.md) - same shape as mark_canopy, kept as an entirely
## separate Set (_worn_path_cells) so the two dynamic "why is this dirt"
## reasons compose instead of one clobbering the other (see
## _canopy_cells's own doc comment).
func mark_worn_path(cell: Vector2i) -> void:
	_worn_path_cells[cell] = true
	_refresh_tile_region(cell)


## Reverts a cell once its foot-traffic wear has fully decayed away (see
## WorldGrid._process) - same "re-derive rather than hardcode" reasoning as
## clear_canopy.
func clear_worn_path(cell: Vector2i) -> void:
	_worn_path_cells.erase(cell)
	_refresh_tile_region(cell)


## True if `cell` currently reads as a worn dirt path from foot traffic
## specifically (not ambient noise/clearings/canopy) - Character reads this
## to apply the path speed bonus (see Dynamic path building system.md's
## "small boost to movement speed").
func is_worn_path(cell: Vector2i) -> bool:
	return _worn_path_cells.has(cell)


## The single source of truth for what a cell's tile should actually look
## like, given every reason (static noise/clearing/path baked at build
## time, a tree's canopy, foot-traffic wear) it might currently be dirt -
## called after any one of those changes for just the one affected cell,
## rather than a full _build() rebuild.
func _refresh_tile_region(cell: Vector2i) -> void:
	var atlas: AtlasTexture = _tile_atlases.get(cell)
	if not atlas:
		return
	var dirt := _is_dirt(cell.x, cell.y) or _canopy_cells.has(cell) or _worn_path_cells.has(cell)
	atlas.region = WORN_REGION if dirt else GRASS_REGION


func _is_dirt(gx: int, gy: int) -> bool:
	if _forced_dirt.has(Vector2i(gx, gy)):
		return true
	var n := (_patch_noise.get_noise_2d(gx, gy) + 1.0) * 0.5
	return n > PATCH_THRESHOLD


func _carve_clearings(rng: RandomNumberGenerator) -> void:
	for i in CLEARING_COUNT:
		var cx := rng.randi_range(start_x, start_x + width - 1)
		var cy := rng.randi_range(start_y, start_y + depth - 1)
		var radius := rng.randf_range(CLEARING_MIN_RADIUS, CLEARING_MAX_RADIUS)
		var jitter := radius * CLEARING_EDGE_JITTER_FRACTION
		var scan := ceili(radius + jitter) + 1
		for dx in range(-scan, scan + 1):
			for dy in range(-scan, scan + 1):
				var gx := cx + dx
				var gy := cy + dy
				var dist := Vector2(dx, dy).length()
				var edge_jitter := _edge_noise.get_noise_2d(gx, gy) * jitter
				if dist <= radius + edge_jitter:
					_forced_dirt[Vector2i(gx, gy)] = true


func _carve_paths(rng: RandomNumberGenerator) -> void:
	for i in PATH_COUNT:
		var gx := rng.randi_range(start_x, start_x + width - 1)
		var gy := rng.randi_range(start_y, start_y + depth - 1)
		var length := rng.randi_range(PATH_MIN_LENGTH, PATH_MAX_LENGTH)
		var dir := Vector2.from_angle(rng.randf_range(0.0, TAU))
		for step in length:
			_forced_dirt[Vector2i(gx, gy)] = true
			if rng.randf() < PATH_WIDEN_CHANCE:
				var neighbors := [Vector2i(gx + 1, gy), Vector2i(gx - 1, gy), Vector2i(gx, gy + 1), Vector2i(gx, gy - 1)]
				_forced_dirt[neighbors[rng.randi_range(0, neighbors.size() - 1)]] = true
			dir = dir.rotated(rng.randf_range(-PATH_TURN_RANGE, PATH_TURN_RANGE)).normalized()
			gx += roundi(dir.x)
			gy += roundi(dir.y)
			if gx < start_x or gx >= start_x + width or gy < start_y or gy >= start_y + depth:
				break
