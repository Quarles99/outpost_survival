extends Node2D
class_name CombatTestManager

## Standalone combat sandbox (scenes/combat/CombatTest.tscn) - run it
## directly (F6 in the editor) to watch two teams fight per Ideas/Combat
## System.md's "classic RTS combat minus direct player control" pillar.
## Each side now runs its own StrategistAI (scripts/combat/strategist_ai.gd),
## which can switch its team's Formation preset mid-battle to counter
## whatever the enemy's composition actually is - see MATCHUPS below for
## asymmetric test rosters that exercise this, and press M to cycle them.
##
## Also doubles as the real town-defense battle scene now: if BattleState.
## active is true, Base._on_attack_pressed sent us here with a real citizen
## squad in BattleState.pending_squad instead of a MATCHUPS entry - see
## _spawn_battle's branch. Everything else (Formation/StrategistAI/terrain
## generation/speed control) is fully shared between the two modes; the only
## real differences are where roster_a comes from, M-cycling being disabled
## (a deployed squad's composition isn't something to swap mid-battle), and
## Esc returning to Base with a casualty report instead of the main menu.
const CombatUnitScene := preload("res://scenes/combat/CombatUnit.tscn")
const MAIN_MENU_SCENE := "res://scenes/menu/MainMenu.tscn"
const BASE_SCENE := "res://scenes/base/Base.tscn"

