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

## --- Happiness ---------------------------------------------------------
## Every tick, each citizen's happiness eases toward a target recomputed
## from current settlement conditions (see _on_happiness_tick) rather than
## jumping straight to it - HAPPINESS_EASE_RATE caps how much it can move
## per tick, so a sudden change in conditions takes several ticks to be
## fully felt. Numbers below are a first pass, not iterated on via
## playtesting.
const HAPPINESS_TICK_INTERVAL := 5.0
const HAPPINESS_EASE_RATE := 3.0
const HAPPINESS_BASELINE := 50.0
const HAPPINESS_WATER_BONUS := 15.0
const HAPPINESS_FOOD_BONUS := 15.0
const HAPPINESS_STARVING_PENALTY := 20.0
const HAPPINESS_PER_FOOD_VARIETY := 5.0
## Below this, a citizen is "unhappy" and starts accumulating toward leaving.
const UNHAPPY_THRESHOLD := 20.0
## Consecutive ticks (at HAPPINESS_TICK_INTERVAL each) of sustained
## unhappiness before a citizen leaves for good - 12 * 5s = 60s.
const LEAVE_AFTER_UNHAPPY_TICKS := 12

## Settlement-wide production bonus/debuff bands, keyed by average
## happiness - the game's first happiness effect beyond "leave if sustained
## low" (see UNHAPPY_THRESHOLD/LEAVE_AFTER_UNHAPPY_TICKS above), applied as
## a flat multiplier on top of each worker's own skill multiplier (see
## GameState.happiness_output_multiplier and Character's work loops).
## Thresholds line up with the existing HAPPINESS_BASELINE (50, "Content" -
## the neutral 1.0x band) and UNHAPPY_THRESHOLD (20, where a citizen is
## already at risk of leaving, and now also least productive). First-pass
## numbers, not tuned via playtesting.
const HAPPINESS_BANDS := [
	{"min": 80.0, "name": "Thriving", "multiplier": 1.15},
	{"min": 50.0, "name": "Content", "multiplier": 1.0},
	{"min": 20.0, "name": "Unhappy", "multiplier": 0.85},
	{"min": 0.0, "name": "Miserable", "multiplier": 0.6},
]

## Minimum cursor travel (px) before a character press becomes a drag rather
## than a click.
const DRAG_THRESHOLD := 12.0

const CHARACTER_SCENE := preload("res://scenes/character/Character.tscn")

@onready var skill_panel: SkillPanel = $SkillPanel
@onready var build_menu: BuildMenu = $BuildMenu
@onready var recruit_panel: RecruitPanel = $RecruitPanel
@onready var crop_panel: CropPanel = $CropPanel
@onready var system_menu: SystemMenu = $SystemMenu
@onready var slot_panel: SlotPanel = $SlotPanel
@onready var hud: HUD = $HUD
@onready var iso_ground: IsoGround = $IsoGround
@onready var camera: RtsCamera = $Camera2D
@onready var characters: Array[Character] = [$Aldric, $Brenna, $Cass]

var posts: Array[Node] = []

## The Farm-family building currently open in crop_panel, set by
## _on_farm_clicked and consumed by _on_crop_selected. Only one crop panel
## can be open at a time (opening a new one closes any other panel first,
## same as recruit/build), so a single field is enough - no stack needed.
var _crop_target: Farm = null

## Which SystemMenu button opened slot_panel ("save" or "load") - slot_panel
## itself is purely presentational and just reports back which slot number
## was picked (see SlotPanel.slot_chosen), so this is where that gets
## turned into an actual save-to-slot or load-from-slot.
var _slot_panel_purpose := ""

## Buildings placed at runtime via the build menu (not the fixed scene-file
## ones), tracked so a save can rebuild them and a load can wipe/replace
## them. Entries: {save_id: String, option_id: String, origin: Vector2i, node: Node}.
## A retool via _on_crop_selected updates an entry's option_id in place, so
## save/load naturally picks up the new recipe through the same mechanism
## that already rebuilds placed buildings from their option_id.
var _placed_buildings: Array[Dictionary] = []
var _next_placed_id := 0

