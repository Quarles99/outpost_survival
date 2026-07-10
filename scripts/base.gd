extends Node2D
class_name Base

const VALID_TINT := Color(0.5, 1.0, 0.5, 0.6)
const INVALID_TINT := Color(1.0, 0.4, 0.4, 0.6)

## Catalog fields that map directly onto exported properties of the
## building scenes they configure (e.g. distinguishing a Farm from a
## Lumber Camp, which share the generic Workstation scene). Applied via
## `option.has(key)` so it's safe to list properties only some Workstation
## subclasses have (e.g. input_resource/input_per_tick/skill_id are Farm-
## only) - a catalog entry for a class without them just never sets them.
const BUILDING_PROPERTIES := [
	"display_name", "resource_type", "output_per_tick", "work_interval",
	"sprite_tint", "input_resource", "input_per_tick", "skill_id",
]

const INITIAL_TREE_COUNT := 12
const INITIAL_TREE_RADIUS := 5.0

## Minimum cursor travel (px) before a character press becomes a drag rather
## than a click.
const DRAG_THRESHOLD := 12.0

@onready var task_panel: TaskPanel = $TaskPanel
@onready var build_menu: BuildMenu = $BuildMenu
@onready var hud: HUD = $HUD
@onready var iso_ground: IsoGround = $IsoGround
@onready var camera: RtsCamera = $Camera2D
@onready var characters: Array[Character] = [$Aldric, $Brenna, $Cass]

var posts: Array[Node] = []

## Buildings placed at runtime via the build menu (not the fixed scene-file
## ones), tracked so a save can rebuild them and a load can wipe/replace
## them. Entries: {save_id: String, option_id: String, origin: Vector2i, node: Node}.
var _placed_buildings: Array[Dictionary] = []
var _next_placed_id := 0

var _selected_character: Character = null

var _placing_option: Dictionary = {}
var _ghost: Node2D = null
var _ghost_origin := Vector2i.ZERO
var _ghost_valid := false

var _drag_character: Character = null
var _drag_start_mouse := Vector2.ZERO
var _drag_moved := false


func _ready() -> void:
	get_viewport().physics_object_picking = true

	var min_cell := Vector2i(iso_ground.start_x, iso_ground.start_y)
	var max_cell := Vector2i(iso_ground.start_x + iso_ground.width - 1, iso_ground.start_y + iso_ground.depth - 1)
	WorldGrid.configure(iso_ground.position, min_cell, max_cell, self)
	WorldGrid.stockpile_spot = $OutpostHall.get_stockpile_spot()
	_configure_camera_limits(min_cell, max_cell)

	posts.append($Farm)
	posts.append($Woodpile)
	$Farm.set_meta("save_id", "farm")
	$Woodpile.set_meta("save_id", "woodpile")

	_reserve_existing_footprint($OutpostHall, BuildingCatalog.get_option("outpost_hall")["grid_size"])
	_reserve_existing_footprint($Farm, BuildingCatalog.get_option("farm")["grid_size"])
	_reserve_existing_footprint($Woodpile, BuildingCatalog.get_option("woodpile")["grid_size"])

	_scatter_initial_trees()

	for character in characters:
		character.drag_started.connect(_on_character_drag_started)

	task_panel.task_selected.connect(_on_task_selected)
	task_panel.idle_selected.connect(_on_idle_selected)

	build_menu.option_selected.connect(_on_build_option_selected)
	hud.build_pressed.connect(_on_build_pressed)


func _configure_camera_limits(min_cell: Vector2i, max_cell: Vector2i) -> void:
	var corners := [
		WorldGrid.grid_to_local(Vector2(min_cell.x, min_cell.y)),
		WorldGrid.grid_to_local(Vector2(max_cell.x, min_cell.y)),
		WorldGrid.grid_to_local(Vector2(min_cell.x, max_cell.y)),
		WorldGrid.grid_to_local(Vector2(max_cell.x, max_cell.y)),
	]
	var min_pos: Vector2 = corners[0]
	var max_pos: Vector2 = corners[0]
	for corner in corners:
		min_pos = min_pos.min(corner)
		max_pos = max_pos.max(corner)
	camera.configure_limits(min_pos, max_pos)


