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

## --- Fast-forward -----------------------------------------------------
## Companion to slowing base movement/work speed down by a factor of 2 (see
## Character.MOVE_SPEED/Workstation.work_interval's own doc comments) - lets
## a player compress the resulting downtime back down instead of just
## sitting through it. Same Engine.time_scale mechanism CombatTestManager's
## own speed control already uses (see its own SPEED_MULTIPLIERS), applied
## here to the town scene instead of a battle - a global engine setting, so
## _exit_tree() resets it to 1.0 on every way out of this scene, same reason
## that scene resets it too (otherwise 4x would carry into whatever loads
## next - a menu, a save-load animation, even a deployed battle before its
## own _apply_speed() overrides it in _ready()).
const SPEED_MULTIPLIERS := [1.0, 2.0, 4.0]
var speed_index := 0

## --- Battle deployment -----------------------------------------------------
## See _on_attack_pressed/BattleState.gd for the full handoff. CombatTest.tscn
## is the same standalone sandbox scene the main menu's "Battle Test" button
## and F6 already use - branching on BattleState.active is what tells it
## apart from a real deployment, see CombatTestManager's own doc comment.
const COMBAT_TEST_SCENE := "res://scenes/combat/CombatTest.tscn"

## Round-robin distribution for citizens trained in "melee_combat" - that one
## skill can't disambiguate which of CombatUnit's four melee archetypes
## (Shieldbearer/Marauder/Outrider/Trapper) a citizen becomes, since nothing
## on CharacterData tracks a sub-specialization (see Outpost_Survival/Ideas/
## Combat Units.md's deferred-integration note - no existing design answer
## to honor here). Cycling through all four by squad-roster order is a
## deliberately simple first pass - keeps a defending squad from being an
## all-Shieldbearer wall (a weak, easily-baited composition per the point-
## cost table in Ideas/Combat Units.md) without inventing a new stat/UI just
## for this. Revisit once there's a real archetype-selection mechanic.
const MELEE_ARCHETYPES := [
	CombatUnit.UnitType.SHIELDBEARER, CombatUnit.UnitType.MARAUDER,
	CombatUnit.UnitType.OUTRIDER, CombatUnit.UnitType.TRAPPER,
]

## --- Day/night visual tint ------------------------------------------------
## Multiplies onto every world CanvasItem (ground, buildings, characters,
## trees) via $DayNightTint - a CanvasModulate, which only affects the same
## canvas it sits in, not any CanvasLayer (every UI panel, including HUD, is
## a CanvasLayer - see CLAUDE.md - so none of them darken at night).
## Deliberately a moderate dusk-blue rather than near-black - work/haul
## loops keep running unchanged through the night (see DayNightCycle's own
## doc comment - only the clock + this tint + the recruit cooldown are wired
## up so far), so night shouldn't read as "nothing is visible," just
## atmospheric.
const DAY_TINT := Color(1.0, 1.0, 1.0)
const NIGHT_TINT := Color(0.38, 0.42, 0.58)
const DAY_NIGHT_TRANSITION_SECONDS := 8.0

## --- Building system -----------------------------------------------------
## Placing a building no longer completes it instantly - it spawns a
## ConstructionSite instead (see _confirm_placement/_spawn_construction_site),
## which haulers stock with the option's own cost (see
## ConstructionSite.materials_needed) and a construction-skilled worker then
## spends labor on (see Character._run_construction_loop) before it becomes
## the real building (see _on_construction_complete).
const CONSTRUCTION_SITE_SCENE := preload("res://scenes/workstation/ConstructionSite.tscn")

## A site's total labor_required is derived from its own material cost
## (bigger/more expensive buildings take longer to build) rather than a
## separate hand-authored number per catalog entry - LABOR_PER_MATERIAL_UNIT
## multiplies the sum of every resource unit in the option's cost dict, with
## MIN_LABOR_REQUIRED as a floor so even a very cheap building still takes a
## meaningful amount of labor rather than finishing in a single tick. Both
## first-pass numbers, not tuned via playtesting.
const LABOR_PER_MATERIAL_UNIT := 2.0
const MIN_LABOR_REQUIRED := 10.0

## --- Happiness ---------------------------------------------------------
## Every tick, each citizen's happiness eases toward a target recomputed
## from current settlement conditions (see _on_happiness_tick) rather than
## jumping straight to it - HAPPINESS_EASE_RATE caps how much it can move
## per tick, so a sudden change in conditions takes several ticks to be
## fully felt. Numbers below are a first pass, not iterated on via
## playtesting.
const HAPPINESS_TICK_INTERVAL := 5.0
## Lowered 3.0 -> 1.0 via Outpost_Survival/Balance.md's edit-and-hand-back
## workflow - a condition change now takes noticeably longer to fully felt.
const HAPPINESS_EASE_RATE := 1.0
const HAPPINESS_BASELINE := 50.0
## Lowered 15.0 -> 5.0 via Outpost_Survival/Balance.md's edit-and-hand-back
## workflow.
const HAPPINESS_WATER_BONUS := 5.0
## Lowered 15.0 -> 10.0 via Outpost_Survival/Balance.md's edit-and-hand-back
## workflow.
const HAPPINESS_FOOD_BONUS := 10.0
const HAPPINESS_STARVING_PENALTY := 20.0
const HAPPINESS_PER_FOOD_VARIETY := 5.0
## Below this, a citizen is "unhappy" and starts accumulating toward leaving.
## Lowered 20.0 -> 15.0 via Outpost_Survival/Balance.md's edit-and-hand-back
## workflow.
const UNHAPPY_THRESHOLD := 15.0
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

const CHARACTER_SCENE := preload("res://scenes/character/Character.tscn")

@onready var skill_panel: SkillPanel = $SkillPanel
@onready var build_menu: BuildMenu = $BuildMenu
@onready var recruit_panel: RecruitPanel = $RecruitPanel
@onready var crop_panel: CropPanel = $CropPanel
@onready var training_ground_panel: TrainingGroundPanel = $TrainingGroundPanel
@onready var system_menu: SystemMenu = $SystemMenu
@onready var slot_panel: SlotPanel = $SlotPanel
@onready var hud: HUD = $HUD
@onready var iso_ground: IsoGround = $IsoGround
@onready var camera: RtsCamera = $Camera2D
@onready var day_night_tint: CanvasModulate = $DayNightTint
@onready var nav_region: NavigationRegion2D = $NavigationRegion2D
@onready var characters: Array[Character] = [$Aldric, $Brenna, $Cass]

var posts: Array[Node] = []

## Buildings still under construction - see the "Building system" consts
## above. Deliberately NOT part of `posts` while still gathering materials
## (ConstructionSite.materials_ready hasn't fired yet - see
## _on_construction_materials_ready), so _job_posts()/_run_job_assignment()
## never try to staff a site that has nothing to build with yet. A site is
## removed from here (and from `posts`, if it had been added) the moment
## construction finishes - see _on_construction_complete.
var construction_sites: Array[ConstructionSite] = []