## The catalog option id the fixed scene-file $Farm currently matches -
## unlike player-placed buildings (tracked in _placed_buildings above),
## $Farm has no entry there to update on retool (see _restore_placed_buildings'
## doc comment: fixed buildings are left alone by save/load), so this is a
## separate, minimal bit of save state just for it.
var _fixed_farm_option_id := "farm"

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

	## GameState is an autoload - unlike Base itself, it's never destroyed
	## when MainMenu switches scenes into Base.tscn, so a second (or third)
	## playthrough in the same process run would otherwise start with
	## whatever resources/population/etc. the *previous* game ended with.
	## Safe to do unconditionally, even when about to load a save right
	## below - _load_game() overwrites every one of these fields from the
	## save data regardless of what they were reset to first.
	GameState.reset_to_defaults()

	var min_cell := Vector2i(iso_ground.start_x, iso_ground.start_y)
	var max_cell := Vector2i(iso_ground.start_x + iso_ground.width - 1, iso_ground.start_y + iso_ground.depth - 1)
	WorldGrid.configure(iso_ground.position, min_cell, max_cell, self)
	WorldGrid.stockpile_spot = $OutpostHall.get_stockpile_spot()
	_configure_camera_limits(min_cell, max_cell)

	posts.append($Farm)
	posts.append($Woodpile)
	posts.append($OutpostHall)
	$Farm.set_meta("save_id", "farm")
	$Woodpile.set_meta("save_id", "woodpile")
	$OutpostHall.set_meta("save_id", "outpost_hall")
	_wire_farm_clicks($Farm)

	_reserve_existing_footprint($OutpostHall, BuildingCatalog.get_option("outpost_hall")["grid_size"])
	_reserve_existing_footprint($Farm, BuildingCatalog.get_option("farm")["grid_size"])
	_reserve_existing_footprint($Woodpile, BuildingCatalog.get_option("woodpile")["grid_size"])

	_scatter_initial_trees()

	for character in characters:
		character.drag_started.connect(_on_character_drag_started)
		## Aldric/Brenna/Cass are hand-authored .tres resources loaded once
		## and shared by every instantiation of Base.tscn in this process -
		## unlike a fresh CharacterData for a recruit, their skill/happiness
		## progress from a *previous* playthrough (MainMenu -> New Game
		## again, in the same process run) would otherwise still be sitting
		## on the resource when this new game starts. Reset unconditionally,
		## same reasoning as GameState.reset_to_defaults() above -
		## _restore_characters() overwrites these fields anyway if a save
		## is about to be loaded on top.
		character.data.skill_xp = {}
		character.data.happiness = HAPPINESS_BASELINE
		character.data.unhappy_streak = 0
		## The 3 starting citizens' .tres resources predate the id field -
		## backfill a stable one (their node name is unique and never
		## changes) rather than leaving it empty, which would make them
		## indistinguishable from each other for save/load matching.
		if character.data.id.is_empty():
			character.data.id = character.name

	build_menu.option_selected.connect(_on_build_option_selected)
	hud.build_pressed.connect(_on_build_pressed)
	hud.menu_pressed.connect(_open_system_menu)

	recruit_panel.candidate_selected.connect(_on_candidate_selected)
	$OutpostHall.clicked.connect(_on_outpost_hall_clicked)

	crop_panel.option_selected.connect(_on_crop_selected)

	system_menu.save_pressed.connect(func() -> void: _open_slot_panel("save"))
	system_menu.load_pressed.connect(func() -> void: _open_slot_panel("load"))
	system_menu.main_menu_pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/menu/MainMenu.tscn"))
	system_menu.quit_pressed.connect(func() -> void: get_tree().quit())
	slot_panel.slot_chosen.connect(_on_slot_panel_chosen)

	var happiness_timer := Timer.new()
	happiness_timer.wait_time = HAPPINESS_TICK_INTERVAL
	happiness_timer.timeout.connect(_on_happiness_tick)
	add_child(happiness_timer)
	happiness_timer.start()
	var initial_average := get_average_happiness()
	var initial_band := _happiness_band(initial_average)
	GameState.happiness_output_multiplier = initial_band["multiplier"]
	hud.set_happiness(initial_average, initial_band["name"])

	## MainMenu's "Continue"/"Load Game" set this before switching into this
	## scene; "New Game" leaves it false so this boot stays on the fresh
	## state everything above just set up. Consumed once and cleared so a
	## later F9/in-game load doesn't re-trigger this on some future scene
	## reload (e.g. Main Menu -> Continue again).
	if SaveManager.should_load_on_start:
		SaveManager.should_load_on_start = false
		_load_game()


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


