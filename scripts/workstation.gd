extends Area2D
class_name Workstation

## Fired whenever `disabled` changes (see its own doc comment) - Base
## listens (see _wire_workstation_disable/_on_post_disabled_changed) to
## evict any current worker the moment a post is disabled, and to re-run
## job assignment either direction.
signal disabled_changed(is_disabled: bool)

## Multiplied onto sprite_tint (not a replacement) so a disabled post still
## reads as "the same building, dimmed" rather than losing its crop/
## resource-specific color entirely.
const DISABLED_TINT := Color(0.55, 0.55, 0.55)

const RESOURCE_VISUALS := {
	"cabbage": {
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
@export var resource_type: String = "cabbage"
@export var output_per_tick: float = 1.0
## Max units of resource_type a worker will accumulate here before hauling
## the lot to the stockpile - also how much a single haul trip carries.
@export var carry_limit: float = 6.0
## Seconds between production ticks. Used directly by Character's generic
## work loop (e.g. StoneMine); Farm reads it too even though it has its own
## specialized loop, and LumberCamp ignores it in favor of chop_interval.
@export var work_interval: float = 1.5
## How many citizens can be assigned here at once - most Workstations only
## have room for one at a time now (a first-pass default, not tuned via
## playtesting - a handful of catalog entries may still want to override it
## upward for genuine parallel-throughput cases). Enforced by
## Base._run_job_assignment's per-skill capacity accounting, not by any
## per-post check anymore - job assignment is fully automatic now (see
## CLAUDE.md's rewritten Character/post interaction pattern).
@export var max_workers: int = 1
## Lets several BuildingCatalog entries share one placeholder scene (e.g.
## every crop/refinement building in the Farm family) while still reading
## visually distinct - applied over whatever RESOURCE_VISUALS or the scene's
## own sprite picked. Identity tint (WHITE) leaves it untouched.
@export var sprite_tint: Color = Color.WHITE
## Right-click toggles this (see _on_input_event) - lets the player
## temporarily pull a post out of automatic job assignment (see
## Base._run_job_assignment) to send its worker elsewhere, without having
## to demolish/rebuild it. A disabled post immediately evicts its current
## worker (Base._on_post_disabled_changed) and is treated as zero capacity
## until re-enabled.
var disabled := false

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
	_update_label()
	_default_texture = sprite.texture
	_default_centered = sprite.centered
	_default_offset = sprite.offset
	refresh_visual()
	input_event.connect(_on_workstation_input_event)


## "Farm\n1/1" - shows how full this post's worker slots are, not just its
## name, refreshed on every add_worker()/remove_worker() so it stays live.
## A disabled post appends " (Disabled)" to the name line (compare House's
## " (Upgraded)" suffix).
func _update_label() -> void:
	var suffix := " (Disabled)" if disabled else ""
	label.text = "%s%s\n%d/%d" % [display_name, suffix, active_workers, max_workers]


## Right-click toggles `disabled` - left-click is already spoken for on a
## Farm-family post (opens the crop panel, see Farm._on_input_event), so
## this uses the other button rather than competing with it. Godot calls
## every connected input_event listener for a given event regardless of
## button, so Farm's own left-click handler and this one coexist fine on
## the same Area2D. Deliberately a different method name than Farm's own
## _on_input_event override - connecting a same-named method from this
## base class's _ready() would resolve virtually to Farm's override
## instead (GDScript has no way to bind "this class's implementation,
## even from a subclass"), silently skipping this handler entirely and
## double-connecting Farm's.
func _on_workstation_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		get_viewport().set_input_as_handled()
		set_disabled(not disabled)


func set_disabled(value: bool) -> void:
	if disabled == value:
		return
	disabled = value
	refresh_visual()
	disabled_changed.emit(disabled)


## Re-applies resource_type/sprite_tint to the sprite (and display_name to
## the label) - split out of _ready() so a caller reconfiguring these
## exported fields at runtime (Farm's crop-selection panel) can refresh the
## visuals without needing _ready() to run again (it only runs once, on
## entering the tree).
func refresh_visual() -> void:
	_update_label()
	var visual: Dictionary = RESOURCE_VISUALS.get(resource_type, {})
	if visual:
		sprite.texture = visual["texture"]
		sprite.centered = visual["centered"]
		sprite.offset = visual["offset"]
	else:
		sprite.texture = _default_texture
		sprite.centered = _default_centered
		sprite.offset = _default_offset
	sprite.modulate = sprite_tint * (DISABLED_TINT if disabled else Color.WHITE)


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
	_update_label()
	if active_workers == 1:
		_start_pulse()


func remove_worker() -> void:
	active_workers = max(0, active_workers - 1)
	_update_label()
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
