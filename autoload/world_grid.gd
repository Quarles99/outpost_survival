extends Node

## Shared grid-cell occupancy and tree registry. Buildings (via Base) and
## trees (via lumberjack replanting) both reserve cells here, so neither can
## ever be placed on top of the other.

## Fired whenever a cell's occupancy changes (reserve or release) -
## Base listens once (see Base._rebake_navigation) and re-bakes the town's
## navmesh on every fire, so a citizen's pathing always reflects the current
## building/tree layout rather than whatever it was at boot. Unlike the
## battle sandbox's terrain (baked once per fight, see
## CombatTestManager._setup_navigation), the town's walkable area keeps
## changing for the whole session.
signal occupancy_changed

const TREE_SCENE := preload("res://scenes/nature/Tree.tscn")
const ROCK_SCENE := preload("res://scenes/nature/Rock.tscn")

var ground_origin := Vector2.ZERO
var bounds_min := Vector2i.ZERO
var bounds_max := Vector2i.ZERO
var trees_container: Node = null
## Set by configure() - lets plant_tree/_on_tree_matured/_on_tree_depleted
## mark/clear the dirt "canopy" tile under a tree directly (Expand map size
## 4x.md's "make the tile under the tree dirt to reflect canopy cover"),
## without threading a new signal through Base for every plant/harvest.
var iso_ground: IsoGround = null
## Every position workers can walk to drop off/pick up hauled resources -
## the Outpost Hall (registered once by Base._ready()) plus every placed
## Storage Facility (registered/unregistered as they're built or a save is
## loaded). Haulers use whichever is nearest (see nearest_stockpile) rather
## than always the Outpost Hall, so a Storage Facility built near a
## workstation actually shortens that workstation's haul trips instead of
## only ever raising the storage cap.
var stockpile_spots: Array[Vector2] = []

var _occupied: Dictionary = {}
var _trees: Array[WorldTree] = []
var _rocks: Array[WorldRock] = []

## Dynamic path building system.md - "the more frequently villagers walk
## over the same tile the more progress it gets to becoming a dirt path
## tile ... if left untraveled for awhile they will revert back to grass."
## Vector2i -> current wear (0..WEAR_MAX) - only cells with any wear at all
## are ever present as keys (removed once decayed back to 0, see _process),
## so this stays bounded to "recently walked" cells rather than growing to
## cover the whole map. Not part of save data, same as every other IsoGround
## cosmetic state (ambient noise, canopy) - see IsoGround's own doc comment
## on why the ground is fully regenerated fresh every session rather than
## persisted.
var _path_wear: Dictionary = {}
## Reworked from the original 0.5 (reached WEAR_PATH_THRESHOLD after a
## single 2-second crossing) per an explicit report: paths were forming and
## fading far faster than "the more frequently villagers walk over the same
## tile the more progress it gets to becoming a dirt path" was meant to
## read as - the source design note calls for a route developing over real
## in-game time, not two seconds. A citizen only registers foot traffic
## while physically standing on a given cell mid-walk (~1-2s per crossing
## at Character.MOVE_SPEED, see register_foot_traffic), so reaching
## threshold now takes on the order of a few in-game days of a route being
## walked repeatedly (DayNightCycle's full day+night cycle is 720s) rather
## than a single pass. First-pass rescale, not verified against a live
## playtest session - may need further tuning once actually watched over a
## multi-day game.
const WEAR_PER_SECOND := 0.005
## Kept at the same 10x-slower-than-gain ratio as before rescaling (0.5:0.05
## -> 0.005:0.0005) - a route crossed constantly still stays worn while an
## abandoned one fades, just over several in-game days now instead of well
## under a minute, matching "if left untraveled for awhile" at the same
## timescale WEAR_PER_SECOND was rescaled to.
const WEAR_DECAY_PER_SECOND := 0.0005
## Wear level at which a cell visually becomes a worn path (see
## IsoGround.mark_worn_path) and starts granting PATH_SPEED_MULTIPLIER.
const WEAR_PATH_THRESHOLD := 1.0
## Clamp - without this a super-highway tile crossed nonstop for a long
## session would take proportionally longer to decay back down too, which
## reads as "stuck" rather than "reverts if left untraveled."
const WEAR_MAX := 2.0
## "A small boost" (Dynamic path building system.md) - first-pass, not
## tuned via playtesting.
const PATH_SPEED_MULTIPLIER := 1.15


