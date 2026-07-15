extends Node2D
class_name CombatTestManager

## Standalone combat sandbox (scenes/combat/CombatTest.tscn) - run it
## directly (F6 in the editor) to watch two teams fight per Ideas/Combat
## System.md's "classic RTS combat minus direct player control" pillar.
## Not reachable from the main game yet; see CombatUnit's own doc comment
## for how this is meant to fold into the real job-assignment system later.
## Each side now runs its own StrategistAI (scripts/combat/strategist_ai.gd),
## which can switch its team's Formation preset mid-battle to counter
## whatever the enemy's composition actually is - see MATCHUPS below for
## asymmetric test rosters that exercise this, and press M to cycle them.

const CombatUnitScene := preload("res://scenes/combat/CombatUnit.tscn")
const MAIN_MENU_SCENE := "res://scenes/menu/MainMenu.tscn"

## Named test matchups: two rosters at roughly the same total
## CombatUnit.point_cost but a different unit mix, so a "fair" fight still
## calls for genuinely different strategies on each side - the whole point
## of testing the strategist AI. Costs are approximate (first-pass
## heuristic, not tuned):
## - balanced: 6700 vs 6700 (a mirror match, the original fixed roster -
##   control case, both sides should converge on "line").
## - melee_vs_ranged: 6620 (1 Sword/5 Archer/1 Mage) vs 6693 (4 Sword/1
##   Archer) - archer-heavy vs. swordsman-heavy, should pull each side
##   toward "rush"/"skirmish" respectively.
## - mage_heavy: 6480 (1 Sword/1 Archer/8 Mage) vs 6700 (balanced) - should
##   pull the balanced side toward "guard".
## - fast_movers: 5867 (4 Outrider/2 Archer) vs 6153 (4 Trapper/2 Swordsman) -
##   exercises Outrider actually running down Archers and Trapper's slow
##   debuff negating that. NOT the intended Trapper matchup - see
##   support_vs_outrider below.
## - support_vs_outrider: 6188 (3 Trapper/4 Archer) vs 6000 (6 Outrider) - the
##   actual intended pairing: Trapper slows, Archer finishes. This is the
##   one that needs to win, not fast_movers.
const MATCHUPS := [
	{
		"id": "balanced",
		"display_name": "Balanced (mirror)",
		"roster_a": [
			CombatUnit.UnitType.SWORDSMAN, CombatUnit.UnitType.SWORDSMAN, CombatUnit.UnitType.SWORDSMAN,
			CombatUnit.UnitType.ARCHER, CombatUnit.UnitType.ARCHER, CombatUnit.UnitType.MAGE,
		],
		"roster_b": [
			CombatUnit.UnitType.SWORDSMAN, CombatUnit.UnitType.SWORDSMAN, CombatUnit.UnitType.SWORDSMAN,
			CombatUnit.UnitType.ARCHER, CombatUnit.UnitType.ARCHER, CombatUnit.UnitType.MAGE,
		],
	},
	{
		"id": "melee_vs_ranged",
		"display_name": "Melee vs Ranged",
		"roster_a": [
			CombatUnit.UnitType.SWORDSMAN,
			CombatUnit.UnitType.ARCHER, CombatUnit.UnitType.ARCHER, CombatUnit.UnitType.ARCHER,
			CombatUnit.UnitType.ARCHER, CombatUnit.UnitType.ARCHER,
			CombatUnit.UnitType.MAGE,
		],
		"roster_b": [
			CombatUnit.UnitType.SWORDSMAN, CombatUnit.UnitType.SWORDSMAN,
			CombatUnit.UnitType.SWORDSMAN, CombatUnit.UnitType.SWORDSMAN,
			CombatUnit.UnitType.ARCHER,
		],
	},
	{
		"id": "mage_heavy",
		"display_name": "Mage Swarm vs Balanced",
		"roster_a": [
			CombatUnit.UnitType.SWORDSMAN, CombatUnit.UnitType.ARCHER,
			CombatUnit.UnitType.MAGE, CombatUnit.UnitType.MAGE, CombatUnit.UnitType.MAGE, CombatUnit.UnitType.MAGE,
			CombatUnit.UnitType.MAGE, CombatUnit.UnitType.MAGE, CombatUnit.UnitType.MAGE, CombatUnit.UnitType.MAGE,
		],
		"roster_b": [
			CombatUnit.UnitType.SWORDSMAN, CombatUnit.UnitType.SWORDSMAN, CombatUnit.UnitType.SWORDSMAN,
			CombatUnit.UnitType.ARCHER, CombatUnit.UnitType.ARCHER, CombatUnit.UnitType.MAGE,
		],
	},
	# fast_movers: 5867 (4 Outrider/2 Archer) vs 6153 (4 Trapper/2 Swordsman) -
	# exercises the newest pair directly: can Outrider actually run down
	# Archers before something stops it, and does getting slowed by a
	# Trapper negate that in practice.
	{
		"id": "fast_movers",
		"display_name": "Outriders vs Trappers",
		"roster_a": [
			CombatUnit.UnitType.OUTRIDER, CombatUnit.UnitType.OUTRIDER,
			CombatUnit.UnitType.OUTRIDER, CombatUnit.UnitType.OUTRIDER,
			CombatUnit.UnitType.ARCHER, CombatUnit.UnitType.ARCHER,
		],
		"roster_b": [
			CombatUnit.UnitType.TRAPPER, CombatUnit.UnitType.TRAPPER,
			CombatUnit.UnitType.TRAPPER, CombatUnit.UnitType.TRAPPER,
			CombatUnit.UnitType.SWORDSMAN, CombatUnit.UnitType.SWORDSMAN,
		],
	},
	# support_vs_outrider: 6188 (3 Trapper/4 Archer) vs 6000 (6 Outrider) - the
	# actual intended matchup per an explicit design clarification: Trapper
	# isn't meant to solo-duel Outriders, it's a support unit that slows them
	# down so Archers (which pack enough punch to kill Outriders quickly) can
	# finish them off. This is the pairing that actually needs to win, not
	# fast_movers above.
	{
		"id": "support_vs_outrider",
		"display_name": "Trapper+Archer Support vs Pure Outrider",
		"roster_a": [
			CombatUnit.UnitType.TRAPPER, CombatUnit.UnitType.TRAPPER, CombatUnit.UnitType.TRAPPER,
			CombatUnit.UnitType.ARCHER, CombatUnit.UnitType.ARCHER,
			CombatUnit.UnitType.ARCHER, CombatUnit.UnitType.ARCHER,
		],
		"roster_b": [
			CombatUnit.UnitType.OUTRIDER, CombatUnit.UnitType.OUTRIDER, CombatUnit.UnitType.OUTRIDER,
			CombatUnit.UnitType.OUTRIDER, CombatUnit.UnitType.OUTRIDER, CombatUnit.UnitType.OUTRIDER,
		],
	},
]