## Named test matchups: two rosters at roughly the same total
## CombatUnit.point_cost but a different unit mix, so a "fair" fight still
## calls for genuinely different strategies on each side - the whole point
## of testing the strategist AI. Costs are approximate (a heuristic, not
## tuned via playtesting) and use the second-pass point_cost formula (see
## its own doc comment in combat_unit.gd) - reworked after
## archer_core_vs_melee_rush verified as a 10/10 rout despite "point-cost
## parity" under the original health*dps-only formula; see
## Outpost_Survival/Ideas/Combat Units.md's "Point-cost formula rework"
## section for the full diagnosis. Costs below are current as of that
## rework:
## - balanced: 6352 vs 6352 (a mirror match, 2 Shieldbearer/1 Marauder/2
##   Archer/1 Mage each side - control case, both sides should converge on
##   "line").
## - melee_vs_ranged: 6105 (1 Shieldbearer/5 Archer/1 Mage) vs 5920 (3
##   Shieldbearer/1 Marauder/1 Archer) - archer-heavy vs. melee-heavy,
##   should pull each side toward "rush"/"skirmish" respectively.
## - mage_heavy: 5074 (1 Shieldbearer/1 Archer/8 Mage) vs 5953 (2
##   Shieldbearer/1 Marauder/2 Archer, +17% over roster_a) - should pull the
##   balanced side toward "guard". The new formula prices a Mage-swarm
##   roster noticeably cheaper than before (Mage's low speed/weak average
##   defense/high focus-fire exposure all discount it) - not yet
##   rebalanced to new-formula parity, since this matchup wasn't the one
##   flagged as broken; worth revisiting if it turns out equally lopsided.
## - fast_movers: 5619 (4 Outrider/2 Archer) vs 4169 (4 Trapper/2
##   Shieldbearer, -26% under roster_a) - exercises Outrider actually
##   running down Archers and Trapper's slow debuff negating that. NOT the
##   intended Trapper matchup - see support_vs_outrider below. Trapper's
##   cost dropped the most of any type under the new formula (below-average
##   speed, no matchup edge in DAMAGE_MULTIPLIERS) - its real value is the
##   slow debuff, an ability point_cost still can't represent (see that
##   function's "known, deliberately-unfixed gap" note), so this pairing
##   being far from cost parity doesn't necessarily mean it's far from
##   competitive; not rebalanced since, as before, it isn't the pairing
##   meant to prove anything.
## - support_vs_outrider: 5567 (3 Trapper/4 Archer) vs 5560 (6 Outrider) -
##   the actual intended pairing: Trapper slows, Archer finishes. This is
##   the one that needs to win, not fast_movers. Stayed near-parity under
##   the new formula (was 6188 vs 6000, ~3% apart; now ~0.1% apart).
## - archer_core_vs_melee_rush: 5877 ("Defensive Archer Core": 2
##   Shieldbearer/2 Trapper/3 Archer) vs 6698 ("Aggressive Melee Rush": 1
##   Marauder/2 Mage/4 Outrider, +14% over roster_a, deliberate premium -
##   see below) - named composition archetypes stress-testing both the
##   point-cost rework and the new roster's fix at once. roster_b was
##   rebuilt from the ground up after the old 2 Marauder/3 Outrider version
##   went 10/10 to roster_a in verification, for two compounding reasons:
##   (1) its 5 bodies to roster_a's 7 - the old formula never priced
##   headcount at all, so "equal points" quietly bought Melee Rush a
##   numbers disadvantage; (2) it had literally no answer to either enemy
##   type - Marauder deals only neutral (1.0x) damage to Shieldbearer, and
##   Outrider is the single hardest-countered type in the game against a
##   Trapper+Archer pairing (already validated in support_vs_outrider as a
##   deliberate Outrider hard-counter). The rebuilt roster now matches
##   roster_a's headcount (7v7) and adds 2 Mage specifically to exploit
##   Shieldbearer's 1.7x magic weakness, which the old all-neutral-damage
##   roster completely ignored - see the Ideas-vault section above for why
##   this needed a deliberate cost premium on top of matching headcount,
##   not just formula-parity at a new number.
const MATCHUPS := [
	{
		"id": "balanced",
		"display_name": "Balanced (mirror)",
		"roster_a": [
			CombatUnit.UnitType.SHIELDBEARER, CombatUnit.UnitType.SHIELDBEARER, CombatUnit.UnitType.MARAUDER,
			CombatUnit.UnitType.ARCHER, CombatUnit.UnitType.ARCHER, CombatUnit.UnitType.MAGE,
		],
		"roster_b": [
			CombatUnit.UnitType.SHIELDBEARER, CombatUnit.UnitType.SHIELDBEARER, CombatUnit.UnitType.MARAUDER,
			CombatUnit.UnitType.ARCHER, CombatUnit.UnitType.ARCHER, CombatUnit.UnitType.MAGE,
		],
	},
	{
		"id": "melee_vs_ranged",
		"display_name": "Melee vs Ranged",
		"roster_a": [
			CombatUnit.UnitType.SHIELDBEARER,
			CombatUnit.UnitType.ARCHER, CombatUnit.UnitType.ARCHER, CombatUnit.UnitType.ARCHER,
			CombatUnit.UnitType.ARCHER, CombatUnit.UnitType.ARCHER,
			CombatUnit.UnitType.MAGE,
		],
		"roster_b": [
			CombatUnit.UnitType.SHIELDBEARER, CombatUnit.UnitType.SHIELDBEARER, CombatUnit.UnitType.SHIELDBEARER,
			CombatUnit.UnitType.MARAUDER,
			CombatUnit.UnitType.ARCHER,
		],
	},
	{
		"id": "mage_heavy",
		"display_name": "Mage Swarm vs Balanced",
		"roster_a": [
			CombatUnit.UnitType.SHIELDBEARER, CombatUnit.UnitType.ARCHER,
			CombatUnit.UnitType.MAGE, CombatUnit.UnitType.MAGE, CombatUnit.UnitType.MAGE, CombatUnit.UnitType.MAGE,
			CombatUnit.UnitType.MAGE, CombatUnit.UnitType.MAGE, CombatUnit.UnitType.MAGE, CombatUnit.UnitType.MAGE,
		],
		"roster_b": [
			CombatUnit.UnitType.SHIELDBEARER, CombatUnit.UnitType.SHIELDBEARER, CombatUnit.UnitType.MARAUDER,
			CombatUnit.UnitType.ARCHER, CombatUnit.UnitType.ARCHER,
		],
	},
	# fast_movers: 5867 (4 Outrider/2 Archer) vs 5806 (4 Trapper/2
	# Shieldbearer) - exercises the newest pair directly: can Outrider
	# actually run down Archers before something stops it, and does getting
	# slowed by a Trapper negate that in practice.
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
			CombatUnit.UnitType.SHIELDBEARER, CombatUnit.UnitType.SHIELDBEARER,
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
	# archer_core_vs_melee_rush: 6970 (2 Shieldbearer/2 Trapper/3 Archer,
	# "Defensive Archer Core") vs 6825 (2 Marauder/3 Outrider, "Aggressive
	# Melee Rush") - two named composition archetypes stress-testing
	# everything built this session at once, each now built around the
	# melee type that actually matches its name: the defensive side leans
	# on Shieldbearer's line-holding plus Trapper wards protecting Archers,
	# the aggressive side is an all-in dive built around Marauder's raw DPS
	# punching through that screen while Outriders bypass it and hunt the
	# Archers directly - exactly the threat Trapper's ward system exists to
	# answer.
	{
		"id": "archer_core_vs_melee_rush",
		"display_name": "Defensive Archer Core vs Aggressive Melee Rush",
		"roster_a": [
			CombatUnit.UnitType.SHIELDBEARER, CombatUnit.UnitType.SHIELDBEARER,
			CombatUnit.UnitType.TRAPPER, CombatUnit.UnitType.TRAPPER,
			CombatUnit.UnitType.ARCHER, CombatUnit.UnitType.ARCHER, CombatUnit.UnitType.ARCHER,
		],
		"roster_b": [
			CombatUnit.UnitType.MARAUDER,
			CombatUnit.UnitType.MAGE, CombatUnit.UnitType.MAGE,
			CombatUnit.UnitType.OUTRIDER, CombatUnit.UnitType.OUTRIDER,
			CombatUnit.UnitType.OUTRIDER, CombatUnit.UnitType.OUTRIDER,
		],
	},
]

