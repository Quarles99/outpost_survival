extends Area2D
class_name Workstation

const RESOURCE_VISUALS := {
	"food": {
		"texture": preload("res://art/iso_workstation_farm.svg"),
		"centered": false,
		"offset": Vector2(-138, -106),
	},
	"wood": {
		"texture": preload("res://art/iso_workstation_woodpile.svg"),
		"centered": false,
		"offset": Vector2(-72, -102),
	},
}

@export var display_name: String = "Workstation"
@export var resource_type: String = "food"
@export var output_per_tick: float = 1.0
## Max units of resource_type a worker will accumulate here before hauling
## the lot to the stockpile - also how much a single haul trip carries.
@export var carry_limit: float = 6.0
## Seconds between production ticks. Used directly by Character's generic
## work loop (e.g. StoneMine); Farm reads it too even though it has its own
## specialized loop, and LumberCamp ignores it in favor of chop_interval.
@export var work_interval: float = 1.5
## How many citizens can be assigned here at once - sharing a post's buffers
## for parallel throughput is intentional (see CLAUDE.md), but unbounded
## stacking isn't; a first-pass default, not tuned via playtesting. Checked
## by Base (_post_has_room) before allowing a new assignment via drag or the
## task menu, alongside WallSegment's own max_workers (duck-typed the same
## way add_worker/remove_worker/get_worker_spot/display_name already are).
@export var max_workers: int = 3
## Lets several BuildingCatalog entries share one placeholder scene (e.g.
## every crop/refinement building in the Farm family) while still reading
## visually distinct - applied over whatever RESOURCE_VISUALS or the scene's
## own sprite picked. Identity tint (WHITE) leaves it untouched.
@export var sprite_tint: Color = Color.WHITE

@onready var label: Label = $Label
@onready var sprite: Sprite2D = $Sprite2D
@onready var work_spot: Marker2D = $WorkSpot

var active_workers := 0
## Produced-but-not-yet-hauled-out resource_type sitting at this post.
var output_buffer: float = 0.0
## Delivered-but-not-yet-consumed get_input_resource() sitting at this post.
## Meaningless (stays 0, never read) for a post whose get_input_resource()
## is "" - LumberCamp and generic Workstation don't use it.
var input_buffer: float = 0.0
var _pulse_tween: Tween

## The scene's own baked-in sprite, captured before any RESOURCE_VISUALS
## override is applied - refresh_visual() falls back to this for a
## resource_type with no RESOURCE_VISUALS entry (e.g. "grain"), so
## reconfiguring resource_type at runtime (see Farm's crop-selection) can
## correctly revert to it rather than getting stuck on whatever texture an
## earlier resource_type happened to pick.
var _default_texture: Texture2D
var _default_centered: bool
var _default_offset: Vector2


func _ready() -> void:
	label.text = display_name
	_default_texture = sprite.texture
	_default_centered = sprite.centered
	_default_offset = sprite.offset
	refresh_visual()


## Re-applies resource_type/sprite_tint to the sprite - split out of _ready()
## so a caller reconfiguring these exported fields at runtime (Farm's
## crop-selection panel) can refresh the visual without needing _ready() to
## run again (it only runs once, on entering the tree).
func refresh_visual() -> void:
	var visual: Dictionary = RESOURCE_VISUALS.get(resource_type, {})
	if visual:
		sprite.texture = visual["texture"]
		sprite.centered = visual["centered"]
		sprite.offset = visual["offset"]
	else:
		sprite.texture = _default_texture
		sprite.centered = _default_centered
		sprite.offset = _default_offset
	sprite.modulate = sprite_tint


func get_worker_spot() -> Vector2:
	return work_spot.global_position


## Skill this post trains in whoever works it. Overridden by subclasses;
## generic Workstation ("labor") is a dead code path today - no scene uses
## the base class directly (see CLAUDE.md's note on Workstation.tscn).
func get_skill_id() -> String:
	return "labor"


## Resource this post needs delivered into input_buffer before it can
## produce, or "" if it doesn't use one (the default - LumberCamp has no
## input). A hauler treats a non-empty return as "this post is a valid
## input-delivery target".
func get_input_resource() -> String:
	return ""


func add_worker() -> void:
	active_workers += 1
	if active_workers == 1:
		_start_pulse()


func remove_worker() -> void:
	active_workers = max(0, active_workers - 1)
	if active_workers == 0:
		_stop_pulse()


func _start_pulse() -> void:
	if _pulse_tween:
		_pulse_tween.kill()
	_pulse_tween = create_tween()
	_pulse_tween.set_loops()
	_pulse_tween.tween_property(sprite, "scale", Vector2(1.08, 1.08), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(sprite, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_pulse() -> void:
	if _pulse_tween:
		_pulse_tween.kill()
		_pulse_tween = null
	var reset_tween := create_tween()
	reset_tween.tween_property(sprite, "scale", Vector2.ONE, 0.15)
