extends Node2D
class_name BattlefieldTerrain

## Procedurally generates the combat sandbox's obstacle/terrain layout -
## regenerated with a fresh RNG seed every battle (CombatTestManager.
## _generate_terrain(), called from both _ready() and _restart()) so no two
## fights play out on the same map, per an explicit request for "a dynamic
## battlefield with chokepoints and rough terrain." Two independent
## features:
##
## - **Chokepoints**: two "barricade lines" of overlapping rock-cluster
##   obstacles (one north, one south of the map's own centerline), each
##   with 1-2 randomized gaps wide enough for a few units abreast. Fed into
##   CombatTestManager._setup_navigation() as obstruction outlines, so the
##   navmesh is actually carved around them - NavigationAgent2D pathing
##   (not hand-rolled steering) is what makes units funnel through the
##   gaps rather than walking through rock.
## - **Rough terrain**: circular patches that halve move speed for any
##   unit standing in one (get_speed_multiplier()), applied everywhere
##   CombatUnit computes its own effective_speed - a soft slow zone rather
##   than a hard obstacle.
##
## Both features stay clear of a band around the map's own centerline
## (CLEAR_LANE_*) - both Formations start co-located at world origin (see
## CombatTestManager._spawn_battle) and the opening clash happens there
## first; terrain instead shapes *later* movement (flanking, kiting,
## routing, mid-battle formation-preset repositioning) rather than
## blocking the initial engagement outright. Since the clear lane is
## always open, the map can never end up fully disconnected regardless of
## how barricade gaps/rough patches land - correctness doesn't depend on
## the RNG producing a "fair" layout.
##
## Both features are also confined to ACTIVE_ZONE_HALF_EXTENTS, a
## fixed-size box around the map center, rather than scaling with the
## ground's own footprint - deliberately decoupled from map size. Where
## units actually go is governed by absolute pixel distances (formation
## leash ranges topping out around 550px, kiting/flanking radii in the low
## hundreds) that have nothing to do with how big the overall map is, so a
## bigger map (more perimeter/maneuvering room, see _generate_border())
## shouldn't also spread tactical terrain across a proportionally wider
## area units never actually reach - confirmed via headless
## instrumentation after an earlier version scattered rough patches across
## the map's *entire* extent and found they landed under a unit 0% of the
## time in a full battle.
##
## Obstacles also block ranged line of sight (blocks_line_of_sight()),
## reusing the same "straight line to target" concept as CombatUnit.
## _has_line_of_sight()'s ally/enemy-body cover check - rock cover works
## the same way body cover already does.
##
## The map's outer edge is sealed by _generate_border() - a solid,
## gapless ring of rock clusters just inside `border_polygon`, added per
## an explicit follow-up request ("make the edges of the battlefield
## blocked off by unpassable terrain") to replace the old invisible
## play_bounds hard-clamp (CombatUnit.play_bounds, still kept as a
## backstop - RVO avoidance isn't aware of navmesh geometry, so a
## heavily-crowded unit could in principle still get shoved a few px past
## the border before the navmesh-respecting path correction catches up)
## with something a player can actually see and that blocks pathing/LOS
## the same way any other obstacle here does.
##
## `border_polygon` is computed by CombatTestManager (_iso_ground_corners)
## directly from $IsoGround's own width/depth/start_x/start_y, projected
## through the same IsoUtils.grid_to_screen() the ground tiles themselves
## use - per a follow-up request, the wall needs to actually conform to
## the isometric ground (a rotated 2:1 diamond/parallelogram, not an
## axis-aligned rectangle) and encompass exactly the tile footprint that's
## visibly ground, not a separately-hand-picked bounding box that could
## drift out of sync with it or leave rectangle corners beyond the visible
## tiles walkable. _generate_border() itself has no idea it's tracing an
## isometric shape specifically - it just walks whatever closed polygon
## it's handed, corner to corner - so the iso-conformance lives entirely
## in how the caller builds that polygon, not in this function.

const OBSTACLE_COLOR := Color(0.32, 0.3, 0.28)
const OBSTACLE_OUTLINE_COLOR := Color(0.16, 0.15, 0.13)
const ROUGH_TERRAIN_COLOR := Color(0.42, 0.36, 0.18, 0.45)

## Rough terrain multiplies move speed by this while a unit's position is
## inside any patch - harsh enough to matter tactically (nearly halves
## speed, comparable to Trapper's own SLOW_MULTIPLIER) without fully
## immobilizing anyone caught on it.
const ROUGH_TERRAIN_SPEED_MULTIPLIER := 0.55