## Which Formation preset each team starts in before its StrategistAI has
## had a chance to react - see FormationCatalog.
const STARTING_FORMATION_ID := "line"

## How many tiles inside the ground's own outer edge BattlefieldTerrain's
## border wall sits (_iso_ground_corners(BORDER_INSET_TILES), fed to
## terrain.generate()) - per a follow-up request that the wall actually
## conform to the isometric ground and encompass exactly where tiles are
## visible, rather than a separately hand-picked rectangle that could (and
## did) drift out of sync with $IsoGround's own size, or leave rectangle
## corners beyond the visible diamond of tiles walkable. Small enough that
## the rocks still read as sitting right at the map's edge rather than
## floating conspicuously inside it.
const BORDER_INSET_TILES := 0.5

@onready var camera: RtsCamera = $RtsCamera
@onready var iso_ground: IsoGround = $IsoGround
@onready var nav_region: NavigationRegion2D = $NavigationRegion2D
@onready var result_label: Label = $UI/ResultLabel
@onready var hint_label: Label = $UI/HintLabel
@onready var strategy_label: Label = $UI/StrategyLabel
@onready var matchup_label: Label = $UI/MatchupLabel
@onready var speed_label: Label = $UI/SpeedLabel

## Regenerated every battle (_generate_terrain) - see BattlefieldTerrain's
## own doc comment for what "dynamic battlefield with chokepoints and
## rough terrain" actually means here. Pinned behind every y-sorted
## participant the same way IsoGround is (see CLAUDE.md's y-sort section)
## - units never actually overlap an obstacle's interior (the navmesh is
## carved around it), so there's no per-obstacle sort case that matters
## enough to justify per-cluster child nodes.
var terrain: BattlefieldTerrain

## Fast-forward, so watching a full battle (or a long batch of them, e.g.
## repeatedly restarting to compare a matchup's outcomes) doesn't need to
## take real-time-equivalent minutes now that HEALTH_MULTIPLIER makes
## battles run longer. Engine.time_scale is a global engine setting, not
## scoped to this scene, so it's explicitly reset to 1.0 on every path out
## of this scene (see _unhandled_input's Esc case and _exit_tree) -
## otherwise leaving at, say, 4x would leave the main menu (and anything
## after it) running fast too.
const SPEED_MULTIPLIERS := [0.5, 1.0, 2.0, 4.0, 8.0, 16.0]
var speed_index := 1