## The Farm-family building currently open in crop_panel, set by
## _on_farm_clicked and consumed by _on_crop_selected. Only one crop panel
## can be open at a time (opening a new one closes any other panel first,
## same as recruit/build), so a single field is enough - no stack needed.
var _crop_target: Farm = null

## Which TrainingGround (if any) opened recruit_panel - null means the
## Outpost Hall's own normal recruitment instead. _on_candidate_selected
## reads this to decide which cooldown to mark (DayNightCycle's shared one
## for the Outpost Hall, or this specific building's own independent one -
## see TrainingGround.mark_recruited) - same single-field-no-stack reasoning
## as _crop_target, since recruit_panel can likewise only be open for one
## source at a time.
var _recruit_source: TrainingGround = null

## Which TrainingGround training_ground_panel is currently open for - set by
## _on_training_ground_clicked, consumed by _on_training_ground_option_chosen.
## Same single-field-no-stack reasoning as _crop_target/_recruit_source,
## since training_ground_panel can likewise only be open for one building at
## a time.
var _training_ground_target: TrainingGround = null

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

var _selected_character: Character = null

var _placing_option: Dictionary = {}
var _ghost: Node2D = null
var _ghost_origin := Vector2i.ZERO
var _ghost_valid := false


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
	DayNightCycle.reset_to_defaults()

	var min_cell := Vector2i(iso_ground.start_x, iso_ground.start_y)
	var max_cell := Vector2i(iso_ground.start_x + iso_ground.width - 1, iso_ground.start_y + iso_ground.depth - 1)
	WorldGrid.configure(iso_ground.position, min_cell, max_cell, self)
	WorldGrid.register_stockpile($OutpostHall.get_stockpile_spot())
	_configure_camera_limits(min_cell, max_cell)

	## Only the Outpost Hall starts built - a Cabbage Farm and Lumber Camp
	## used to be fixed starting buildings too, but the player now has to
	## build everything else themselves - see GameState.DEFAULT_RESOURCES for
	## why the starting cabbage/wood amounts are what they are (a Lumber
	## Camp/Cabbage Farm/half a House outright, plus enough cabbage to
	## recruit immediately without starving before the first farm is built
	## and staffed).
	## Not appended to `posts` - it's never a job post (see _job_posts), only
	## a stockpile drop-off point.
	$OutpostHall.set_meta("save_id", "outpost_hall")

	_reserve_existing_footprint($OutpostHall, BuildingCatalog.get_option("outpost_hall")["grid_size"])

	_scatter_initial_trees()

	## Baked once here (after every starting cell reservation above) and
	## re-baked on every subsequent WorldGrid.occupancy_changed (a building
	## placed/completed, a tree planted/harvested) rather than once at boot -
	## see WorldGrid.occupancy_changed's own doc comment for why the town's
	## navmesh can't be treated as fixed-for-the-session the way the battle
	## sandbox's is.
	_rebake_navigation()
	WorldGrid.occupancy_changed.connect(_rebake_navigation)

	for character in characters:
		character.clicked.connect(_on_character_selected)
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
	hud.attack_pressed.connect(_on_attack_pressed)
	hud.speed_pressed.connect(_on_speed_button_pressed)
	hud.menu_pressed.connect(_open_system_menu)

	recruit_panel.candidate_selected.connect(_on_candidate_selected)
	training_ground_panel.option_chosen.connect(_on_training_ground_option_chosen)
	$OutpostHall.clicked.connect(_on_outpost_hall_clicked)

	crop_panel.option_selected.connect(_on_crop_selected)
	DayNightCycle.day_started.connect(_on_day_started)
	DayNightCycle.night_started.connect(_on_night_started)

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

	## Returning from a battle deployment (_on_attack_pressed sent the player
	## to CombatTest.tscn) takes priority over the two boot paths below -
	## town_blob is only ever non-empty on the scene reload right after
	## CombatTestManager hands control back (see _apply_battle_result), never
	## on a genuine main-menu boot. Checked and cleared before either of the
	## other two so a stale blob can't leak into some later "New Game"/
	## "Continue" boot.
	if not BattleState.town_blob.is_empty():
		var blob := BattleState.town_blob
		var battle_result := BattleState.result
		BattleState.clear()
		_apply_state(blob)
		_apply_battle_result(battle_result)
	## MainMenu's "Continue"/"Load Game" set this before switching into this
	## scene; "New Game" leaves it false so this boot stays on the fresh
	## state everything above just set up. Consumed once and cleared so a
	## later F9/in-game load doesn't re-trigger this on some future scene
	## reload (e.g. Main Menu -> Continue again).
	elif SaveManager.should_load_on_start:
		SaveManager.should_load_on_start = false
		_load_game()
	else:
		## _load_game() already ends with its own _run_job_assignment() call
		## (covering boot-load and any later F9/menu load) - this covers the
		## fresh "New Game" path, which never calls _load_game() at all.
		_run_job_assignment()

	## Snapped immediately (no tween) to whatever phase DayNightCycle ended
	## up in above - deliberately placed after every load/apply-state branch,
	## not right where day_started/night_started got connected, since a save
	## load or a battle-spanning-a-day-boundary return can leave DayNightCycle
	## on night even though it was freshly reset_to_defaults() (day) at the
	## very top of this function. Only day_started/night_started firing
	## *after* this point should tween - see _on_day_started/_on_night_started.
	day_night_tint.color = DAY_TINT if DayNightCycle.is_day else NIGHT_TINT
	hud.set_day_label(DayNightCycle.day_number, DayNightCycle.is_day)

	## Fast-forward always boots at 1x - a transient display preference, not
	## saved game state, same as CombatTestManager's own speed_index never
	## persisting across that scene's own reloads.
	_apply_speed()


## Safety net alongside the explicit key-triggered changes in
## _unhandled_input - covers every other way this scene could end up
## removed from the tree (System Menu -> Main Menu, a battle deployment,
## quitting) without leaving Engine.time_scale stuck elevated for whatever
## loads next. Mirrors CombatTestManager._exit_tree() exactly, same reason.
func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _apply_speed() -> void:
	Engine.time_scale = SPEED_MULTIPLIERS[speed_index]
	hud.set_speed_label(SPEED_MULTIPLIERS[speed_index])


func _on_speed_button_pressed() -> void:
	speed_index = (speed_index + 1) % SPEED_MULTIPLIERS.size()
	_apply_speed()


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