func configure(ground_pos: Vector2, min_cell: Vector2i, max_cell: Vector2i, trees_node: Node, ground: IsoGround = null) -> void:
	ground_origin = ground_pos
	bounds_min = min_cell
	bounds_max = max_cell
	trees_container = trees_node
	iso_ground = ground
	_occupied.clear()
	_trees.clear()
	_rocks.clear()
	_path_wear.clear()
	## WorldGrid is an autoload, unlike Base itself - a fresh Base.tscn
	## instantiation (New Game, or MainMenu -> Continue) calls configure()
	## exactly once in _ready(), so this is where stale stockpile spots
	## from a *previous* playthrough in the same process run get cleared,
	## same reasoning as GameState.reset_to_defaults().
	stockpile_spots.clear()


func register_stockpile(pos: Vector2) -> void:
	stockpile_spots.append(pos)


func unregister_stockpile(pos: Vector2) -> void:
	stockpile_spots.erase(pos)


## Whichever registered stockpile is closest to `from` - always the Outpost
## Hall if it's the only one, or if no Storage Facility happens to be
## closer. Vector2.ZERO if none are registered yet (shouldn't happen once
## Base._ready() has run, since the Outpost Hall always registers one).
func nearest_stockpile(from: Vector2) -> Vector2:
	var best := Vector2.ZERO
	var best_dist := INF
	for spot in stockpile_spots:
		var dist := from.distance_to(spot)
		if dist < best_dist:
			best = spot
			best_dist = dist
	return best


## Called every frame (Character._move_to's loop, while actually walking)
## with the citizen's current world position - bumps that cell's wear, and
## once it crosses WEAR_PATH_THRESHOLD, tells IsoGround to render it as a
## worn dirt path. No-op for a cell outside the built grid (no iso_ground
## configured yet, or genuinely out of bounds) - defensive only.
func register_foot_traffic(world_pos: Vector2) -> void:
	if not iso_ground:
		return
	var grid := local_to_grid(world_pos)
	var cell := Vector2i(round(grid.x), round(grid.y))
	var wear: float = minf(_path_wear.get(cell, 0.0) + WEAR_PER_SECOND * get_process_delta_time(), WEAR_MAX)
	_path_wear[cell] = wear
	if wear >= WEAR_PATH_THRESHOLD:
		iso_ground.mark_worn_path(cell)


## True if the cell at `world_pos` currently reads as a worn path -
## Character reads this each frame while moving to apply
## PATH_SPEED_MULTIPLIER.
func get_speed_multiplier(world_pos: Vector2) -> float:
	if not iso_ground:
		return 1.0
	var grid := local_to_grid(world_pos)
	var cell := Vector2i(round(grid.x), round(grid.y))
	return PATH_SPEED_MULTIPLIER if iso_ground.is_worn_path(cell) else 1.0


## Decays every tracked cell's wear continuously (not just the ones
## actively being walked on this frame, unlike register_foot_traffic) -
## this is what makes a path actually "revert back to grass" once foot
## traffic stops, rather than staying worn forever once it first crosses
## the threshold. Cells fully decayed back to 0 are dropped from
## _path_wear entirely, so this dict only ever holds recently-active cells.
func _process(delta: float) -> void:
	if _path_wear.is_empty():
		return
	var to_clear: Array[Vector2i] = []
	for cell in _path_wear:
		var wear: float = maxf(_path_wear[cell] - WEAR_DECAY_PER_SECOND * delta, 0.0)
		_path_wear[cell] = wear
		if wear <= 0.0:
			to_clear.append(cell)
		elif wear < WEAR_PATH_THRESHOLD and iso_ground and iso_ground.is_worn_path(cell):
			iso_ground.clear_worn_path(cell)
	for cell in to_clear:
		_path_wear.erase(cell)


func grid_to_local(grid: Vector2) -> Vector2:
	return ground_origin + IsoUtils.grid_to_screen(grid)