var team_a: Array = []
var team_b: Array = []
var formation_a: Formation
var formation_b: Formation
var strategist_a: StrategistAI
var strategist_b: StrategistAI
var matchup_index := 0
## True once a winner (by wipe-out or mass rout - see Formation.
## MASS_ROUT_THRESHOLD) has been decided for the current battle -
## _declare_result() sets this and every result-checking path is guarded
## by it, so a battle can't have its result overwritten once decided
## (e.g. a mass rout firing, then a few more ordinary deaths landing
## while the last routing stragglers are still jogging off-map).
var battle_over := false
## Set alongside battle_over by _declare_result - "win"/"lose"/"draw" from
## Team A's perspective, i.e. the defending squad's perspective in
## deployment mode. Only meaningful once battle_over is true; read by
## _return_to_base to fill BattleState.result.
var _battle_outcome := ""
## Every team-A CombatUnit.citizen_id that has fired `died`, accumulated as
## the battle runs rather than read from team_a's contents once the battle
## ends - see the research this integration was built from: team_a/team_b
## over-count survivors right after a mass-rout decides the result (routing
## units are still "in" the array until they finish fleeing several seconds
## later). Death is the only casualty condition in this combat model
## (routing makes a unit untargetable, so it can never die after that point)
## - so this list is already final the instant battle_over flips, no need
## to wait for stragglers to actually leave the map. Reset at the top of
## every _spawn_battle() so R-restarting a deployment doesn't carry a
## previous attempt's deaths into the next one.
var _squad_casualty_ids: Array[String] = []


func _ready() -> void:
	camera.position = Vector2.ZERO
	terrain = BattlefieldTerrain.new()
	terrain.z_index = -1
	add_child(terrain)
	## HintLabel's scene-authored text ("M: Cycle matchup" / "Esc: Main
	## menu") is only accurate for the free-play sandbox - M is inert and
	## Esc goes to Base, not the main menu, in deployment mode (see
	## _unhandled_input).
	if BattleState.active:
		hint_label.text = "R: Restart battle\n+/-: Battle speed\nEsc: Return to settlement"
	_generate_terrain()
	_setup_navigation()
	_spawn_battle()
	_apply_speed()


## Safety net alongside the explicit reset in _unhandled_input's Esc case -
## covers any other way this scene could end up removed from the tree
## (e.g. a future different exit path) without leaving Engine.time_scale
## stuck elevated for whatever loads next.
func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _apply_speed() -> void:
	Engine.time_scale = SPEED_MULTIPLIERS[speed_index]
	var mult: float = SPEED_MULTIPLIERS[speed_index]
	speed_label.text = "Speed: %sx" % (str(int(mult)) if mult == floor(mult) else str(mult))


## The four corners (in cyclic order, closed by wrapping back to index 0)
## of $IsoGround's own visible outer edge, in the same world/screen space
## CombatUnit positions already live in - derived directly from its
## exported width/depth/start_x/start_y plus half a tile of margin (each
## tile sprite extends TILE_WIDTH/TILE_HEIGHT around its own center, so the
## actual visible edge sits half a tile beyond the outermost tile
## *centers*), projected through the same IsoUtils.grid_to_screen() the
## ground tiles themselves use. Reading $IsoGround's own properties here
## rather than maintaining a separately hand-picked rectangle (the old
## NAV_BOUNDS) is what guarantees the navmesh/border can never drift out
## of sync with the ground - previously true only by manual discipline
## (both had to be doubled together when the map was last resized).
## `inset_tiles` shrinks the rectangle inward in *grid* space before
## projecting - the natural way to inset a shape that's an affine, not
## just a uniform-scale, image of a rectangle (the projection also shears)
## - a plain per-axis pixel inset wouldn't shrink all four sloped edges by
## the same visual amount.
func _iso_ground_corners(inset_tiles: float = 0.0) -> PackedVector2Array:
	var gx0 := float(iso_ground.start_x) - 0.5 + inset_tiles
	var gx1 := float(iso_ground.start_x + iso_ground.width) - 0.5 - inset_tiles
	var gy0 := float(iso_ground.start_y) - 0.5 + inset_tiles
	var gy1 := float(iso_ground.start_y + iso_ground.depth) - 0.5 - inset_tiles
	return PackedVector2Array([
		IsoUtils.grid_to_screen(Vector2(gx0, gy0)),
		IsoUtils.grid_to_screen(Vector2(gx1, gy0)),
		IsoUtils.grid_to_screen(Vector2(gx1, gy1)),
		IsoUtils.grid_to_screen(Vector2(gx0, gy1)),
	])