## Fraction of a full tile diamond a single occupied cell's obstruction
## outline actually covers - shrunk well below 1.0 (not a full tile) so a
## building's own WorkSpot marker, deliberately placed right at its
## footprint's near edge (see e.g. Farm.tscn's WorkSpot vs. its front cell's
## own diamond corners), never ends up *inside* the hole its own building
## creates - that would leave NavigationAgent2D.is_navigation_finished()
## permanently false for anyone walking there (see Character._move_to),
## freezing that citizen's whole work loop. Verified against every current
## WorkSpot offset (all sit at local y=26-30, versus a shrunk cell's own
## near-corner at TILE_HEIGHT*0.5*this = 19.2px) before picking this value.
const NAV_OBSTACLE_SHRINK := 0.6


## Baked in code (see CombatTestManager._setup_navigation's identical
## pattern for the battle sandbox) rather than authored in the editor, so it
## can't drift out of sync with the ground's actual size - and re-baked on
## every WorldGrid.occupancy_changed (see _ready()) rather than once at
## boot, since the town's walkable area keeps changing shape all session
## (buildings built, trees planted/harvested) unlike a single fight's fixed
## terrain. One obstruction outline per occupied WorldGrid cell (buildings,
## construction sites, and trees alike - see WorldGrid.get_occupied_cells)
## rather than one polygon per building, so this doesn't need to know
## anything about footprint anchoring/shapes at all, just the same cell
## occupancy building placement/tree planting already maintain.
func _rebake_navigation() -> void:
	var nav_poly := NavigationPolygon.new()
	nav_poly.add_outline(_ground_outline())
	var source_geometry := NavigationMeshSourceGeometryData2D.new()
	for cell in WorldGrid.get_occupied_cells():
		source_geometry.add_obstruction_outline(_cell_obstacle_outline(cell))
	NavigationServer2D.bake_from_source_geometry_data(nav_poly, source_geometry)
	nav_region.navigation_polygon = nav_poly


## The ground's own isometric footprint (see WorldGrid.bounds_min/bounds_max),
## not an axis-aligned rectangle - same reasoning as CombatTestManager's
## _iso_ground_corners (a rectangular navmesh around a diamond map would let
## citizens path into the rectangle's corners, past the last visible tile).
func _ground_outline() -> PackedVector2Array:
	var gx0 := float(WorldGrid.bounds_min.x) - 0.5
	var gx1 := float(WorldGrid.bounds_max.x) + 0.5
	var gy0 := float(WorldGrid.bounds_min.y) - 0.5
	var gy1 := float(WorldGrid.bounds_max.y) + 0.5
	return PackedVector2Array([
		WorldGrid.grid_to_local(Vector2(gx0, gy0)),
		WorldGrid.grid_to_local(Vector2(gx1, gy0)),
		WorldGrid.grid_to_local(Vector2(gx1, gy1)),
		WorldGrid.grid_to_local(Vector2(gx0, gy1)),
	])


## A NAV_OBSTACLE_SHRINK-sized diamond centered on a single occupied cell -
## see that const's own doc comment for why it's shrunk rather than a full
## tile.
func _cell_obstacle_outline(cell: Vector2i) -> PackedVector2Array:
	var center := WorldGrid.grid_to_local(Vector2(cell.x, cell.y))
	var half_w := IsoUtils.TILE_WIDTH * 0.5 * NAV_OBSTACLE_SHRINK
	var half_h := IsoUtils.TILE_HEIGHT * 0.5 * NAV_OBSTACLE_SHRINK
	return PackedVector2Array([
		center + Vector2(0, -half_h),
		center + Vector2(half_w, 0),
		center + Vector2(0, half_h),
		center + Vector2(-half_w, 0),
	])


func _on_day_started(day: int) -> void:
	_tween_day_night_tint(DAY_TINT)
	hud.set_day_label(day, true)


func _on_night_started(day: int) -> void:
	_tween_day_night_tint(NIGHT_TINT)
	hud.set_day_label(day, false)


func _tween_day_night_tint(target: Color) -> void:
	var tween := create_tween()
	tween.tween_property(day_night_tint, "color", target, DAY_NIGHT_TRANSITION_SECONDS)


func _scatter_initial_trees() -> void:
	## Scattered around the Outpost Hall rather than a starting Lumber
	## Camp - there isn't a fixed one anymore, the player builds their own.
	var scatter_center := WorldGrid.local_to_grid($OutpostHall.position)
	for i in INITIAL_TREE_COUNT:
		var cell = WorldGrid.find_plantable_cell(scatter_center, INITIAL_TREE_RADIUS)
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
	target += HAPPINESS_FOOD_BONUS if GameState.get_total_food() > 0.0 else -HAPPINESS_STARVING_PENALTY
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
	characters.erase(character)
	GameState.population_count = maxi(0, GameState.population_count - 1)
	GameState.population_changed.emit(GameState.population_count, GameState.population_capacity)
	character.queue_free()
	_run_job_assignment()


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
		elif event.keycode == KEY_EQUAL or event.keycode == KEY_KP_ADD:
			get_viewport().set_input_as_handled()
			speed_index = mini(speed_index + 1, SPEED_MULTIPLIERS.size() - 1)
			_apply_speed()
			return
		elif event.keycode == KEY_MINUS or event.keycode == KEY_KP_SUBTRACT:
			get_viewport().set_input_as_handled()
			speed_index = maxi(speed_index - 1, 0)
			_apply_speed()
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
	if training_ground_panel.visible and ((event is InputEventMouseButton and event.pressed) or event.is_action_pressed("ui_cancel")):
		training_ground_panel.close()
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
		_deselect()
	elif event.is_action_pressed("ui_cancel"):
		_deselect()


## Clicking a citizen selects them and opens their (view-only) skill panel -
## job assignment is fully automatic (see _run_job_assignment), so this is
## purely informational. Clicking the same already-selected citizen again
## just deselects them, same as clicking elsewhere.
func _on_character_selected(character: Character) -> void:
	if _placing_option:
		return
	if _selected_character == character:
		_deselect()
		return
	if _selected_character:
		_selected_character.set_selected(false)
	_selected_character = character
	_selected_character.set_selected(true)
	skill_panel.open_for(character)


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
	training_ground_panel.close()
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
	training_ground_panel.close()
	system_menu.open()


## Gated by DayNightCycle.can_recruit() - the panel doesn't even open on
## cooldown (rather than opening it and rejecting a candidate pick after the
## fact), same "block the action upfront" shape _on_attack_pressed's empty-
## squad guard already uses.
func _on_outpost_hall_clicked() -> void:
	if not DayNightCycle.can_recruit():
		var days := DayNightCycle.days_until_next_recruit()
		hud.flash_message("Recruiting available in %d more day%s" % [days, "" if days == 1 else "s"])
		return
	_cancel_placement()
	build_menu.close()
	crop_panel.close()
	training_ground_panel.close()
	_recruit_source = null
	recruit_panel.open_for(RecruitCatalog.generate_candidates())