## Recomputes a target happiness from current settlement conditions and
## eases every citizen toward it (see HAPPINESS_EASE_RATE), rather than
## setting happiness directly - conditions changing (e.g. the well running
## dry) should be felt gradually, not as an instant jump. Citizens who've
## sat below UNHAPPY_THRESHOLD for LEAVE_AFTER_UNHAPPY_TICKS consecutive
## ticks leave for good.
func _on_happiness_tick() -> void:
	var target := HAPPINESS_BASELINE
	target += HAPPINESS_WATER_BONUS if GameState.has_water() else -HAPPINESS_WATER_BONUS
	target += HAPPINESS_FOOD_BONUS if GameState.resources.get("food", 0.0) > 0.0 else -HAPPINESS_STARVING_PENALTY
	target += _food_variety_count() * HAPPINESS_PER_FOOD_VARIETY
	target = clampf(target, 0.0, 100.0)

	for character in characters.duplicate():
		if not is_instance_valid(character):
			continue
		var data: CharacterData = character.data
		data.happiness = move_toward(data.happiness, target, HAPPINESS_EASE_RATE)
		if data.happiness < UNHAPPY_THRESHOLD:
			data.unhappy_streak += 1
			if data.unhappy_streak >= LEAVE_AFTER_UNHAPPY_TICKS:
				_character_leaves(character)
		else:
			data.unhappy_streak = 0

	var average := get_average_happiness()
	var band := _happiness_band(average)
	GameState.happiness_output_multiplier = band["multiplier"]
	hud.set_happiness(average, band["name"])


## How many of GameState.FOOD_RESOURCES currently have stock - "food
## variety gives improved happiness" per the design doc.
func _food_variety_count() -> int:
	var count := 0
	for resource_name in GameState.FOOD_RESOURCES:
		if GameState.resources.get(resource_name, 0.0) > 0.0:
			count += 1
	return count


## First entry in HAPPINESS_BANDS (highest "min" first) that `average`
## clears - the bands' own ordering does the sorting, so this is just a
## linear scan rather than needing them pre-sorted separately.
func _happiness_band(average: float) -> Dictionary:
	for band in HAPPINESS_BANDS:
		if average >= band["min"]:
			return band
	return HAPPINESS_BANDS[-1]


func get_average_happiness() -> float:
	if characters.is_empty():
		return 0.0
	var total := 0.0
	for character in characters:
		total += character.data.happiness
	return total / characters.size()


## A citizen departing for good - perma-death's sibling for "left rather
## than died" (see the design doc's Core Systems notes on perma-death).
## Permanent within THIS session: nothing un-departs them short of loading a
## save from before they left, same as any other town state a load reverts -
## _restore_characters recreates whoever's in the save but missing from the
## live roster (see its own docs), recruits and departed citizens alike.
func _character_leaves(character: Character) -> void:
	character.leave()
	if _selected_character == character:
		_deselect()
	if _drag_character == character:
		_drag_character = null
		_drag_moved = false
	characters.erase(character)
	GameState.population_count = maxi(0, GameState.population_count - 1)
	GameState.population_changed.emit(GameState.population_count, GameState.population_capacity)
	character.queue_free()


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
	## SystemMenu/SlotPanel handle their own Esc-to-close via their own
	## _input() (which always runs before _unhandled_input regardless of
	## tree order - see CLAUDE.md's RtsCamera note for the same mechanism),
	## so nothing to do here for that. What's missing without this check is
	## mouse clicks: neither panel intercepts those, so without swallowing
	## them here a click while either is open would fall all the way
	## through to whatever's underneath (selecting a citizen, deselecting,
	## assigning to a post...) instead of being absorbed by the modal menu
	## on top of it.
	if (system_menu.visible or slot_panel.visible) and event is InputEventMouseButton and event.pressed:
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
	if recruit_panel.visible and ((event is InputEventMouseButton and event.pressed) or event.is_action_pressed("ui_cancel")):
		recruit_panel.close()
		return
	if crop_panel.visible and ((event is InputEventMouseButton and event.pressed) or event.is_action_pressed("ui_cancel")):
		crop_panel.close()
		return
	if _selected_character == null:
		## Esc only reaches here once nothing else above had anything to
		## back out of - deselecting a citizen (below) takes priority over
		## opening the system menu, so Esc backs out one layer at a time
		## rather than jumping straight to the menu while something's
		## still selected.
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			_open_system_menu()
		return
	if event is InputEventMouseButton and event.pressed:
		## A Farm-family post intercepts its own click before this ever runs
		## (see _on_farm_clicked) - this only fires for post types with no
		## click handler of their own (LumberCamp, StoneMine, WallSegment),
		## resolved the same way a drag-drop already is: a physics point
		## query against `posts`, not a per-post signal.
		if event.button_index == MOUSE_BUTTON_LEFT:
			var post := _post_at(get_global_mouse_position())
			if post:
				_assign_selected_to(post)
				return
		_deselect()
	elif event.is_action_pressed("ui_cancel"):
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
	if _post_has_room(post, character):
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


