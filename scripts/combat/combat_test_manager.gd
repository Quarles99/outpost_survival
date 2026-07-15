extends Node2D
class_name CombatTestManager

## Standalone combat sandbox (scenes/combat/CombatTest.tscn) - run it
## directly (F6 in the editor) to watch two teams fight per Ideas/Combat
## System.md's "classic RTS combat minus direct player control" pillar.
## Not reachable from the main game yet; see CombatUnit's own doc comment
## for how this is meant to fold into the real job-assignment system later.

const CombatUnitScene := preload("res://scenes/combat/CombatUnit.tscn")
const MAIN_MENU_SCENE := "res://scenes/menu/MainMenu.tscn"

## First-pass team composition, not tuned via playtesting - just enough of
## each type to see all three targeting priorities and the melee/kiting
## interaction play out.
const ROSTER: Array[CombatUnit.UnitType] = [
	CombatUnit.UnitType.SWORDSMAN, CombatUnit.UnitType.SWORDSMAN, CombatUnit.UnitType.SWORDSMAN,
	CombatUnit.UnitType.ARCHER, CombatUnit.UnitType.ARCHER,
	CombatUnit.UnitType.MAGE,
]

## Which Formation preset each team fights in - see FormationCatalog. Both
## sides always use the same one for now; player-facing formation choice is
## a deferred idea, see Outpost_Survival/Ideas/Formation Strategy AI.md.
const FORMATION_ID := "line"

## Covers the IsoGround footprint (20x16 tiles, start (-10,-8), see the
## scene file) with margin for maneuvering past the visible tiles - open
## field, no obstacles, so a single rectangle outline is the whole navmesh.
const NAV_BOUNDS := Rect2(-1200.0, -700.0, 2400.0, 1400.0)

@onready var camera: RtsCamera = $RtsCamera
@onready var nav_region: NavigationRegion2D = $NavigationRegion2D
@onready var result_label: Label = $UI/ResultLabel

var team_a: Array = []
var team_b: Array = []
var formation_a: Formation
var formation_b: Formation


func _ready() -> void:
	camera.position = Vector2.ZERO
	_setup_navigation()
	_spawn_battle()


## Baked in code rather than authored/baked in the editor so the navmesh
## can't silently drift out of sync with NAV_BOUNDS/IsoGround's own size.
## NavigationServer2D.bake_from_source_geometry_data() (not the simpler but
## deprecated NavigationPolygon.make_polygons_from_outlines()) is the
## current non-deprecated way to bake a polygon with no parsed scene
## geometry - there's nothing to parse here since the field has no
## obstacles, the outline alone is the whole navmesh.
func _setup_navigation() -> void:
	var nav_poly := NavigationPolygon.new()
	var b := NAV_BOUNDS
	nav_poly.add_outline(PackedVector2Array([
		b.position, Vector2(b.end.x, b.position.y), b.end, Vector2(b.position.x, b.end.y),
	]))
	NavigationServer2D.bake_from_source_geometry_data(nav_poly, NavigationMeshSourceGeometryData2D.new())
	nav_region.navigation_polygon = nav_poly


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		_restart()
	elif event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _spawn_battle() -> void:
	result_label.text = ""
	var preset := FormationCatalog.get_option(FORMATION_ID)
	var bounds := NAV_BOUNDS.grow(-CombatUnit.UNIT_RADIUS)

	# facing is which way is "toward the enemy" for each formation - team A
	# sits on the negative-x side facing +x, team B mirrors it. Both start
	# co-located at the world origin (Formation itself moves from there -
	# see Formation._process).
	formation_a = Formation.new()
	add_child(formation_a)
	formation_a.setup(preset, -1.0, bounds)
	formation_b = Formation.new()
	add_child(formation_b)
	formation_b.setup(preset, 1.0, bounds)

	team_a = _spawn_team(CombatUnit.Team.A, formation_a)
	team_b = _spawn_team(CombatUnit.Team.B, formation_b)
	# Only after _spawn_team returns a finished roster - it returns a new
	# Array rather than mutating one in place, so assigning living_units any
	# earlier would leave each formation watching a stale, permanently-empty
	# array (frozen anchor, no runtime error to notice it by).
	formation_a.living_units = team_a
	formation_b.living_units = team_b

	for unit in team_a:
		(unit as CombatUnit).enemies = team_b
		(unit as CombatUnit).died.connect(_on_unit_died)
	for unit in team_b:
		(unit as CombatUnit).enemies = team_a
		(unit as CombatUnit).died.connect(_on_unit_died)


func _spawn_team(team: CombatUnit.Team, formation: Formation) -> Array:
	var units: Array = []
	var offsets := formation.assign_slots(ROSTER)
	for i in ROSTER.size():
		var unit: CombatUnit = CombatUnitScene.instantiate()
		add_child(unit)
		unit.global_position = formation.global_position + offsets[i]
		unit.setup(ROSTER[i], team, [], formation.play_bounds, formation, offsets[i])
		units.append(unit)
	return units


func _on_unit_died(unit: CombatUnit) -> void:
	team_a.erase(unit)
	team_b.erase(unit)
	var a_alive := not team_a.is_empty()
	var b_alive := not team_b.is_empty()
	if a_alive and b_alive:
		return
	if a_alive:
		result_label.text = "Team A wins! Press R to restart."
	elif b_alive:
		result_label.text = "Team B wins! Press R to restart."
	else:
		result_label.text = "Draw! Press R to restart."


func _restart() -> void:
	for unit in team_a + team_b:
		if is_instance_valid(unit):
			unit.queue_free()
	# Without this, every restart leaks an orphaned Formation still ticking
	# _process() against a cleared-but-not-freed living_units array.
	if is_instance_valid(formation_a):
		formation_a.queue_free()
	if is_instance_valid(formation_b):
		formation_b.queue_free()
	team_a.clear()
	team_b.clear()
	await get_tree().process_frame
	_spawn_battle()