## A built combat-training building offers two independent actions -
## Recruit (its own additional recruit per day, on its own cooldown - see
## TrainingGround.can_recruit/mark_recruited's doc comments for why this is
## sound, each type capped at one via BuildingCatalog's "max_count") and
## Upgrade (raises its unit cap - see TrainingGround.get_unit_cap/
## mark_upgraded's doc comments). Neither gates the other, so unlike
## _on_outpost_hall_clicked's "block the action upfront" shape, this always
## opens training_ground_panel and lets it show Recruit as disabled (with
## the cooldown message baked into its label) rather than refusing to open
## at all - Upgrade needs to stay reachable even mid-recruit-cooldown.
func _on_training_ground_clicked(building: TrainingGround) -> void:
	_cancel_placement()
	build_menu.close()
	crop_panel.close()
	recruit_panel.close()
	_training_ground_target = building

	var options: Array[Dictionary] = []
	if building.can_recruit():
		options.append({"id": "recruit", "label": "Recruit"})
	else:
		var days := building.days_until_next_recruit()
		options.append({
			"id": "recruit",
			"label": "Recruit (ready in %d day%s)" % [days, "" if days == 1 else "s"],
			"enabled": false,
		})
	options.append({
		"id": "upgrade",
		"label": "Upgrade (%s)\nUnit cap %d -> %d" % [_format_cost(TrainingGround.UPGRADE_COST), building.get_unit_cap(), building.get_unit_cap() + TrainingGround.UNIT_CAP_PER_UPGRADE],
	})
	training_ground_panel.open_for(building.display_name, options)


## training_ground_panel's own signal handler - branches into the same
## recruit-panel-opening code _on_training_ground_clicked used to run
## directly, or the upgrade spend/grant flow (same spend-then-apply shape
## as _on_house_clicked, but repeatable - no "already upgraded" guard).
func _on_training_ground_option_chosen(option_id: String) -> void:
	if not is_instance_valid(_training_ground_target):
		return
	var building := _training_ground_target
	match option_id:
		"recruit":
			if not building.can_recruit():
				hud.flash_message("%s's recruit is ready again tomorrow" % building.display_name)
				return
			_recruit_source = building
			var skill_id := building.get_skill_id()
			var candidate := RecruitCatalog.generate_combat_candidate(skill_id, SkillTitles.JOB_NOUNS[skill_id])
			recruit_panel.open_for([candidate])
		"upgrade":
			if not GameState.can_afford(TrainingGround.UPGRADE_COST):
				hud.flash_message("Not enough brick")
				return
			GameState.spend(TrainingGround.UPGRADE_COST)
			building.mark_upgraded()
			hud.flash_message("%s upgraded (unit cap %d)" % [building.display_name, building.get_unit_cap()])
			## A higher unit cap may free up a slot right now for whoever's
			## currently hauling with nothing better to do - same reasoning
			## _on_post_disabled_changed re-runs assignment on a capacity
			## change in the other direction.
			_run_job_assignment()