## Whether `for_character` could be assigned to `post` right now - false for
## a null post, or one already at its max_workers (duck-typed on Workstation
## and WallSegment, which each set their own default - see their max_workers
## doc comments). Always true for a post `for_character` is already assigned
## to: re-dropping them back onto their current post shouldn't be blocked
## just because they themselves count toward its own occupancy.
func _post_has_room(post: Node, for_character: Character = null) -> bool:
	if not post:
		return false
	if for_character and for_character.assigned_post == post:
		return true
	return post.active_workers < post.max_workers


## Clicking a citizen selects them (opening their skill panel) rather than
## opening a menu of assignable posts - assignment itself now happens by
## dragging them onto a post, or by clicking a post while they're selected
## (see _unhandled_input/_on_farm_clicked). Clicking the *same* already-
## selected citizen again unassigns them instead (set them idle) rather
## than being a no-op - with the old task menu's "[0] Idle" option gone,
## this is the replacement gesture for "stop working."
func _on_character_selected(character: Character) -> void:
	if _placing_option:
		return
	if _selected_character == character:
		character.assign_to(null)
		_deselect()
		return
	if _selected_character:
		_selected_character.set_selected(false)
	_selected_character = character
	_selected_character.set_selected(true)
	skill_panel.open_for(character)


## Assigns _selected_character to `post` if it has room (see
## _post_has_room), or flashes a denial, then deselects either way -
## shared by _unhandled_input's generic post click and _on_farm_clicked's
## "a Farm was clicked while a citizen is selected" branch.
func _assign_selected_to(post: Node) -> void:
	var character := _selected_character
	if _post_has_room(post, character):
		character.assign_to(post)
	else:
		hud.flash_message("%s is full" % post.display_name)
	_deselect()


func _deselect() -> void:
	if _selected_character:
		_selected_character.set_selected(false)
	_selected_character = null
	skill_panel.close()


func _on_build_pressed() -> void:
	_cancel_placement()
	if _selected_character:
		_deselect()
	recruit_panel.close()
	crop_panel.close()
	build_menu.open_for(BuildingCatalog.placeable_options())


## Shared by the HUD's Menu button and Esc (see _unhandled_input) - closes
## whatever else might be open first, same as every other panel-opening
## entry point in this file, so SystemMenu never ends up stacked on top of
## an unrelated selection/panel.
func _open_system_menu() -> void:
	_cancel_placement()
	if _selected_character:
		_deselect()
	build_menu.close()
	recruit_panel.close()
	crop_panel.close()
	system_menu.open()


## A citizen selected when the Outpost Hall is clicked assigns them there as
## a hauler instead of opening the recruit panel - same "clicked posts take
## priority for assignment over their other click behavior" rule
## _on_farm_clicked already follows for the crop-selection panel.
func _on_outpost_hall_clicked() -> void:
	if _selected_character:
		_assign_selected_to($OutpostHall)
		return
	_cancel_placement()
	build_menu.close()
	crop_panel.close()
	recruit_panel.open_for(RecruitCatalog.generate_candidates())


