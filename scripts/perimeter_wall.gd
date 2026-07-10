extends Node2D
class_name PerimeterWall

const WALL_SLOT_SCENE := preload("res://scenes/build_slot/BuildSlot.tscn")
const CORNER_PEAK_SCENE := preload("res://scenes/wall/WallCornerPeak.tscn")
const CORNER_POINT_SCENE := preload("res://scenes/wall/WallCornerPoint.tscn")

## Half a tile, in grid units: shifts a wall from the tile center onto the
## tile's outer edge (the side facing away from the compound interior).
const OUTWARD := 0.5
## How much of each edge's length (in grid units) to leave clear for the
## corner piece, so straight segments don't overlap it.
const CORNER_MARGIN := 1.1

@export var gx_min: float = -1.5
@export var gx_max: float = 6.5
@export var gy_min: float = -1.5
@export var gy_max: float = 6.5
@export var segment_step: float = 2.0
@export var gate_center: float = 2.5
@export var gate_half_width: float = 1.3


func _ready() -> void:
	# Edges where gy is fixed (gx varies) slope the opposite way on screen from
	# edges where gx is fixed (gy varies), so they need the mirrored wall art.
	_build_edge(gx_min + CORNER_MARGIN, gx_max - CORNER_MARGIN, gy_min, true, -OUTWARD, true, false)
	_build_edge(gx_min + CORNER_MARGIN, gx_max - CORNER_MARGIN, gy_max, true, OUTWARD, true, true)
	_build_edge(gy_min + CORNER_MARGIN, gy_max - CORNER_MARGIN, gx_min, false, -OUTWARD, false, false)
	_build_edge(gy_min + CORNER_MARGIN, gy_max - CORNER_MARGIN, gx_max, false, OUTWARD, false, false)

	_place_corner(Vector2(gx_min - OUTWARD, gy_min - OUTWARD), CORNER_PEAK_SCENE, false, true)
	_place_corner(Vector2(gx_max + OUTWARD, gy_max + OUTWARD), CORNER_PEAK_SCENE, false, false)
	_place_corner(Vector2(gx_min - OUTWARD, gy_max + OUTWARD), CORNER_POINT_SCENE, false, false)
	_place_corner(Vector2(gx_max + OUTWARD, gy_min - OUTWARD), CORNER_POINT_SCENE, true, false)


func _build_edge(along_min: float, along_max: float, fixed_value: float, fixed_is_gy: bool, outward: float, flip_h: bool, has_gate: bool) -> void:
	var drawn_fixed := fixed_value + outward
	var steps: int = maxi(1, int(round((along_max - along_min) / segment_step)))
	for i in range(steps + 1):
		var t: float = along_min + (along_max - along_min) * (float(i) / float(steps))
		if has_gate and absf(t - gate_center) < gate_half_width:
			continue
		_place_slot(_grid_point(t, drawn_fixed, fixed_is_gy), "medium", flip_h)

	if has_gate:
		_place_slot(_grid_point(gate_center, drawn_fixed, fixed_is_gy), "gate", flip_h)


func _grid_point(along: float, fixed_value: float, fixed_is_gy: bool) -> Vector2:
	return Vector2(along, fixed_value) if fixed_is_gy else Vector2(fixed_value, along)


func _place_slot(grid: Vector2, size: String, flip_h: bool) -> void:
	var slot: BuildSlot = WALL_SLOT_SCENE.instantiate()
	slot.slot_size = size
	slot.position = IsoUtils.grid_to_screen(grid)
	slot.flip_h = flip_h
	add_child(slot)


func _place_corner(grid: Vector2, scene: PackedScene, flip_h: bool, flip_v: bool) -> void:
	var corner: Node2D = scene.instantiate()
	add_child(corner)
	corner.position = IsoUtils.grid_to_screen(grid)
	var sprite: Sprite2D = corner.get_node("Sprite2D")
	sprite.scale = Vector2(-1.0 if flip_h else 1.0, -1.0 if flip_v else 1.0)