## "10 Brick" - a smaller version of RecruitPanel._cost_text for a non-food
## cost (TrainingGround.UPGRADE_COST is brick, not a HUD.FOOD_BREAKDOWN_
## LABELS entry), kept separate rather than reusing that one since it lives
## on a different node and its food-label lookup doesn't apply here.
func _format_cost(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for resource_name in cost:
		parts.append("%d %s" % [int(cost[resource_name]), String(resource_name).capitalize()])
	return " + ".join(parts)


## Connects a Farm-family building's clicked signal (see Farm.gd) so
## clicking it opens the crop-selection panel - called for every
## dynamically placed/restored Farm-family building. Buildings that aren't
## Farm instances (LumberCamp, StoneMine, passive structures) don't have
## this signal at all, so this is a no-op for them.
func _wire_farm_clicks(building: Node) -> void:
	if building is Farm:
		building.clicked.connect(_on_farm_clicked.bind(building))


func _wire_house_clicks(building: Node) -> void:
	if building is House:
		building.clicked.connect(_on_house_clicked.bind(building))


func _wire_training_ground_clicks(building: Node) -> void:
	if building is TrainingGround:
		building.clicked.connect(_on_training_ground_clicked.bind(building))


## A House's `clicked` signal always means "try to upgrade" - unlike a
## Farm, a House isn't assignable, so there's no citizen-selection branch
## to check first (compare _on_farm_clicked).
func _on_house_clicked(house: House) -> void:
	if house.upgraded:
		hud.flash_message("%s is already upgraded" % house.display_name)
		return
	if not GameState.can_afford(House.UPGRADE_COST):
		hud.flash_message("Not enough stone")
		return
	GameState.spend(House.UPGRADE_COST)
	house.mark_upgraded()
	GameState.add_population_capacity(House.UPGRADE_CAPACITY_BONUS)
	hud.flash_message("%s upgraded (+%d capacity)" % [house.display_name, House.UPGRADE_CAPACITY_BONUS])


func _on_farm_clicked(farm: Farm) -> void:
	_cancel_placement()
	build_menu.close()
	recruit_panel.close()
	training_ground_panel.close()
	_crop_target = farm
	crop_panel.open_for(BuildingCatalog.farm_family_options(), farm.display_name)


## Right-click toggles any job post (Farm/LumberCamp/StoneMine/Brickmaker/
## Workshop - every Workstation subclass) disabled/re-enabled - see Workstation.disabled's
## doc comment. Left-click on a Farm-family post is already spoken for
## (opens the crop panel, see _on_farm_clicked), so this deliberately uses
## the other mouse button rather than competing with it.
func _wire_workstation_disable(building: Node) -> void:
	if building is Workstation:
		building.disabled_changed.connect(_on_post_disabled_changed.bind(building))


## A post going disabled evicts whoever's currently working it (back to
## hauling) so "temporarily disable a building to send its worker
## elsewhere" - the actual point of the feature - takes effect immediately
## rather than only the next time assignment happens to run. Either
## direction (disabling or re-enabling) then re-runs the full assignment
## pass: disabling may free up a more-qualified worker who was previously
## displaced elsewhere, and re-enabling gives the post a chance to be
## staffed again straight away rather than waiting for some other trigger.
func _on_post_disabled_changed(is_disabled: bool, post: Workstation) -> void:
	if is_disabled:
		for citizen in characters:
			if citizen.assigned_post == post:
				citizen.assign_to(null)
	_run_job_assignment()


## Every placed post that trains one of the seven job skills (see
## SkillTitles.TITLE_SKILLS - includes "construction" now, see the Building
## system consts up top) - the Outpost Hall and Storage Facilities never
## appear here (they're not in `posts` at all - see _ready's doc comment on
## the Outpost Hall), a disabled post is excluded too (its effective
## capacity is 0 - see _run_job_assignment), and a ConstructionSite only
## ever appears here once its materials phase is done and it's actually
## been added to `posts` in the first place (see
## _on_construction_materials_ready) - a site still gathering materials
## lives only in construction_sites, never here.
func _job_posts() -> Array:
	var result: Array = []
	for post in posts:
		if post is Workstation and post.get_skill_id() in SkillTitles.TITLE_SKILLS:
			result.append(post)
	return result


## Matches every citizen to whichever job post trains the skill they're
## currently best at - "Each pawn should automatically take a job matching
## whatever their highest stat is" - with no player-driven assignment at
## all anymore (see CLAUDE.md's rewritten Character/post interaction
## pattern). Recomputed from scratch on every relevant trigger (a citizen
## recruited/departed, a post built/disabled/re-enabled, a save loaded)
## rather than incrementally patched - simplest way to guarantee the result
## is always the same regardless of history, and cheap enough at this
## game's scale (a handful of citizens/posts) to just redo in full.
##
## This is citizen-proposing Gale-Shapley deferred acceptance, generalized
## to multi-worker posts: each citizen ranks the 6 job skills by their own
## level in them (SkillTitles.skill_preference_order - stable, so a
## citizen tied at level 1 in everything doesn't get stuck only ever
## proposing to their nominal #1 pick when a *different* skill's post is
## the only one with room - see that function's doc comment for the bug
## this specifically avoids), then repeatedly proposes to their best
## not-yet-rejected skill's post pool. A pool under capacity accepts
## immediately; a full pool compares the proposer against its current
## weakest occupant (by level in that specific skill) and evicts/accepts on
## a *strict* improvement only (a tie changes nothing - no thrashing
## between equally-qualified citizens). This is exactly "if a citizen has a
## job but a new citizen arrives with higher skill in that job, the
## previous job holder should swap for the better qualified citizen" -
## implicit in the eviction step, not a separate code path. Whoever
## exhausts every preference without landing a post stays unassigned,
## which Character.assign_to(null) already turns into hauling automatically
## - "a citizen who can't find a job becomes a hauler until one opens up".
##
## Finally applies the result with a diff against each citizen's *current*
## assigned_post: assign_to() is only called for citizens whose target
## actually changed, so an already-correctly-placed citizen (the common
## case on a repeat call) is left completely alone rather than having their
## work loop restarted for no reason - this is also what makes restoring a
## citizen's exact saved position (Base._restore_characters) survive the
## _run_job_assignment() call _load_game() makes right after: if the save
## was already stable under this same algorithm (the normal case), nothing
## about it changes.
func _run_job_assignment() -> void:
	var job_posts := _job_posts()
	var posts_by_skill: Dictionary = {}
	for post in job_posts:
		var skill_id: String = post.get_skill_id()
		if not posts_by_skill.has(skill_id):
			posts_by_skill[skill_id] = []
		posts_by_skill[skill_id].append(post)

	var capacity_by_skill: Dictionary = {}
	for skill_id in posts_by_skill:
		var capacity := 0
		for post in posts_by_skill[skill_id]:
			if not post.disabled:
				capacity += post.max_workers
		capacity_by_skill[skill_id] = capacity

	var preferences: Dictionary = {}
	var next_pref_index: Dictionary = {}
	for citizen in characters:
		preferences[citizen] = SkillTitles.skill_preference_order(citizen.data)
		next_pref_index[citizen] = 0

	## skill_id -> Array[Character] tentatively accepted into that skill's
	## shared pool (bounded by capacity_by_skill[skill_id]).
	var accepted: Dictionary = {}
	for skill_id in posts_by_skill:
		accepted[skill_id] = []

	var queue: Array = characters.duplicate()
	while not queue.is_empty():
		var citizen: Character = queue.pop_front()
		var prefs: Array = preferences[citizen]
		var idx: int = next_pref_index[citizen]
		if idx >= prefs.size():
			continue
		next_pref_index[citizen] = idx + 1
		var skill_id: String = prefs[idx]
		var capacity: int = capacity_by_skill.get(skill_id, 0)
		if capacity == 0:
			queue.append(citizen)
			continue
		var pool: Array = accepted[skill_id]
		if pool.size() < capacity:
			pool.append(citizen)
			continue
		var weakest: Character = pool[0]
		for candidate in pool:
			if candidate.data.get_skill_level(skill_id) < weakest.data.get_skill_level(skill_id):
				weakest = candidate
		if citizen.data.get_skill_level(skill_id) > weakest.data.get_skill_level(skill_id):
			pool.erase(weakest)
			pool.append(citizen)
			queue.append(weakest)
		else:
			queue.append(citizen)

	## Distribute each skill's accepted pool across that skill's posts (in
	## `posts` order - stable/deterministic, not meaningful beyond that) up
	## to each post's own max_workers, then diff-apply against reality.
	var target_post: Dictionary = {}
	for skill_id in accepted:
		var pool: Array = accepted[skill_id]
		var pool_index := 0
		for post in posts_by_skill[skill_id]:
			if post.disabled:
				continue
			for _i in range(post.max_workers):
				if pool_index >= pool.size():
					break
				target_post[pool[pool_index]] = post
				pool_index += 1

	for citizen in characters:
		var target: Node = target_post.get(citizen, null)
		if citizen.assigned_post != target:
			citizen.assign_to(target)


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

	## Keep _placed_buildings' record of this building's recipe in sync -
	## otherwise a retool would silently revert on the next save/load
	## round-trip, since _restore_placed_buildings rebuilds a Farm-family
	## building's fields from its saved option_id rather than reading them
	## live off the node. Every Farm-family building is a placed one now
	## (no fixed scene-file Farm to special-case anymore).
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


## _recruit_source (set by _on_outpost_hall_clicked/_on_training_ground_
## clicked just before recruit_panel opens) decides which cooldown this
## recruitment marks - the Outpost Hall's shared DayNightCycle one if null,
## or the specific TrainingGround's own independent one otherwise - see
## TrainingGround.mark_recruited's doc comment for why marking the wrong one
## would either double-dip the Outpost Hall's cooldown or let a combat
## building's recruit compete with it instead of adding to it.
func _on_candidate_selected(candidate: Dictionary) -> void:
	if GameState.population_count >= GameState.population_capacity:
		hud.flash_message("No housing available")
		return
	if not GameState.can_afford(candidate["cost"]):
		hud.flash_message("Not enough food")
		return
	GameState.spend(candidate["cost"])

	var character := _spawn_character(candidate["name"], $OutpostHall.get_stockpile_spot())
	character.data.skill_xp[candidate["skill_id"]] = candidate["starting_xp"]

	GameState.population_count += 1
	GameState.population_changed.emit(GameState.population_count, GameState.population_capacity)
	if _recruit_source:
		_recruit_source.mark_recruited()
	else:
		DayNightCycle.mark_recruited()
	hud.flash_message("%s joined the outpost" % character.data.character_name)
	## A new arrival might out-qualify whoever currently holds a matching
	## job - see _run_job_assignment's doc comment.
	_run_job_assignment()


## Instantiates a fresh Character with a fresh CharacterData (not a shared
## .tres like Aldric/Brenna/Cass - recruits are procedurally generated, not
## hand-authored) and registers it exactly like the 3 starting citizens are
## in _ready(): added as a direct child of Base (required for y-sorting -
## see CLAUDE.md), appended to `characters`, wired to `clicked`. Does NOT
## touch GameState.population_count or spend anything - callers decide
## whether that applies (a fresh recruit does both; _restore_characters
## recreating a missing citizen from a save does neither, since the saved
## population_count already accounts for them). Also deliberately doesn't
## call _run_job_assignment() itself - callers differ on timing (a fresh
## recruit needs it once, right after; _restore_characters needs every
## citizen spawned first, then one assignment pass at the very end).
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
	character.clicked.connect(_on_character_selected)
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
		and _under_max_count(_placing_option)
	)
	_ghost.modulate = VALID_TINT if _ghost_valid else INVALID_TINT