func _scatter_initial_trees() -> void:
	var woodpile_cell := WorldGrid.local_to_grid($Woodpile.position)
	for i in INITIAL_TREE_COUNT:
		var cell = WorldGrid.find_plantable_cell(woodpile_cell, INITIAL_TREE_RADIUS)
		if cell == null:
			break
		WorldGrid.plant_tree(cell, true)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F5:
			get_viewport().set_input_as_handled()
			_save_game()
			return
		elif event.keycode == KEY_F9:
			get_viewport().set_input_as_handled()
			_load_game()
			return
	if _drag_character:
		_handle_drag_input(event)
		return
	if _placing_option:
		_handle_placement_input(event)
		return
	if build_menu.visible and ((event is InputEventMouseButton and event.pressed) or event.is_action_pressed("ui_cancel")):
		build_menu.close()
		return
	if _selected_character == null:
		return
	if (event is InputEventMouseButton and event.pressed) or event.is_action_pressed("ui_cancel"):
		_deselect()


func _on_character_drag_started(character: Character) -> void:
	if _placing_option or _drag_character:
		return
	_drag_character = character
	_drag_start_mouse = get_global_mouse_position()
	_drag_moved = false


func _handle_drag_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mouse_pos := get_global_mouse_position()
		if not _drag_moved and mouse_pos.distance_to(_drag_start_mouse) >= DRAG_THRESHOLD:
			_drag_moved = true
			if _selected_character:
				_deselect()
			_drag_character.start_drag()
		if _drag_moved:
			_drag_character.update_drag(mouse_pos)
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		_end_character_drag()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		get_viewport().set_input_as_handled()
		_cancel_character_drag()
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_cancel_character_drag()


func _end_character_drag() -> void:
	var character := _drag_character
	var moved := _drag_moved
	_drag_character = null
	_drag_moved = false

	if not moved:
		_on_character_selected(character)
		return

	var post := _post_at(get_global_mouse_position())
	if post and not (post is WallSegment and post.active_workers >= 1):
		character.end_drag()
		character.assign_to(post)
	else:
		character.cancel_drag()


func _cancel_character_drag() -> void:
	var character := _drag_character
	var moved := _drag_moved
	_drag_character = null
	_drag_moved = false
	if moved:
		character.cancel_drag()


func _post_at(global_pos: Vector2) -> Node:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = global_pos
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for result in get_world_2d().direct_space_state.intersect_point(query, 8):
		if result["collider"] in posts:
			return result["collider"]
	return null


func _on_character_selected(character: Character) -> void:
	if _placing_option:
		return
	if _selected_character and _selected_character != character:
		_selected_character.set_selected(false)
	_selected_character = character
	_selected_character.set_selected(true)

	var assignable := posts.filter(func(post: Node) -> bool: return not (post is WallSegment and post.active_workers >= 1))
	task_panel.open_for(character, assignable)


func _on_task_selected(post: Node) -> void:
	if _selected_character:
		_selected_character.assign_to(post)
	_deselect()


func _on_idle_selected() -> void:
	if _selected_character:
		_selected_character.assign_to(null)
	_deselect()


func _deselect() -> void:
	if _selected_character:
		_selected_character.set_selected(false)
	_selected_character = null
	task_panel.close()


func _on_build_pressed() -> void:
	_cancel_placement()
	if _selected_character:
		_deselect()
	build_menu.open_for(BuildingCatalog.placeable_options())


func _on_build_option_selected(option: Dictionary) -> void:
	_cancel_placement()
	_placing_option = option
	_ghost = option["scene"].instantiate()
	_apply_option_properties(_ghost, option)
	if _ghost.has_node("Label"):
		_ghost.get_node("Label").visible = false
	add_child(_ghost)
	_update_ghost(to_local(get_global_mouse_position()))