## Which Formation preset each team starts in before its StrategistAI has
## had a chance to react - see FormationCatalog.
const STARTING_FORMATION_ID := "line"

## Covers the IsoGround footprint (20x16 tiles, start (-10,-8), see the
## scene file) with margin for maneuvering past the visible tiles - open
## field, no obstacles, so a single rectangle outline is the whole navmesh.
const NAV_BOUNDS := Rect2(-1200.0, -700.0, 2400.0, 1400.0)

@onready var camera: RtsCamera = $RtsCamera
@onready var nav_region: NavigationRegion2D = $NavigationRegion2D
@onready var result_label: Label = $UI/ResultLabel
@onready var strategy_label: Label = $UI/StrategyLabel
@onready var matchup_label: Label = $UI/MatchupLabel

var team_a: Array = []
var team_b: Array = []
var formation_a: Formation
var formation_b: Formation
var strategist_a: StrategistAI
var strategist_b: StrategistAI
var matchup_index := 0


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


func _process(delta: float) -> void:
	if is_instance_valid(strategist_a):
		strategist_a.update(delta)
	if is_instance_valid(strategist_b):
		strategist_b.update(delta)
	if is_instance_valid(formation_a) and is_instance_valid(formation_b):
		strategy_label.text = "Team A: %s   |   Team B: %s" % [formation_a.preset_id.capitalize(), formation_b.preset_id.capitalize()]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			_restart()
		elif event.keycode == KEY_M:
			matchup_index = (matchup_index + 1) % MATCHUPS.size()
			_restart()
	elif event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _spawn_battle() -> void:
	result_label.text = ""
	var matchup: Dictionary = MATCHUPS[matchup_index]
	matchup_label.text = "Matchup: %s (M to cycle)" % matchup["display_name"]
	var starting_preset := FormationCatalog.get_option(STARTING_FORMATION_ID)
	var bounds := NAV_BOUNDS.grow(-CombatUnit.UNIT_RADIUS)

	# facing is which way is "toward the enemy" for each formation - team A
	# sits on the negative-x side facing +x, team B mirrors it. Both start
	# co-located at the world origin (Formation itself moves from there -
	# see Formation._process).
	formation_a = Formation.new()
	add_child(formation_a)
	formation_a.setup(starting_preset, -1.0, bounds)
	formation_b = Formation.new()
	add_child(formation_b)
	formation_b.setup(starting_preset, 1.0, bounds)

	team_a = _spawn_team(CombatUnit.Team.A, formation_a, matchup["roster_a"])
	team_b = _spawn_team(CombatUnit.Team.B, formation_b, matchup["roster_b"])
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

	strategist_a = StrategistAI.new(formation_a, team_b)
	strategist_b = StrategistAI.new(formation_b, team_a)


func _spawn_team(team: CombatUnit.Team, formation: Formation, roster: Array) -> Array:
	var units: Array = []
	var offsets := formation.assign_slots(roster)
	for i in roster.size():
		var unit: CombatUnit = CombatUnitScene.instantiate()
		add_child(unit)
		unit.global_position = formation.global_position + offsets[i]
		unit.setup(roster[i], team, [], formation.play_bounds, formation, offsets[i])
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