## True unless `option` has a "max_count" cap (see BuildingCatalog's combat-
## training entries) and that many already exist - counting both completed
## buildings (_placed_buildings) and still-under-construction sites
## (construction_sites), since a site that hasn't finished yet still
## represents a committed instance the player is already paying labor/
## materials toward. _confirm_placement doesn't need its own separate check -
## it already bails out unconditionally on `not _ghost_valid`, so this being
## folded into that one computation is enough.
func _under_max_count(option: Dictionary) -> bool:
	if not option.has("max_count"):
		return true
	var count := 0
	for entry in _placed_buildings:
		if entry["option_id"] == option["id"]:
			count += 1
	for site in construction_sites:
		if is_instance_valid(site) and site.target_option_id == option["id"]:
			count += 1
	return count < int(option["max_count"])


## Confirming placement no longer instantiates the real building - it starts
## a ConstructionSite instead (see the "Building system" consts up top).
## Affordability is still checked here (matching the ghost's own green/red
## tint), same as before this feature existed, but resources aren't spent
## yet - see _spawn_construction_site/Character._deliver_construction_material,
## which drain the stockpile gradually as each material actually arrives.
func _confirm_placement() -> void:
	if not _ghost_valid:
		return
	var option := _placing_option
	var size: Vector2i = option["grid_size"]
	var origin := _ghost_origin

	_reserve_cells(origin, size)

	var save_id := "placed_%d" % _next_placed_id
	_next_placed_id += 1
	_spawn_construction_site(option, origin, save_id, (option["cost"] as Dictionary).duplicate())

	_cancel_placement()


## Creates a ConstructionSite for `option` at `origin` and registers it in
## construction_sites - shared by a fresh placement (called with the
## option's full cost, zero labor_completed) and _restore_construction_sites
## (an in-progress save entry, passing whatever was actually left of each -
## `materials_needed` must be passed explicitly rather than defaulting to
## "the full cost" here, since an empty dict is itself a meaningful saved
## state - every material already delivered, nothing left to haul). A site
## with no materials needed at all is immediately added to `posts` too, same
## as _on_construction_materials_ready would do the moment that happens live.
func _spawn_construction_site(option: Dictionary, origin: Vector2i, save_id: String, materials_needed: Dictionary, labor_completed: float = 0.0) -> ConstructionSite:
	var size: Vector2i = option["grid_size"]
	var site: ConstructionSite = CONSTRUCTION_SITE_SCENE.instantiate()
	site.display_name = option["display_name"]
	site.target_option_id = option["id"]
	site.materials_needed = materials_needed.duplicate()
	site.labor_required = _labor_required_for(option)
	site.labor_completed = labor_completed
	site.position = WorldGrid.grid_to_local(_footprint_anchor(origin, size))
	site.set_meta("save_id", save_id)
	site.set_meta("origin", origin)
	add_child(site)
	_wire_workstation_disable(site)
	site.materials_ready.connect(_on_construction_materials_ready.bind(site))
	site.construction_complete.connect(_on_construction_complete.bind(site))
	site.refresh_label()

	construction_sites.append(site)
	if site.materials_are_ready():
		posts.append(site)

	return site


func _labor_required_for(option: Dictionary) -> float:
	var total := 0.0
	for resource_name in option.get("cost", {}):
		total += option["cost"][resource_name]
	return maxf(total * LABOR_PER_MATERIAL_UNIT, MIN_LABOR_REQUIRED)


## Every material has arrived - see ConstructionSite.materials_ready's doc
## comment. Adds the site to `posts` for the first time (if a save/load
## round-trip hasn't already done so - see _restore_construction_sites) so
## it becomes eligible for automatic job assignment, same as any other job
## post, then re-runs assignment so a construction-skilled worker (or
## whoever's currently unassigned) can pick it up right away rather than
## waiting for some other trigger.
func _on_construction_materials_ready(site: ConstructionSite) -> void:
	if not posts.has(site):
		posts.append(site)
	site.refresh_label()
	_run_job_assignment()


## labor_completed reached labor_required - see ConstructionSite.
## construction_complete's doc comment. Evicts whoever was working the site
## (their assigned_post is about to point at a freed node otherwise), swaps
## the site for the real building via _materialize_building (identical to
## what _confirm_placement used to do the instant a building was placed),
## then re-runs job assignment - a freshly finished job post (or the
## just-freed builder themselves) might be eligible for it immediately.
func _on_construction_complete(site: ConstructionSite) -> void:
	var option := BuildingCatalog.get_option(site.target_option_id)
	var origin: Vector2i = site.get_meta("origin")
	var save_id: String = site.get_meta("save_id")

	for citizen in characters:
		if citizen.assigned_post == site:
			citizen.assign_to(null)

	posts.erase(site)
	construction_sites.erase(site)
	site.queue_free()

	var building := _materialize_building(option, origin, save_id)
	hud.flash_message("%s construction complete" % building.display_name)
	_run_job_assignment()


## Instantiates the real building for `option` at `origin`, wires it up, and
## grants whatever it provides (capacity/stockpile/job-post registration) -
## the exact set of steps _confirm_placement used to do the instant a
## building was placed, before construction sites existed. The only caller
## now is _on_construction_complete - a save/load round-trip rebuilds an
## already-finished building via _restore_placed_buildings instead, which
## deliberately never re-grants capacity (see its own doc comment on why),
## so this helper isn't reused there.
func _materialize_building(option: Dictionary, origin: Vector2i, save_id: String) -> Node2D:
	var building: Node2D = option["scene"].instantiate()
	_apply_option_properties(building, option)
	building.position = WorldGrid.grid_to_local(_footprint_anchor(origin, option["grid_size"]))
	building.set_meta("save_id", save_id)
	add_child(building)
	_wire_farm_clicks(building)
	_wire_house_clicks(building)
	_wire_training_ground_clicks(building)
	_wire_workstation_disable(building)

	if option.has("population_capacity"):
		GameState.add_population_capacity(option["population_capacity"])
	if option.has("water_wells"):
		GameState.add_water_well(option["water_wells"])
	if option.has("storage_capacity"):
		GameState.add_storage_capacity(option["storage_capacity"])
	if building.has_method("add_worker"):
		posts.append(building)
	if building.has_method("get_stockpile_spot"):
		WorldGrid.register_stockpile(building.get_stockpile_spot())

	_placed_buildings.append({"save_id": save_id, "option_id": option["id"], "origin": origin, "node": building})
	return building


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