## Connects a Farm-family building's clicked signal (see Farm.gd) so
## clicking it opens the crop-selection panel - called for both fixed
## scene-file Farms ($Farm) and every dynamically placed/restored one.
## Buildings that aren't Farm instances (LumberCamp, StoneMine, passive
## structures) don't have this signal at all, so this is a no-op for them.
func _wire_farm_clicks(building: Node) -> void:
	if building is Farm:
		building.clicked.connect(_on_farm_clicked.bind(building))


## A Farm's own `clicked` signal (see Farm.gd) always reaches here first,
## before _unhandled_input's generic post-click handling ever gets a look -
## so unlike other post types, a Farm has to decide for itself whether a
## click means "assign the selected citizen here" or "open the crop-
## selection panel", based on whether a citizen happens to be selected.
func _on_farm_clicked(farm: Farm) -> void:
	if _selected_character:
		_assign_selected_to(farm)
		return
	_cancel_placement()
	build_menu.close()
	recruit_panel.close()
	_crop_target = farm
	crop_panel.open_for(BuildingCatalog.farm_family_options(), farm.display_name)


## Reconfigures _crop_target in place with `option`'s Farm-family fields
## (resource_type/input_resource/input_per_tick/output_per_tick/skill_id/
## sprite_tint/work_interval) via the same _apply_option_properties used for
## placing a brand new building - this is a free, instant retool, not a
## rebuild, so the node itself (and its assigned workers/coroutines) is left
## alone; retooling into/out of Mill/Bakery/Brewery correctly switches which
## skill the assigned worker trains going forward, same as any other field.
## Clears output_buffer/input_buffer since whatever was accumulated
## under the old recipe doesn't carry over to the new one (e.g. half a load
## of grain sitting in a buffer that's about to become a Bakery's flour
## input would be a silent, confusing bug otherwise) - an accepted loss on
## switching, same spirit as storage overflow being lost rather than
## refunded elsewhere in this game. Character's work loops re-read the
## post's fields fresh every iteration, so an already-assigned worker just
## starts producing the new recipe on their next pass with no need to
## restart their coroutine.
func _on_crop_selected(option: Dictionary) -> void:
	if not is_instance_valid(_crop_target):
		return
	_apply_crop_option(_crop_target, option)
	_crop_target.output_buffer = 0.0
	_crop_target.input_buffer = 0.0
	hud.flash_message("Now growing %s" % option["display_name"])

	## Keep whatever tracks this building's recipe for save/load in sync -
	## otherwise a retool would silently revert on the next save/load
	## round-trip, since both paths rebuild a Farm-family building's fields
	## from an option_id rather than reading them live off the node.
	if _crop_target == $Farm:
		_fixed_farm_option_id = option["id"]
	else:
		for entry in _placed_buildings:
			if entry["node"] == _crop_target:
				entry["option_id"] = option["id"]
				break

	_crop_target = null


## Applies a Farm-family option's fields and refreshes the sprite to match -
## the part of "place/restore/retool a Farm-family building" that's common
## to all three, without the buffer-clearing/flash-message side effects
## that only make sense for an interactive retool (_on_crop_selected), not
## for silently re-establishing state during load (_load_game).
func _apply_crop_option(building: Node, option: Dictionary) -> void:
	_apply_option_properties(building, option)
	building.refresh_visual()


func _on_candidate_selected(candidate: Dictionary) -> void:
	if GameState.population_count >= GameState.population_capacity:
		hud.flash_message("No housing available")
		return
	if not GameState.can_afford(RecruitCatalog.RECRUIT_COST):
		hud.flash_message("Not enough food")
		return
	GameState.spend(RecruitCatalog.RECRUIT_COST)

	var character := _spawn_character(candidate["name"], $OutpostHall.get_stockpile_spot())
	character.data.skill_xp[candidate["skill_id"]] = candidate["starting_xp"]

	GameState.population_count += 1
	GameState.population_changed.emit(GameState.population_count, GameState.population_capacity)
	hud.flash_message("%s joined the outpost" % character.data.character_name)