## Axis-aligned bounding box of the ground's outer edge (see
## _iso_ground_corners) - used only for CombatUnit.play_bounds's cheap
## per-frame hard-clamp backstop, which needs a plain Rect2, not the true
## diamond/parallelogram shape. A deliberate superset of the actual
## walkable area (a parallelogram's bounding box always is) - that's fine,
## it's a last-resort safety net for RVO overshoot (see play_bounds's own
## doc comment on CombatUnit), not the real boundary; BattlefieldTerrain's
## border wall is an exact polygon and is what actually seals the edge.
func _iso_ground_bounds_rect() -> Rect2:
	var corners := _iso_ground_corners()
	var r := Rect2(corners[0], Vector2.ZERO)
	for c in corners:
		r = r.expand(c)
	return r


## Baked in code rather than authored/baked in the editor so the navmesh
## can't silently drift out of sync with $IsoGround's own size.
## NavigationServer2D.bake_from_source_geometry_data() (not the simpler but
## deprecated NavigationPolygon.make_polygons_from_outlines()) is the
## current non-deprecated way to bake a polygon with no parsed scene
## geometry. The outline is the ground's own isometric footprint (see
## _iso_ground_corners()), not an axis-aligned rectangle - a follow-up fix
## after the border wall (see below) was originally traced around a
## rectangle superset of the visible diamond of tiles, which both looked
## wrong (a rectangular wall around a diamond map) and would have let
## units path into the rectangle's corners, past the last visible tile.
## terrain.obstacles are fed in as obstruction outlines - each one carves
## a hole in the resulting navmesh, so NavigationAgent2D pathing actually
## routes around BattlefieldTerrain's rock clusters and through its
## barricade gaps rather than walking through rock.
func _setup_navigation() -> void:
	var nav_poly := NavigationPolygon.new()
	nav_poly.add_outline(_iso_ground_corners())
	var source_geometry := NavigationMeshSourceGeometryData2D.new()
	for outline in terrain.obstacles:
		source_geometry.add_obstruction_outline(outline)
	NavigationServer2D.bake_from_source_geometry_data(nav_poly, source_geometry)
	nav_region.navigation_polygon = nav_poly


## Fresh RNG (unseeded - true per-battle randomness) every call, so R
## (_restart) and M (matchup cycle, which also calls _restart) both hand
## the next battle a different layout, not just the first one. The
## border polygon handed to terrain is inset BORDER_INSET_TILES inside the
## ground's own outer edge - see that constant's doc comment.
func _generate_terrain() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	terrain.generate(_iso_ground_corners(BORDER_INSET_TILES), rng)


func _process(delta: float) -> void:
	if battle_over:
		return
	if is_instance_valid(strategist_a):
		strategist_a.update(delta)
	if is_instance_valid(strategist_b):
		strategist_b.update(delta)
	if is_instance_valid(formation_a) and is_instance_valid(formation_b):
		strategy_label.text = "Team A: %s   |   Team B: %s" % [formation_a.preset_id.capitalize(), formation_b.preset_id.capitalize()]
	_check_mass_rout(formation_a, "Team B wins - Team A routed! %s" % _result_hint(), "lose")
	_check_mass_rout(formation_b, "Team A wins - Team B routed! %s" % _result_hint(), "win")


## See Formation.MASS_ROUT_THRESHOLD/force_rout_all() - the result is
## decided the instant enough of a team has broken, not once every
## straggler has physically left the map (which would just delay a
## result that's already inevitable).
func _check_mass_rout(formation: Formation, result_text: String, outcome: String) -> void:
	if not is_instance_valid(formation) or not formation.is_mass_routed():
		return
	formation.force_rout_all()
	_declare_result(result_text, outcome)


## "Press R to restart." in the free-play sandbox (unchanged); in deployment
## mode restarting doesn't make sense to offer as the primary action (the
## squad already committed) so the hint instead points at the one action
## that actually matters there - see _return_to_base.
func _result_hint() -> String:
	return "Press Esc to return to the settlement." if BattleState.active else "Press R to restart."