## y-offset band (mirrored north/south by _generate_barricade's `side`)
## each barricade line's rock clusters are centered on.
const BARRICADE_Y_MIN := 300.0
const BARRICADE_Y_MAX := 520.0
## Inset from ACTIVE_ZONE_HALF_EXTENTS's own x-edges a barricade line's
## rocks start/stop at (not the map's own x-edges - see ACTIVE_ZONE_HALF_
## EXTENTS's doc comment).
const BARRICADE_MARGIN_MIN := 120.0
const BARRICADE_MARGIN_MAX := 280.0
## Step between consecutive rock clusters along a barricade line - smaller
## than twice OBSTACLE_RADIUS_MIN so consecutive rocks always overlap,
## which is what keeps the "wall" solid instead of leaving unintended
## micro-gaps RVO avoidance could exploit.
const OBSTACLE_SPACING := 85.0
const OBSTACLE_RADIUS_MIN := 50.0
const OBSTACLE_RADIUS_MAX := 70.0
## Deliberate gap(s) left in an otherwise-solid barricade line - the actual
## chokepoint a team has to funnel through to go around that flank.
const GAP_COUNT_MIN := 1
const GAP_COUNT_MAX := 2
const GAP_WIDTH_MIN := 170.0
const GAP_WIDTH_MAX := 240.0

## The perimeter ring (_generate_border()) is gapless by design - the map
## edge, unlike a barricade line, isn't meant to be flankable. How far the
## rocks sit inside the ground's own outer edge is CombatTestManager's
## call (baked into the polygon it hands to generate()), not this file's -
## see _iso_ground_corners()'s BORDER_INSET_TILES.
const BORDER_OBSTACLE_SPACING := 85.0
const BORDER_OBSTACLE_RADIUS_MIN := 55.0
const BORDER_OBSTACLE_RADIUS_MAX := 75.0
## Deliberately still plain (unsquashed) circular-ish rock clusters rather
## than matching the ground tiles' 2:1 width:height ratio - a fixed
## screen-space squash would shrink exactly the axis each obstacle relies
## on to guarantee overlap with its neighbors (OBSTACLE_SPACING/BORDER_
## OBSTACLE_SPACING < 2x each radius) along whichever direction a given
## wall segment happens to run. That guarantee is direction-independent
## only because the shape is isotropic; the border in particular walks a
## parallelogram with edges running in more than one direction (see
## _generate_border()), so a segment running closer to vertical would lose
## most of its overlap margin under a fixed vertical squash - a real
## exploitable gap risk, not just a cosmetic tradeoff. The wall's overall
## *shape* (the polygon it traces) is what needs to conform to the
## isometric ground footprint here, not each individual rock's silhouette.

const ROUGH_PATCH_COUNT_MIN := 3
const ROUGH_PATCH_COUNT_MAX := 5
const ROUGH_PATCH_RADIUS_MIN := 90.0
const ROUGH_PATCH_RADIUS_MAX := 170.0
## Kept clear of rough patches too - see the class doc comment's "clear
## lane" note.
const CLEAR_LANE_RADIUS := 220.0
## Fixed-size box around the map center that both the barricade lines'
## x-span and rough-patch placement are confined to, independent of the
## ground's own footprint - see the class doc comment for why this is
## deliberately not derived from the map's own size. Half-height (600)
## comfortably contains BARRICADE_Y_MAX (520) plus a rock's own radius.
const ACTIVE_ZONE_HALF_EXTENTS := Vector2(900.0, 600.0)

## Each entry a world-space polygon (PackedVector2Array) - both the
## drawn rock-cluster shape and the navmesh obstruction outline fed to
## NavigationMeshSourceGeometryData2D.add_obstruction_outline().
var obstacles: Array[PackedVector2Array] = []
## Each entry {"center": Vector2, "radius": float}.
var rough_patches: Array[Dictionary] = []


## `border_polygon` is the closed loop (already in world/screen space, any
## number of corners - see _generate_border()) that the map's own
## impassable edge should trace; CombatTestManager builds it from the
## actual ground tile footprint. See the class doc comment for why that
## responsibility lives with the caller, not here.
func generate(border_polygon: PackedVector2Array, rng: RandomNumberGenerator) -> void:
	obstacles.clear()
	rough_patches.clear()
	_generate_barricade(rng, 1.0)
	_generate_barricade(rng, -1.0)
	_generate_rough_patches(rng)
	_generate_border(border_polygon, rng)
	queue_redraw()


## A solid, gapless ring of rock clusters tracing `border_polygon` -
## see the class doc comment's "map's outer edge" note. Walks the
## polygon's own corners in a cyclic loop (works for any convex polygon,
## not just a rectangle - the isometric ground footprint this is actually
## called with is a parallelogram, not axis-aligned) so the corners get
## seamless coverage without any extra corner-specific logic - each side's
## walk naturally runs a bit past its own corner into the next side's
## starting point.
func _generate_border(border_polygon: PackedVector2Array, rng: RandomNumberGenerator) -> void:
	var n := border_polygon.size()
	for i in n:
		var from: Vector2 = border_polygon[i]
		var to: Vector2 = border_polygon[(i + 1) % n]
		var length := from.distance_to(to)
		if length < 0.01:
			continue
		var dir := (to - from) / length
		var d := 0.0
		while d < length:
			var jitter := Vector2(rng.randf_range(-15.0, 15.0), rng.randf_range(-15.0, 15.0))
			var radius := rng.randf_range(BORDER_OBSTACLE_RADIUS_MIN, BORDER_OBSTACLE_RADIUS_MAX)
			obstacles.append(_make_rock_outline(from + dir * d + jitter, radius, rng))
			d += BORDER_OBSTACLE_SPACING


