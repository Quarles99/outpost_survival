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


func configure(ground_pos: Vector2, min_cell: Vector2i, max_cell: Vector2i, trees_node: Node, ground: IsoGround = null) -> void:
	ground_origin = ground_pos
	bounds_min = min_cell
	bounds_max = max_cell
	trees_container = trees_node
	iso_ground = ground
	_occupied.clear()
	_trees.clear()
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


## Total trees (mature or still growing) within radius_tiles of from_cell -
## the whole local population a lumberjack should be sustaining, not just
## the ones a given worker personally planted.
func count_trees_near(from_cell: Vector2, radius_tiles: float) -> int:
	var count := 0
	for tree in _trees:
		if is_instance_valid(tree) and Vector2(tree.grid_cell).distance_to(from_cell) <= radius_tiles:
			count += 1
	return count


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