func _unhandled_input(event: InputEvent) -> void:
	## Checked first and unconditionally, NOT as an `elif` sibling of the
	## `event is InputEventKey` branch below - a pre-existing structural bug
	## found while verifying this integration: Escape's own key-press event
	## IS an InputEventKey with pressed == true, so the old `if event is
	## InputEventKey and event.pressed: ... elif event.is_action_pressed(
	## "ui_cancel")` shape meant Escape's InputEventKey always matched the
	## first branch (falling through R/M/+/- with no match) and could NEVER
	## reach the elif - "Esc returns to main menu" was dead code in the
	## free-play sandbox even before this deployment-mode Esc-return was
	## added, which would have inherited the exact same dead branch.
	## Confirmed via a headless driver that fed a real InputEventKey(Escape)
	## through this exact function.
	if event.is_action_pressed("ui_cancel"):
		if BattleState.active:
			## Works whether the battle has already resolved (the normal
			## case per _result_hint's prompt) or not (an early Esc reads as
			## retreating the squad - any citizen not already in
			## _squad_casualty_ids just returns home unharmed, same as a
			## clean win/loss report).
			_return_to_base()
		else:
			Engine.time_scale = 1.0
			get_tree().change_scene_to_file(MAIN_MENU_SCENE)
		return

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			_restart()
		elif event.keycode == KEY_M and not BattleState.active:
			## Cycling MATCHUPS makes no sense against a deployed citizen
			## squad - roster_a comes from BattleState.pending_squad in that
			## mode, not from MATCHUPS at all (see _spawn_battle) - so M is
			## simply inert in deployment mode rather than reassigning a
			## roster nobody generated.
			matchup_index = (matchup_index + 1) % MATCHUPS.size()
			_restart()
		elif event.keycode == KEY_EQUAL or event.keycode == KEY_KP_ADD:
			speed_index = mini(speed_index + 1, SPEED_MULTIPLIERS.size() - 1)
			_apply_speed()
		elif event.keycode == KEY_MINUS or event.keycode == KEY_KP_SUBTRACT:
			speed_index = maxi(speed_index - 1, 0)
			_apply_speed()


func _spawn_battle() -> void:
	result_label.text = ""
	battle_over = false
	_battle_outcome = ""
	_squad_casualty_ids = []

	var roster_a: Array = []
	var roster_b: Array = []
	var skill_levels_a: Array = []
	var citizen_ids_a: Array = []

	if BattleState.active:
		## Real deployment - see Base._on_attack_pressed for how
		## pending_squad was built (one entry per citizen currently assigned
		## to a TrainingGround). The enemy roster is a same-composition
		## mirror of the defending squad (mock skill levels, same as the
		## free-play sandbox's own teams) - a deliberate first-pass stand-in
		## for a real raider-generation system (see Docs/roadmap.md's
		## "raids/sieges" long-term item), not a balanced-encounter design.
		matchup_label.text = "Defending the settlement"
		for entry in BattleState.pending_squad:
			roster_a.append(entry["unit_type"])
			skill_levels_a.append(entry["skill_level"])
			citizen_ids_a.append(entry["citizen_id"])
		roster_b = roster_a.duplicate()
	else:
		var matchup: Dictionary = MATCHUPS[matchup_index]
		matchup_label.text = "Matchup: %s (M to cycle)" % matchup["display_name"]
		roster_a = matchup["roster_a"]
		roster_b = matchup["roster_b"]

	var starting_preset := FormationCatalog.get_option(STARTING_FORMATION_ID)
	var bounds := _iso_ground_bounds_rect().grow(-CombatUnit.UNIT_RADIUS)

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

	team_a = _spawn_team(CombatUnit.Team.A, formation_a, roster_a, skill_levels_a, citizen_ids_a)
	team_b = _spawn_team(CombatUnit.Team.B, formation_b, roster_b)
	# Only after _spawn_team returns a finished roster - it returns a new
	# Array rather than mutating one in place, so assigning living_units any
	# earlier would leave each formation watching a stale, permanently-empty
	# array (frozen anchor, no runtime error to notice it by).
	formation_a.living_units = team_a
	formation_b.living_units = team_b
	formation_a.original_roster_size = team_a.size()
	formation_b.original_roster_size = team_b.size()

	for unit in team_a:
		(unit as CombatUnit).enemies = team_b
		(unit as CombatUnit).died.connect(_on_unit_died)
		(unit as CombatUnit).escaped.connect(_on_unit_escaped)
	for unit in team_b:
		(unit as CombatUnit).enemies = team_a
		(unit as CombatUnit).died.connect(_on_unit_died)
		(unit as CombatUnit).escaped.connect(_on_unit_escaped)

	strategist_a = StrategistAI.new(formation_a, team_b)
	strategist_b = StrategistAI.new(formation_b, team_a)