func local_to_grid(local_pos: Vector2) -> Vector2:
	return IsoUtils.screen_to_grid(local_pos - ground_origin)


func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= bounds_min.x and cell.y >= bounds_min.y and cell.x <= bounds_max.x and cell.y <= bounds_max.y


func is_free(cell: Vector2i) -> bool:
	return not _occupied.has(cell)


func reserve(cell: Vector2i) -> void:
	_occupied[cell] = true
	occupancy_changed.emit()


func release(cell: Vector2i) -> void:
	_occupied.erase(cell)
	occupancy_changed.emit()


## Every currently-occupied cell (buildings, construction sites, and trees
## all reserve through the same dict) - fed to Base._rebake_navigation as
## the navmesh's obstruction set, so pathing avoids all three uniformly
## without needing to enumerate each source separately.
func get_occupied_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell in _occupied:
		cells.append(cell)
	return cells


func plant_tree(cell: Vector2i, mature: bool) -> WorldTree:
	var tree: WorldTree = TREE_SCENE.instantiate()
	tree.grid_cell = cell
	tree.is_mature = mature
	tree.depleted.connect(_on_tree_depleted)
	tree.matured.connect(_on_tree_matured.bind(tree))
	reserve(cell)
	trees_container.add_child(tree)
	tree.position = grid_to_local(Vector2(cell.x, cell.y))
	_trees.append(tree)
	## A tree planted already-mature (the initial map scatter) never fires
	## its own matured signal - that only happens via the sapling-growth
	## tween _ready() starts for is_mature=false (see WorldTree._ready()) -
	## so this is the only place that case's canopy ever gets marked.
	if mature and iso_ground:
		iso_ground.mark_canopy(cell)
	return tree


## A replanted sapling (lumberjack replanting, or find_plantable_cell's own
## callers) only grows a real canopy once it actually matures - see
## plant_tree's own doc comment for the already-mature case.
func _on_tree_matured(tree: WorldTree) -> void:
	if iso_ground:
		iso_ground.mark_canopy(tree.grid_cell)


func _on_tree_depleted(tree: WorldTree) -> void:
	release(tree.grid_cell)
	_trees.erase(tree)
	if iso_ground:
		iso_ground.clear_canopy(tree.grid_cell)


func get_trees() -> Array[WorldTree]:
	return _trees.duplicate()


## Frees every tracked tree and releases its cell, bypassing the depleted
## signal (that path is for harvest-to-zero, not a full-registry wipe like a
## save load needs).
func clear_trees() -> void:
	for tree in _trees:
		if is_instance_valid(tree):
			release(tree.grid_cell)
			tree.queue_free()
	_trees.clear()


## Whichever tree (if any) sits at `cell` - linear scan, same style as
## find_available_tree. Used by Base's demolish-mode click handling (see
## Character._run_demolish_harvest) to resolve a clicked grid cell to a
## world object; doesn't exist for any other caller today.
func get_tree_at(cell: Vector2i) -> WorldTree:
	for tree in _trees:
		if is_instance_valid(tree) and tree.grid_cell == cell:
			return tree
	return null


## Instant free-removal path for demolishing an immature sapling (see Base's
## demolish-mode click handling) - deliberately bypasses harvest()/depleted
## entirely. A sapling's wood_remaining is 0 until it matures, and
## WorldTree.harvest() returns 0 without ever reaching its own depletion
## check for wood_remaining <= 0, so a sapling can never "harvest to zero"
## the normal way; it has no value to gather, so clearing it is free.
func remove_tree(tree: WorldTree) -> void:
	release(tree.grid_cell)
	_trees.erase(tree)
	tree.queue_free()


## Total trees (mature or still growing) within radius_tiles of from_cell -
## the whole local population a lumberjack should be sustaining, not just
## the ones a given worker personally planted.
func count_trees_near(from_cell: Vector2, radius_tiles: float) -> int:
	var count := 0
	for tree in _trees:
		if is_instance_valid(tree) and Vector2(tree.grid_cell).distance_to(from_cell) <= radius_tiles:
			count += 1
	return count