## HUD's "Simulate Attack" button - the current stand-in for the roadmap's
## eventual raid/siege trigger (Docs/roadmap.md's Long-Term Design Vision),
## since there's no wandering-raider AI yet. Every citizen currently
## assigned to a TrainingGround (Barracks/Archery Range/Mage Tower) deploys
## as their own squad against a generated enemy roster in CombatTest.tscn -
## see BattleState's doc comment for the full handoff shape, and
## MELEE_ARCHETYPES for why a "melee_combat"-trained citizen's concrete unit
## type is a round-robin guess rather than a real stat lookup. A citizen NOT
## currently assigned to a TrainingGround never deploys, same as any other
## job - "soldier" is just whatever a citizen's current post happens to be,
## consistent with how every other job skill already works (see Combat
## Units.md's "whether they keep their town job meanwhile" question - they
## do, this reads assignment directly rather than unassigning first).
func _on_attack_pressed() -> void:
	var squad := characters.filter(func(c: Character) -> bool: return c.assigned_post is TrainingGround)
	if squad.is_empty():
		hud.flash_message("No soldiers stationed to defend!")
		return

	var pending: Array = []
	var melee_index := 0
	for citizen in squad:
		var post: TrainingGround = citizen.assigned_post
		var unit_type: CombatUnit.UnitType
		if post.skill_id == "archery":
			unit_type = CombatUnit.UnitType.ARCHER
		elif post.skill_id == "spellcasting":
			unit_type = CombatUnit.UnitType.MAGE
		else:
			unit_type = MELEE_ARCHETYPES[melee_index % MELEE_ARCHETYPES.size()]
			melee_index += 1
		pending.append({
			"citizen_id": citizen.data.id,
			"unit_type": unit_type,
			"skill_level": citizen.data.get_skill_level(post.skill_id),
		})

	BattleState.pending_squad = pending
	## In-memory only - see _serialize_state's doc comment for why this
	## deliberately doesn't go through SaveManager/a disk slot.
	BattleState.town_blob = _serialize_state()
	BattleState.active = true
	get_tree().change_scene_to_file(COMBAT_TEST_SCENE)


## Called once from _ready(), right after _apply_state() restores
## BattleState.town_blob on the scene reload CombatTestManager triggers when
## a deployment battle ends - see that call site's doc comment. Removes any
## citizen CombatTestManager reported as dead (BattleState.result's doc
## comment) via the exact same cleanup a happiness-driven departure already
## uses (_character_leaves) - a battle death isn't mechanically different
## from any other permanent citizen loss, and this is the documented (if
## previously unbuilt) intent per Docs/roadmap.md's "Perma-death for
## citizens" long-term item. Silently skips a casualty_id with no living
## match (shouldn't happen - town_blob was captured from this exact roster
## moments before deployment - but a missing citizen isn't a reason to
## surface an error on a load).
func _apply_battle_result(result: Dictionary) -> void:
	if result.is_empty():
		return

	var casualty_ids: Array = result.get("casualty_ids", [])
	for casualty_id in casualty_ids:
		var match_list := characters.filter(func(c: Character) -> bool: return c.data.id == casualty_id)
		if not match_list.is_empty():
			_character_leaves(match_list[0])

	var outcome_text: String = {"win": "Victory", "lose": "Defeat", "draw": "Draw"}.get(result.get("outcome", "draw"), "Battle over")
	var loss_text := " - no losses" if casualty_ids.is_empty() else " - %d soldier%s lost" % [casualty_ids.size(), "" if casualty_ids.size() == 1 else "s"]
	hud.flash_message(outcome_text + loss_text)


func _save_game() -> void:
	SaveManager.save_game(SaveManager.active_slot, _serialize_state())
	hud.flash_message("Saved")


## The in-memory half of _save_game - split out so battle deployment
## (_on_attack_pressed) can capture the exact same Dictionary a real save
## would produce and stash it on BattleState.town_blob without touching
## SaveManager.active_slot or disk at all. Deploying used to be tempting to
## implement as "just call _save_game() to the active slot" - don't: that
## slot may be the player's real save (active_slot defaults to 1 even for a
## fresh New Game that was never manually saved), so a battle would silently
## clobber it. Keeping the capture in memory means losslessness is "does
## _apply_state round-trip this Dictionary," which is fully in this file's
## control, not "does the whole on-disk format happen to capture everything
## a mid-battle round trip needs."
func _serialize_state() -> Dictionary:
	return {
		"version": 1,
		"saved_at": int(Time.get_unix_time_from_system()),
		"resources": GameState.resources.duplicate(),
		"population_count": GameState.population_count,
		"population_capacity": GameState.population_capacity,
		"water_wells": GameState.water_wells,
		"storage_capacity": GameState.storage_capacity,
		"trees": _serialize_trees(),
		"placed_buildings": _serialize_placed_buildings(),
		"construction_sites": _serialize_construction_sites(),
		"post_buffers": _serialize_post_buffers(),
		"characters": _serialize_characters(),
		"day_number": DayNightCycle.day_number,
		"is_day": DayNightCycle.is_day,
		"phase_elapsed": DayNightCycle.phase_elapsed,
		"last_recruit_day": DayNightCycle.last_recruit_day,
	}


func _load_game() -> void:
	var data := SaveManager.load_game(SaveManager.active_slot)
	if data.is_empty():
		hud.flash_message("No save found")
		return
	_apply_state(data)
	hud.flash_message("Loaded")