## Sandbox stand-in for a real citizen's trained combat-skill level
## (CombatUnit.SKILL_ID[unit_type]) - there's no real CharacterData here, so
## each spawned unit gets a random level in this range instead, which is
## what actually makes the skill-augment effect visible battle-to-battle
## (a fixed level for everyone would look identical to no system at all).
const MOCK_SKILL_LEVEL_MIN := 1
const MOCK_SKILL_LEVEL_MAX := 70


## `skill_levels`/`citizen_ids`, when non-empty, are positionally parallel to
## `roster` - the real-deployment case (see _spawn_battle), where each
## citizen's actual trained level (not a mock roll) and CharacterData.id
## (for casualty tracking, see _on_unit_died) need to land on the matching
## unit. Left empty for the free-play sandbox's own two teams and for the
## generated enemy roster in deployment mode - both fall back to the
## existing mock-level behavior exactly as before, and citizen_id stays "".
func _spawn_team(team: CombatUnit.Team, formation: Formation, roster: Array, skill_levels: Array = [], citizen_ids: Array = []) -> Array:
	var units: Array = []
	var offsets := formation.assign_slots(roster)
	for i in roster.size():
		var unit: CombatUnit = CombatUnitScene.instantiate()
		add_child(unit)
		unit.global_position = formation.global_position + offsets[i]
		var skill_level: int = skill_levels[i] if i < skill_levels.size() else randi_range(MOCK_SKILL_LEVEL_MIN, MOCK_SKILL_LEVEL_MAX)
		unit.setup(roster[i], team, [], formation.play_bounds, formation, offsets[i], skill_level, terrain)
		if i < citizen_ids.size():
			unit.citizen_id = citizen_ids[i]
		units.append(unit)
	return units


## An escaped unit (see CombatUnit.escaped/_escape()) is removed from its
## team exactly like a death - either way it's no longer available to
## fight - but doesn't itself represent a loss condition the way a wipe
## does; _check_empty_teams() below still declares a normal wipe-out
## winner if enough individual escapes eventually empty a team without
## ever crossing the mass-rout threshold (a slower, edge-case path to the
## same kind of result the mass-rout check in _process() usually beats it
## to).
func _on_unit_died(unit: CombatUnit) -> void:
	if unit.citizen_id != "":
		_squad_casualty_ids.append(unit.citizen_id)
	team_a.erase(unit)
	team_b.erase(unit)
	_check_empty_teams()


func _on_unit_escaped(unit: CombatUnit) -> void:
	team_a.erase(unit)
	team_b.erase(unit)
	_check_empty_teams()


func _check_empty_teams() -> void:
	var a_alive := not team_a.is_empty()
	var b_alive := not team_b.is_empty()
	if a_alive and b_alive:
		return
	if a_alive:
		_declare_result("Team A wins! %s" % _result_hint(), "win")
	elif b_alive:
		_declare_result("Team B wins! %s" % _result_hint(), "lose")
	else:
		_declare_result("Draw! %s" % _result_hint(), "draw")


## Guarded by battle_over so the result can't be overwritten once decided
## - see that field's own doc comment. `outcome` ("win"/"lose"/"draw", from
## Team A's perspective) is only used in deployment mode (see
## _return_to_base) - the free-play sandbox has no BattleState to report it
## to, so its call sites just leave it at the default "".
func _declare_result(text: String, outcome: String = "") -> void:
	if battle_over:
		return
	battle_over = true
	_battle_outcome = outcome
	result_label.text = text


## Only ever called in deployment mode (BattleState.active) - see
## _unhandled_input's Esc handling. Writes the casualty report Base is
## waiting for (_apply_battle_result) and hands control back; BattleState.
## pending_squad/town_blob/active are left as Base set them, since Base
## itself is what clears the whole autoload once it's read `result` back
## (see Base._ready()'s doc comment on that branch) - not this scene's job.
func _return_to_base() -> void:
	Engine.time_scale = 1.0
	BattleState.result = {
		"outcome": _battle_outcome if not _battle_outcome.is_empty() else "draw",
		"casualty_ids": _squad_casualty_ids,
	}
	get_tree().change_scene_to_file(BASE_SCENE)


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
	_generate_terrain()
	_setup_navigation()
	_spawn_battle()
