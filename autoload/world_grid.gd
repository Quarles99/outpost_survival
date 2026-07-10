extends Node

## Shared grid-cell occupancy and tree registry. Buildings (via Base) and
## trees (via lumberjack replanting) both reserve cells here, so neither can
## ever be placed on top of the other.

const TREE_SCENE := preload("res://scenes/nature/Tree.tscn")

var ground_origin := Vector2.ZERO
var bounds_min := Vector2i.ZERO
var bounds_max := Vector2i.ZERO
var trees_container: Node = null
## Where workers walk to drop off/pick up hauled resources (the Outpost
## Hall). Set once by Base._ready(); Vector2.ZERO until then.
var stockpile_spot := Vector2.ZERO

var _occupied: Dictionary = {}
var _trees: Array[WorldTree] = []


func configure(ground_pos: Vector2, min_cell: Vector2i, max_cell: Vector2i, trees_node: Node) -> void:
	ground_origin = ground_pos
	bounds_min = min_cell
	bounds_max = max_cell
	trees_container = trees_node
	_occupied.clear()
	_trees.clear()


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


func release(cell: Vector2i) -> void:
	_occupied.erase(cell)


func plant_tree(cell: Vector2i, mature: bool) -> WorldTree:
	var tree: WorldTree = TREE_SCENE.instantiate()
	tree.grid_cell = cell
	tree.is_mature = mature
	tree.depleted.connect(_on_tree_depleted)
	reserve(cell)
	trees_container.add_child(tree)
	tree.position = grid_to_local(Vector2(cell.x, cell.y))
	_trees.append(tree)
	return tree


func _on_tree_depleted(tree: WorldTree) -> void:
	release(tree.grid_cell)
	_trees.erase(tree)


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