func _generate_barricade(rng: RandomNumberGenerator, side: float) -> void:
	var y := side * rng.randf_range(BARRICADE_Y_MIN, BARRICADE_Y_MAX)
	var zone := Rect2(-ACTIVE_ZONE_HALF_EXTENTS, ACTIVE_ZONE_HALF_EXTENTS * 2.0)
	var x_start := zone.position.x + rng.randf_range(BARRICADE_MARGIN_MIN, BARRICADE_MARGIN_MAX)
	var x_end := zone.end.x - rng.randf_range(BARRICADE_MARGIN_MIN, BARRICADE_MARGIN_MAX)
	if x_end <= x_start:
		return

	var gap_count := rng.randi_range(GAP_COUNT_MIN, GAP_COUNT_MAX)
	var gaps: Array[Vector2] = []
	for _i in gap_count:
		var center := rng.randf_range(x_start, x_end)
		var half_width := rng.randf_range(GAP_WIDTH_MIN, GAP_WIDTH_MAX) / 2.0
		gaps.append(Vector2(center - half_width, center + half_width))

	var x := x_start
	while x <= x_end:
		var in_gap := false
		for gap in gaps:
			if x >= gap.x and x <= gap.y:
				in_gap = true
				break
		if not in_gap:
			var jitter := Vector2(rng.randf_range(-20.0, 20.0), rng.randf_range(-25.0, 25.0))
			var radius := rng.randf_range(OBSTACLE_RADIUS_MIN, OBSTACLE_RADIUS_MAX)
			obstacles.append(_make_rock_outline(Vector2(x, y) + jitter, radius, rng))
		x += OBSTACLE_SPACING


func _generate_rough_patches(rng: RandomNumberGenerator) -> void:
	var count := rng.randi_range(ROUGH_PATCH_COUNT_MIN, ROUGH_PATCH_COUNT_MAX)
	var zone := Rect2(-ACTIVE_ZONE_HALF_EXTENTS, ACTIVE_ZONE_HALF_EXTENTS * 2.0)
	var attempts := 0
	# Bounded retry rather than an infinite loop - a patch that would land
	# inside the clear lane is skipped and re-rolled, but the loop still
	# has to terminate even in a pathological bounds/radius combination.
	while rough_patches.size() < count and attempts < count * 8:
		attempts += 1
		var radius := rng.randf_range(ROUGH_PATCH_RADIUS_MIN, ROUGH_PATCH_RADIUS_MAX)
		var pos := Vector2(
			rng.randf_range(zone.position.x + radius, zone.end.x - radius),
			rng.randf_range(zone.position.y + radius, zone.end.y - radius)
		)
		if pos.length() < CLEAR_LANE_RADIUS + radius:
			continue
		rough_patches.append({"center": pos, "radius": radius})


## Irregular hexagon/heptagon-ish polygon approximating a circle of
## `radius`, per-vertex jittered - reads as a rock cluster rather than a
## mechanically perfect circle without needing actual art.
func _make_rock_outline(center: Vector2, radius: float, rng: RandomNumberGenerator) -> PackedVector2Array:
	var points := PackedVector2Array()
	var vertex_count := rng.randi_range(6, 8)
	for i in vertex_count:
		var angle := TAU * i / vertex_count
		var r := radius * rng.randf_range(0.75, 1.15)
		points.append(center + Vector2(cos(angle), sin(angle)) * r)
	return points


## 1.0 normally, ROUGH_TERRAIN_SPEED_MULTIPLIER while `pos` sits inside any
## rough patch - read by CombatUnit everywhere it computes effective_speed.
func get_speed_multiplier(pos: Vector2) -> float:
	for patch in rough_patches:
		var center: Vector2 = patch["center"]
		var radius: float = patch["radius"]
		if pos.distance_squared_to(center) <= radius * radius:
			return ROUGH_TERRAIN_SPEED_MULTIPLIER
	return 1.0


## True if any obstacle's outline crosses the straight segment from `a` to
## `b` - same "rock cover blocks a shot" concept CombatUnit.
## _has_line_of_sight() already applies to ally/enemy bodies, extended to
## terrain.
func blocks_line_of_sight(a: Vector2, b: Vector2) -> bool:
	for outline in obstacles:
		var n := outline.size()
		for i in n:
			var p1 := outline[i]
			var p2 := outline[(i + 1) % n]
			if Geometry2D.segment_intersects_segment(a, b, p1, p2) != null:
				return true
	return false


func _draw() -> void:
	for patch in rough_patches:
		draw_circle(patch["center"], patch["radius"], ROUGH_TERRAIN_COLOR)
	for outline in obstacles:
		draw_colored_polygon(outline, OBSTACLE_COLOR)
		var closed := PackedVector2Array(outline)
		closed.append(outline[0])
		draw_polyline(closed, OBSTACLE_OUTLINE_COLOR, 2.0)