## Rock registry - WorldTree's sibling for stone (see WorldRock's own doc
## comment for why it's simpler: no growth/replant, so no matured signal or
## _on_rock_matured counterpart to plant_tree/_on_tree_matured).
func place_rock(cell: Vector2i) -> WorldRock:
	var rock: WorldRock = ROCK_SCENE.instantiate()
	rock.grid_cell = cell
	rock.depleted.connect(_on_rock_depleted)
	reserve(cell)
	trees_container.add_child(rock)
	rock.position = grid_to_local(Vector2(cell.x, cell.y))
	_rocks.append(rock)
	return rock


func _on_rock_depleted(rock: WorldRock) -> void:
	release(rock.grid_cell)
	_rocks.erase(rock)


func get_rocks() -> Array[WorldRock]:
	return _rocks.duplicate()


## Mirrors clear_trees - see its own doc comment.
func clear_rocks() -> void:
	for rock in _rocks:
		if is_instance_valid(rock):
			release(rock.grid_cell)
			rock.queue_free()
	_rocks.clear()


## Mirrors get_tree_at - see its own doc comment.
func get_rock_at(cell: Vector2i) -> WorldRock:
	for rock in _rocks:
		if is_instance_valid(rock) and rock.grid_cell == cell:
			return rock
	return null


## Nearest unclaimed mature tree within radius_tiles of from_cell, or null.
func find_available_tree(from_cell: Vector2, radius_tiles: float) -> WorldTree:
	var best: WorldTree = null
	var best_dist := INF
	for tree in _trees:
		if not is_instance_valid(tree) or not tree.is_mature or tree.claimed:
			continue
		var dist: float = Vector2(tree.grid_cell).distance_to(from_cell)
		if dist <= radius_tiles and dist < best_dist:
			best = tree
			best_dist = dist
	return best


## A random free, in-bounds cell within radius_tiles of from_cell, or null.
func find_plantable_cell(from_cell: Vector2, radius_tiles: float):
	var candidates: Array[Vector2i] = []
	var r := ceili(radius_tiles)
	var center := Vector2i(roundi(from_cell.x), roundi(from_cell.y))
	for dx in range(-r, r + 1):
		for dy in range(-r, r + 1):
			var cell := center + Vector2i(dx, dy)
			if Vector2(cell).distance_to(from_cell) > radius_tiles:
				continue
			if is_in_bounds(cell) and is_free(cell):
				candidates.append(cell)
	if candidates.is_empty():
		return null
	return candidates.pick_random()


## A free, in-bounds cell picked uniformly at random anywhere on the map -
## unlike find_plantable_cell, not limited to a radius around one center
## point. Used for scattering decoration (rocks, grass clumps) sparsely
## across the whole map rather than clustered near a single point. Retries
## a bounded number of times rather than enumerating every cell up front -
## the map is mostly free space when this runs, so a handful of retries is
## enough; giving up (returning null) just means one fewer decoration
## spawns, same as find_plantable_cell running out of candidates.
func find_random_cell_anywhere():
	for i in 40:
		var cell := Vector2i(randi_range(bounds_min.x, bounds_max.x), randi_range(bounds_min.y, bounds_max.y))
		if is_free(cell):
			return cell
	return null


## A free cell on one of the map's four boundary edges, picked uniformly at
## random - used to spawn an orc raiding party arriving "from the edge of
## the village" (see Base._on_night_started_raid) rather than appearing
## already inside the settlement. Same bounded-retry contract as
## find_random_cell_anywhere (a handful of retries is enough since the map
## edge is mostly free space; giving up just means that spawn attempt is
## skipped).
func find_random_edge_cell():
	for i in 40:
		var cell: Vector2i
		match randi_range(0, 3):
			0:
				cell = Vector2i(randi_range(bounds_min.x, bounds_max.x), bounds_min.y)
			1:
				cell = Vector2i(randi_range(bounds_min.x, bounds_max.x), bounds_max.y)
			2:
				cell = Vector2i(bounds_min.x, randi_range(bounds_min.y, bounds_max.y))
			_:
				cell = Vector2i(bounds_max.x, randi_range(bounds_min.y, bounds_max.y))
		if is_free(cell):
			return cell
	return null