func _handle_placement_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_ghost(to_local(get_global_mouse_position()))
	elif event is InputEventMouseButton and event.pressed:
		get_viewport().set_input_as_handled()
		if event.button_index == MOUSE_BUTTON_LEFT:
			_confirm_placement()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_placement()
	elif event.is_action_pressed("ui_cancel"):
		_cancel_placement()


func _update_ghost(local_pos: Vector2) -> void:
	var size: Vector2i = _placing_option["grid_size"]
	var grid := WorldGrid.local_to_grid(local_pos)
	_ghost_origin = _footprint_origin(grid, size)
	_ghost.position = WorldGrid.grid_to_local(_footprint_anchor(_ghost_origin, size))
	_ghost_valid = (
		_footprint_in_bounds(_ghost_origin, size)
		and _footprint_free(_ghost_origin, size)
		and GameState.can_afford(_placing_option["cost"])
	)
	_ghost.modulate = VALID_TINT if _ghost_valid else INVALID_TINT


func _confirm_placement() -> void:
	if not _ghost_valid:
		return
	var option := _placing_option
	var size: Vector2i = option["grid_size"]
	var origin := _ghost_origin

	GameState.spend(option["cost"])
	_reserve_cells(origin, size)

	var building: Node2D = option["scene"].instantiate()
	_apply_option_properties(building, option)
	building.position = WorldGrid.grid_to_local(_footprint_anchor(origin, size))
	var save_id := "placed_%d" % _next_placed_id
	_next_placed_id += 1
	building.set_meta("save_id", save_id)
	add_child(building)

	if option.has("population_capacity"):
		GameState.add_population_capacity(option["population_capacity"])
	if option.has("water_wells"):
		GameState.add_water_well(option["water_wells"])
	if option.has("storage_capacity"):
		GameState.add_storage_capacity(option["storage_capacity"])
	if building.has_method("add_worker"):
		posts.append(building)

	_placed_buildings.append({"save_id": save_id, "option_id": option["id"], "origin": origin, "node": building})

	_cancel_placement()


func _cancel_placement() -> void:
	if _ghost:
		_ghost.queue_free()
		_ghost = null
	_placing_option = {}


func _apply_option_properties(node: Node, option: Dictionary) -> void:
	for key in BUILDING_PROPERTIES:
		if option.has(key):
			node.set(key, option[key])


## The min (back-most) cell of a size-shaped footprint whose front (nearest-
## camera) cell sits under the given grid point.
func _footprint_origin(grid: Vector2, size: Vector2i) -> Vector2i:
	return Vector2i(roundi(grid.x), roundi(grid.y)) - size + Vector2i.ONE


## Inverse of _footprint_origin: the building's anchor is its front-most
## cell's own center — the same point a 1x1 tile/building anchors to — so
## multi-tile buildings snap the same way single-tile ones do, rather than
## centering on the grid-line intersection shared by the footprint's cells.
func _footprint_anchor(origin: Vector2i, size: Vector2i) -> Vector2:
	var front := origin + size - Vector2i.ONE
	return Vector2(front.x, front.y)