## Instantiates a fresh Character with a fresh CharacterData (not a shared
## .tres like Aldric/Brenna/Cass - recruits are procedurally generated, not
## hand-authored) and registers it exactly like the 3 starting citizens are
## in _ready(): added as a direct child of Base (required for y-sorting -
## see CLAUDE.md), appended to `characters`, wired to drag_started. Does NOT
## touch GameState.population_count or spend anything - callers decide
## whether that applies (a fresh recruit does both; _restore_characters
## recreating a missing citizen from a save does neither, since the saved
## population_count already accounts for them).
## `id` lets a caller pin the save/load identity (used when recreating a
## citizen from a save entry); left empty, a fresh one is generated - two
## recruits can share a display name (RecruitCatalog's pool is small) but
## must never share an id, since save/load matches on id, not name.
func _spawn_character(character_name: String, spawn_position: Vector2, id: String = "") -> Character:
	var data := CharacterData.new()
	data.character_name = character_name
	data.id = id if not id.is_empty() else "citizen_%d_%d" % [Time.get_ticks_usec(), randi()]
	var character: Character = CHARACTER_SCENE.instantiate()
	character.data = data
	character.position = spawn_position
	add_child(character)
	characters.append(character)
	character.drag_started.connect(_on_character_drag_started)
	return character


func _on_build_option_selected(option: Dictionary) -> void:
	_cancel_placement()
	_placing_option = option
	_ghost = option["scene"].instantiate()
	_apply_option_properties(_ghost, option)
	if _ghost.has_node("Label"):
		_ghost.get_node("Label").visible = false
	## Farm's (and any future clickable post's) input_event handler would
	## otherwise fire on the ghost too - it follows the cursor, so it's
	## almost always directly under it - and calls set_input_as_handled()
	## before Base._unhandled_input() ever sees the click, silently
	## swallowing the very click meant to confirm placement (see
	## Base._on_outpost_hall_clicked/_on_farm_clicked for why that call
	## reliably pre-empts _unhandled_input in this codebase).
	if _ghost is CollisionObject2D:
		(_ghost as CollisionObject2D).input_pickable = false
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
	_wire_farm_clicks(building)

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


## --- Save / load (F5 quicksave, F9 quickload, or the in-game System Menu) --

func _open_slot_panel(purpose: String) -> void:
	_slot_panel_purpose = purpose
	slot_panel.open_for(purpose)


## slot_panel itself doesn't know or care why it was opened - see
## _slot_panel_purpose's doc comment. Either way, the chosen slot becomes
## SaveManager.active_slot going forward, so a subsequent F5/F9 (or picking
## "Save"/"Load" again without specifying a slot) keeps acting on whichever
## one the player most recently interacted with here.
func _on_slot_panel_chosen(slot: int) -> void:
	SaveManager.active_slot = slot
	if _slot_panel_purpose == "save":
		_save_game()
	elif _slot_panel_purpose == "load":
		_load_game()


func _save_game() -> void:
	var data := {
		"version": 1,
		"saved_at": int(Time.get_unix_time_from_system()),
		"resources": GameState.resources.duplicate(),
		"population_count": GameState.population_count,
		"population_capacity": GameState.population_capacity,
		"water_wells": GameState.water_wells,
		"storage_capacity": GameState.storage_capacity,
		"trees": _serialize_trees(),
		"placed_buildings": _serialize_placed_buildings(),
		"post_buffers": _serialize_post_buffers(),
		"characters": _serialize_characters(),
		"fixed_farm_option_id": _fixed_farm_option_id,
	}
	SaveManager.save_game(SaveManager.active_slot, data)
	hud.flash_message("Saved")