## The in-memory half of _load_game - split out so the battle-return flow
## (_on_battle_finished, called once CombatTestManager hands control back)
## can restore BattleState.town_blob the same way a real load restores a
## disk save, without going through SaveManager/a slot at all. See
## _serialize_state's doc comment for why this pairing avoids disk/slot
## entirely rather than reusing SaveManager.save_game/load_game.
func _apply_state(data: Dictionary) -> void:
	_cancel_placement()
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

	## Restores the clock to the exact moment it was saved at, rather than
	## letting a fresh reset_to_defaults() (already called unconditionally in
	## _ready() - see that call site) stand: a load should resume exactly
	## where the player left off, same as every other piece of state here.
	DayNightCycle.day_number = int(data.get("day_number", DayNightCycle.day_number))
	DayNightCycle.is_day = bool(data.get("is_day", DayNightCycle.is_day))
	DayNightCycle.phase_elapsed = float(data.get("phase_elapsed", DayNightCycle.phase_elapsed))
	DayNightCycle.last_recruit_day = int(data.get("last_recruit_day", DayNightCycle.last_recruit_day))

	## Buildings are restored before trees: WorldGrid.plant_tree() doesn't
	## check cell occupancy, and a stale placed building torn down after
	## trees are replanted could release a cell a just-restored tree also
	## claimed, leaving WorldGrid.is_free() wrong about that cell forever.
	_restore_placed_buildings(data.get("placed_buildings", []))
	_restore_construction_sites(data.get("construction_sites", []))
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

	## Normalizes assignments against the current automatic system - a no-op
	## diff in the common case (the save was itself produced under this same
	## system), but self-heals an older save's stale/now-invalid assignment
	## (e.g. a citizen saved as an explicit Outpost Hall hauler, back when
	## that was a manual option - see _post_by_save_id's doc comment).
	_run_job_assignment()


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
		var out_entry := {"save_id": entry["save_id"], "option_id": entry["option_id"], "origin": [origin.x, origin.y]}
		if entry["node"] is House and entry["node"].upgraded:
			out_entry["upgraded"] = true
		if entry["node"] is TrainingGround and entry["node"].last_recruit_day > 0:
			out_entry["last_recruit_day"] = entry["node"].last_recruit_day
		if entry["node"] is TrainingGround and entry["node"].upgrade_level > 0:
			out_entry["upgrade_level"] = entry["node"].upgrade_level
		if entry["node"] is Workstation and entry["node"].disabled:
			out_entry["disabled"] = true
		out.append(out_entry)
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
			if node.has_method("get_stockpile_spot"):
				WorldGrid.unregister_stockpile(node.get_stockpile_spot())
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
		_wire_house_clicks(building)
		_wire_training_ground_clicks(building)
		_wire_workstation_disable(building)
		if building is House and entry.get("upgraded", false):
			building.mark_upgraded()
		if building is TrainingGround and entry.has("last_recruit_day"):
			building.last_recruit_day = int(entry["last_recruit_day"])
		if building is TrainingGround and entry.has("upgrade_level"):
			building.restore_upgrade_level(int(entry["upgrade_level"]))
		if building is Workstation and entry.get("disabled", false):
			building.disabled = true
		if building.has_method("add_worker"):
			posts.append(building)
		if building.has_method("get_stockpile_spot"):
			WorldGrid.register_stockpile(building.get_stockpile_spot())

		_placed_buildings.append({"save_id": save_id, "option_id": entry["option_id"], "origin": origin, "node": building})

		if save_id.begins_with("placed_"):
			_next_placed_id = maxi(_next_placed_id, int(save_id.trim_prefix("placed_")) + 1)


func _serialize_construction_sites() -> Array:
	var out := []
	for site in construction_sites:
		if not is_instance_valid(site):
			continue
		var origin: Vector2i = site.get_meta("origin")
		out.append({
			"save_id": site.get_meta("save_id"),
			"option_id": site.target_option_id,
			"origin": [origin.x, origin.y],
			"materials_needed": site.materials_needed.duplicate(),
			"labor_completed": site.labor_completed,
		})
	return out


## Wipes every in-progress ConstructionSite and rebuilds from saved entries -
## the same "clear and rebuild from scratch" pattern _restore_placed_buildings
## uses for finished buildings, run right after it (before trees, for the
## same cell-occupancy-ordering reason - see _load_game). A site whose
## materials were already fully delivered before the save (materials_needed
## saved as {}) goes straight back into `posts` too (see
## _spawn_construction_site), so a citizen already mid-labor on it resumes
## from labor_completed rather than the site reverting to the materials
## phase. Shares _next_placed_id's counter/prefix with _restore_placed_
## buildings (construction sites and finished buildings are two states of
## the same save_id, not two separate id spaces), so this must run after
## that function's own reset-to-0 - see the call order in _load_game.
func _restore_construction_sites(entries: Array) -> void:
	for site in construction_sites.duplicate():
		if is_instance_valid(site):
			posts.erase(site)
			var option := BuildingCatalog.get_option(site.target_option_id)
			if option.has("grid_size"):
				_release_cells(site.get_meta("origin"), option["grid_size"])
			site.queue_free()
	construction_sites.clear()

	for entry in entries:
		var option := BuildingCatalog.get_option(entry["option_id"])
		if option.is_empty():
			continue
		var origin_arr: Array = entry["origin"]
		var origin := Vector2i(int(origin_arr[0]), int(origin_arr[1]))
		_reserve_cells(origin, option["grid_size"])

		var save_id: String = entry["save_id"]
		_spawn_construction_site(option, origin, save_id, entry.get("materials_needed", {}), entry.get("labor_completed", 0.0))

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
			"position": [character.position.x, character.position.y],
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
		## grant_move_xp=false: this call's own _move_to (toward the
		## post/home position) is about to be overridden by
		## snap_to_position() below (or just left as-is for an older save
		## with no "position" field) - either way this placement isn't a
		## real move the citizen made, so it shouldn't earn speed xp (see
		## _move_to's doc comment). Without this, every load would hand
		## every restored citizen a free chunk of speed xp.
		character.assign_to(_post_by_save_id(entry.get("assigned_save_id", "")), false)
		## Overrides assign_to's own placement with wherever this citizen
		## actually was when saved - older saves without "position" just
		## keep assign_to's post/home placement, same as before this field
		## existed.
		if entry.has("position"):
			var pos_arr: Array = entry["position"]
			character.snap_to_position(Vector2(pos_arr[0], pos_arr[1]))
		matched_ids[character.data.id] = true

	## Any live citizen not accounted for above didn't exist at the point
	## this save was made - remove them so loading actually reverts state
	## rather than only ever adding citizens back.
	for character in characters.duplicate():
		if not matched_ids.has(character.data.id):
			character.leave()
			characters.erase(character)
			character.queue_free()


## "farm"/"woodpile" (the old fixed starting Cabbage Farm/Lumber Camp) and
## "outpost_hall" (the old explicit-hauler-assignment target, before job
## assignment became fully automatic) are none of them valid job posts
## anymore - an old save referencing a citizen assigned to any of them just
## falls through to null (unassigned/hauling) rather than crashing on a
## node that either doesn't exist, or (Outpost Hall) simply isn't a post.
func _post_by_save_id(save_id: String) -> Node:
	if save_id.is_empty():
		return null
	for entry in _placed_buildings:
		if entry["save_id"] == save_id:
			return entry["node"]
	## A citizen mid-labor on a construction site when the game was saved -
	## the site itself isn't in _placed_buildings yet (see construction_sites'
	## doc comment), so it needs its own lookup here too.
	for site in construction_sites:
		if is_instance_valid(site) and site.has_meta("save_id") and site.get_meta("save_id") == save_id:
			return site
	return null