func _footprint_cells(origin: Vector2i, size: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in size.x:
		for y in size.y:
			cells.append(Vector2i(origin.x + x, origin.y + y))
	return cells


func _reserve_cells(origin: Vector2i, size: Vector2i) -> void:
	for cell in _footprint_cells(origin, size):
		WorldGrid.reserve(cell)


func _release_cells(origin: Vector2i, size: Vector2i) -> void:
	for cell in _footprint_cells(origin, size):
		WorldGrid.release(cell)


func _reserve_existing_footprint(node: Node2D, size: Vector2i) -> void:
	var grid := WorldGrid.local_to_grid(node.position)
	_reserve_cells(_footprint_origin(grid, size), size)


func _footprint_in_bounds(origin: Vector2i, size: Vector2i) -> bool:
	for cell in _footprint_cells(origin, size):
		if not WorldGrid.is_in_bounds(cell):
			return false
	return true


func _footprint_free(origin: Vector2i, size: Vector2i) -> bool:
	for cell in _footprint_cells(origin, size):
		if not WorldGrid.is_free(cell):
			return false
	return true


## --- Save / load (F5 quicksave, F9 quickload) ------------------------------

func _save_game() -> void:
	var data := {
		"version": 1,
		"resources": GameState.resources.duplicate(),
		"population_count": GameState.population_count,
		"population_capacity": GameState.population_capacity,
		"water_wells": GameState.water_wells,
		"storage_capacity": GameState.storage_capacity,
		"trees": _serialize_trees(),
		"placed_buildings": _serialize_placed_buildings(),
		"post_buffers": _serialize_post_buffers(),
		"characters": _serialize_characters(),
	}
	SaveManager.save_game(data)
	hud.flash_message("Saved")


func _load_game() -> void:
	var data := SaveManager.load_game()
	if data.is_empty():
		hud.flash_message("No save found")
		return

	_cancel_placement()
	if _drag_character:
		_cancel_character_drag()
	_deselect()
	build_menu.close()

	## Merged onto the current resource schema (not a wholesale replace): a
	## save made before a new resource type existed (e.g. an old save
	## predating "stone") would otherwise just omit that key, leaving
	## GameState.resources - and the HUD label reading it - stuck on
	## whatever was in play before the load instead of resetting to 0.
	var saved_resources: Dictionary = data.get("resources", {})
	for resource_name in GameState.resources.keys():
		GameState.resources[resource_name] = saved_resources.get(resource_name, 0.0)
	for resource_name in saved_resources:
		if not GameState.resources.has(resource_name):
			GameState.resources[resource_name] = saved_resources[resource_name]
	for resource_name in GameState.resources:
		GameState.resources_changed.emit(resource_name, GameState.resources[resource_name])
	GameState.population_count = int(data.get("population_count", GameState.population_count))
	GameState.population_capacity = int(data.get("population_capacity", GameState.population_capacity))
	GameState.population_changed.emit(GameState.population_count, GameState.population_capacity)
	GameState.water_wells = int(data.get("water_wells", GameState.water_wells))
	GameState.water_changed.emit(GameState.has_water())
	GameState.storage_capacity = float(data.get("storage_capacity", GameState.storage_capacity))
	GameState.storage_capacity_changed.emit(GameState.storage_capacity)

	## Buildings are restored before trees: WorldGrid.plant_tree() doesn't
	## check cell occupancy, and a stale placed building torn down after
	## trees are replanted could release a cell a just-restored tree also
	## claimed, leaving WorldGrid.is_free() wrong about that cell forever.
	_restore_placed_buildings(data.get("placed_buildings", []))
	_restore_trees(data.get("trees", []))
	_restore_post_buffers(data.get("post_buffers", {}))
	_restore_characters(data.get("characters", []))

	hud.flash_message("Loaded")


func _serialize_trees() -> Array:
	var out := []
	for tree in WorldGrid.get_trees():
		out.append({
			"cell": [tree.grid_cell.x, tree.grid_cell.y],
			"is_mature": tree.is_mature,
			"wood_remaining": tree.wood_remaining,
		})
	return out


## Saplings regrow from scratch rather than resuming mid-growth - the exact
## growth progress isn't tracked anywhere else and isn't worth persisting.
func _restore_trees(entries: Array) -> void:
	WorldGrid.clear_trees()
	for entry in entries:
		var cell_arr: Array = entry["cell"]
		var cell := Vector2i(int(cell_arr[0]), int(cell_arr[1]))
		var tree := WorldGrid.plant_tree(cell, entry.get("is_mature", true))
		tree.wood_remaining = entry.get("wood_remaining", tree.wood_remaining)


func _serialize_placed_buildings() -> Array:
	var out := []
	for entry in _placed_buildings:
		var origin: Vector2i = entry["origin"]
		out.append({"save_id": entry["save_id"], "option_id": entry["option_id"], "origin": [origin.x, origin.y]})
	return out


## Wipes every runtime-placed building (the fixed scene-file ones - Outpost
## Hall/Farm/Woodpile - are left alone) and rebuilds from saved entries.
## Doesn't re-grant population_capacity for entries that provide it - the
## saved population_capacity total already accounts for them.
func _restore_placed_buildings(entries: Array) -> void:
	for entry in _placed_buildings:
		var node: Node = entry["node"]
		if is_instance_valid(node):
			posts.erase(node)
			node.queue_free()
		var option := BuildingCatalog.get_option(entry["option_id"])
		if option.has("grid_size"):
			_release_cells(entry["origin"], option["grid_size"])
	_placed_buildings.clear()
	_next_placed_id = 0

	for entry in entries:
		var option := BuildingCatalog.get_option(entry["option_id"])
		if option.is_empty():
			continue
		var origin_arr: Array = entry["origin"]
		var origin := Vector2i(int(origin_arr[0]), int(origin_arr[1]))
		var size: Vector2i = option["grid_size"]
		_reserve_cells(origin, size)

		var building: Node2D = option["scene"].instantiate()
		_apply_option_properties(building, option)
		building.position = WorldGrid.grid_to_local(_footprint_anchor(origin, size))
		var save_id: String = entry["save_id"]
		building.set_meta("save_id", save_id)
		add_child(building)
		if building.has_method("add_worker"):
			posts.append(building)

		_placed_buildings.append({"save_id": save_id, "option_id": entry["option_id"], "origin": origin, "node": building})

		if save_id.begins_with("placed_"):
			_next_placed_id = maxi(_next_placed_id, int(save_id.trim_prefix("placed_")) + 1)


## In-transit haul buffers aren't tracked anywhere but the post nodes
## themselves, so without this a quickload silently deletes whatever
## resources were sitting in output_buffer/input_buffer at save time.
func _serialize_post_buffers() -> Dictionary:
	var out := {}
	for post in posts:
		if not (post is Workstation and post.has_meta("save_id")):
			continue
		var entry := {"output_buffer": post.output_buffer}
		if not post.get_input_resource().is_empty():
			entry["input_buffer"] = post.input_buffer
		out[post.get_meta("save_id")] = entry
	return out


func _restore_post_buffers(data: Dictionary) -> void:
	for post in posts:
		if not (post is Workstation and post.has_meta("save_id")):
			continue
		var entry: Dictionary = data.get(post.get_meta("save_id"), {})
		post.output_buffer = entry.get("output_buffer", 0.0)
		if not post.get_input_resource().is_empty():
			post.input_buffer = entry.get("input_buffer", 0.0)


func _serialize_characters() -> Array:
	var out := []
	for character in characters:
		var save_id := ""
		if character.assigned_post and character.assigned_post.has_meta("save_id"):
			save_id = character.assigned_post.get_meta("save_id")
		out.append({
			"name": character.data.character_name,
			"skill_xp": character.data.skill_xp.duplicate(),
			"assigned_save_id": save_id,
		})
	return out


## Matched by character_name against the fixed Aldric/Brenna/Cass nodes -
## there's no recruitment system yet that could add or remove a character.
func _restore_characters(entries: Array) -> void:
	var by_name := {}
	for character in characters:
		by_name[character.data.character_name] = character

	for entry in entries:
		var character: Character = by_name.get(entry.get("name", ""))
		if not character:
			continue
		character.data.skill_xp = (entry.get("skill_xp", {}) as Dictionary).duplicate()
		character.assign_to(_post_by_save_id(entry.get("assigned_save_id", "")))


func _post_by_save_id(save_id: String) -> Node:
	if save_id.is_empty():
		return null
	if save_id == "farm":
		return $Farm
	if save_id == "woodpile":
		return $Woodpile
	for entry in _placed_buildings:
		if entry["save_id"] == save_id:
			return entry["node"]
	return null