func _load_game() -> void:
	var data := SaveManager.load_game(SaveManager.active_slot)
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

	## $Farm is a fixed scene-file building, not one of the entries
	## _restore_placed_buildings rebuilds - its recipe (if ever retooled via
	## the crop-selection panel) is tracked separately and reapplied here.
	## Done before _restore_post_buffers below, since (unlike
	## _on_crop_selected's interactive path) this must NOT clear
	## output_buffer/input_buffer - the save's actual buffer values are the
	## authority here, not the empty-buffer reset a live retool wants.
	_fixed_farm_option_id = data.get("fixed_farm_option_id", "farm")
	var fixed_farm_option := BuildingCatalog.get_option(_fixed_farm_option_id)
	if not fixed_farm_option.is_empty():
		_apply_crop_option($Farm, fixed_farm_option)

	## Buildings are restored before trees: WorldGrid.plant_tree() doesn't
	## check cell occupancy, and a stale placed building torn down after
	## trees are replanted could release a cell a just-restored tree also
	## claimed, leaving WorldGrid.is_free() wrong about that cell forever.
	_restore_placed_buildings(data.get("placed_buildings", []))
	_restore_trees(data.get("trees", []))
	_restore_post_buffers(data.get("post_buffers", {}))
	_restore_characters(data.get("characters", []))

	## Safety net, not the primary source of truth: _restore_characters
	## above already adds/removes citizens to exactly match the save's
	## entries, so characters.size() should already equal the saved
	## population_count. This just keeps the count honest if the two ever
	## disagree (e.g. a hand-edited save file).
	if GameState.population_count != characters.size():
		GameState.population_count = characters.size()
		GameState.population_changed.emit(GameState.population_count, GameState.population_capacity)

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
		_wire_farm_clicks(building)
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
			"id": character.data.id,
			"name": character.data.character_name,
			"skill_xp": character.data.skill_xp.duplicate(),
			"happiness": character.data.happiness,
			"unhappy_streak": character.data.unhappy_streak,
			"assigned_save_id": save_id,
		})
	return out


## Matched by CharacterData.id, not character_name - RecruitCatalog draws
## from a small procedural name pool, so two live citizens can end up
## sharing a display name, and name-based matching would silently misapply
## one citizen's saved data to the other. Saves written before `id` existed
## have no "id" field; those fall back to matching by name (best-effort
## one-time migration, not relied on going forward).
## A saved entry with no live match is recreated via _spawn_character rather
## than silently dropped - this covers both a recruit that doesn't exist yet
## on a fresh game boot (only Aldric/Brenna/Cass start in the scene file)
## and a citizen who left after the save being loaded was made (loading is
## reverting to that point in time, so they should come back, same as any
## other town state a load reverts). Symmetrically, a *live* citizen with no
## matching save entry didn't exist yet at the point this save was made
## (e.g. recruited after it) and is removed. _spawn_character deliberately
## doesn't touch population_count/spend anything - the save's wholesale
## population_count already accounts for every entry being restored here.
func _restore_characters(entries: Array) -> void:
	var by_id := {}
	var by_name := {}
	for character in characters:
		by_id[character.data.id] = character
		by_name[character.data.character_name] = character

	var matched_ids := {}
	for entry in entries:
		var entry_id: String = entry.get("id", "")
		var entry_name: String = entry.get("name", "")
		var character: Character = by_id.get(entry_id) if not entry_id.is_empty() else by_name.get(entry_name)
		if not character:
			character = _spawn_character(entry_name, $OutpostHall.get_stockpile_spot(), entry_id)
		if not entry_id.is_empty():
			character.data.id = entry_id
		character.data.character_name = entry_name
		character.data.skill_xp = (entry.get("skill_xp", {}) as Dictionary).duplicate()
		character.data.happiness = float(entry.get("happiness", character.data.happiness))
		character.data.unhappy_streak = int(entry.get("unhappy_streak", 0))
		character.assign_to(_post_by_save_id(entry.get("assigned_save_id", "")))
		matched_ids[character.data.id] = true

	## Any live citizen not accounted for above didn't exist at the point
	## this save was made - remove them so loading actually reverts state
	## rather than only ever adding citizens back.
	for character in characters.duplicate():
		if not matched_ids.has(character.data.id):
			character.leave()
			characters.erase(character)
			character.queue_free()


func _post_by_save_id(save_id: String) -> Node:
	if save_id.is_empty():
		return null
	if save_id == "farm":
		return $Farm
	if save_id == "woodpile":
		return $Woodpile
	if save_id == "outpost_hall":
		return $OutpostHall
	for entry in _placed_buildings:
		if entry["save_id"] == save_id:
			return entry["node"]
	return null
