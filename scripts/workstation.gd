extends Area2D
class_name Workstation

## Fired whenever `disabled` changes (see its own doc comment) - Base
## listens (see _wire_workstation_disable/_on_post_disabled_changed) to
## evict any current worker the moment a post is disabled, and to re-run
## job assignment either direction.
signal disabled_changed(is_disabled: bool)

## Fired on left-click - lets Base show a generic building-info panel
## (name + who's currently employed here, see Base._on_building_info_
## clicked/BuildingInfoPanel) for whichever Workstation subclass doesn't
## already have its own left-click meaning. Farm (crop-retool panel) and
## TrainingGround (recruit/upgrade panel) both extend this class too and
## so also emit this signal on left-click alongside their own separate
## `clicked` signal - harmless, since Base's wiring (_wire_building_info_
## clicks) deliberately only connects it for the plain subclasses
## (LumberCamp/StoneMine/Brickmaker/Workshop/ConstructionSite) and leaves
## it unconnected (a no-op emit) for Farm/TrainingGround, whose own panels
## show this same name+employees info instead - see CropPanel/
## TrainingGroundPanel's own employee-list section.
signal info_clicked

## Multiplied onto sprite_tint (not a replacement) so a disabled post still
## reads as "the same building, dimmed" rather than losing its crop/
## resource-specific color entirely.
const DISABLED_TINT := Color(0.55, 0.55, 0.55)

## Shared across every occluder class (WorldTree, House, OutpostHall, Well,
## StorageFacility too) - see Base's "X-ray reveal" doc comment. One shared
## ShaderMaterial instance is safe here since every parameter it reads is a
## global uniform, not a per-instance one.
const XRAY_MATERIAL := preload("res://shaders/xray_reveal_material.tres")

## Emptied out - "cabbage" and "wood" used to force an override here
## regardless of which scene a post actually was, which silently meant
## LumberCamp (always resource_type "wood") rendered from this dict instead
## of its own scene's baked-in Sprite2D, and a Farm-family post retooled
## back to Cabbage would revert to whatever art lived here even if the
## scene's own default had since moved on. Now that every Farm-family crop
## and LumberCamp each carry their own correct baked-in sprite directly
## (see _default_texture below), there's no resource_type left that needs
## a cross-scene override - kept as an empty dict (not deleted) since
## refresh_visual() still consults it and a future genuinely-shared-across-
## scenes resource type could still want one.
const RESOURCE_VISUALS := {}

@export var display_name: String = "Workstation"
@export var resource_type: String = "cabbage"
@export var output_per_tick: float = 1.0
## Input side of a single-input/single-output converter (Farm-class
## buildings, Brickmaker) - moved up here (like work_interval already was,
## for StoneMine's benefit) so Character._run_farm_loop can drive any
## converter-shaped post generically rather than requiring the Farm class
## specifically. A post with no input (LumberCamp, StoneMine,
## ConstructionSite) just leaves input_per_tick at 0 / input_resource at ""
## and never worries about either - get_input_resource() below returns ""
## by default, which is also what marks a post as "no input delivery
## needed" to Character._find_haul_job().
@export var input_per_tick: float = 0.0
@export var input_resource: String = ""
## Max units of resource_type a worker will accumulate here before hauling
## the lot to the stockpile - also how much a single haul trip carries.
## Raised 6.0 -> 8.0 -> 10.0 via Outpost_Survival/Game Systems/Balance.md's
## edit-and-hand-back workflow.
@export var carry_limit: float = 10.0
## Seconds between production ticks. Used directly by Character's generic
## work loop (e.g. StoneMine); Farm reads it too even though it has its own
## specialized loop, and LumberCamp ignores it in favor of chop_interval.
## Doubled from 1.5 to 3.0 per an explicit request to slow work pace by a
## factor of 2 (see Character.MOVE_SPEED's doc comment for the matching
## movement slowdown, and Base's fast-forward system for the companion
## speed-up), then doubled again 3.0 -> 6.0 via Outpost_Survival/Balance.md's
## edit-and-hand-back workflow. Not itself save-persisted (see
## Base.BUILDING_PROPERTIES/_apply_option_properties) - it's re-applied from
## BuildingCatalog at placement/restore time, so this default change is
## automatically backward-compatible with existing saves.
@export var work_interval: float = 6.0
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
## Short player-facing blurb shown in whichever info panel this post's
## click opens (BuildingInfoPanel/CropPanel/TrainingGroundPanel - see
## Base.BUILDING_PROPERTIES, which copies this from the catalog entry the
## same way it does display_name/sprite_tint). Empty by default so a
## catalog entry that hasn't been given one yet just shows nothing rather
## than a placeholder string.
@export var description: String = ""
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
	sprite.material = XRAY_MATERIAL
	refresh_visual()
	input_event.connect(_on_workstation_input_event)


## "1/1" - just how full this post's worker slots are, refreshed on every
## add_worker()/remove_worker() so it stays live. Used to also show the
## building's own name above this, dropped per an explicit request ("remove
## the floating name from above buildings but keep the number") - a
## disabled post is still visually distinguishable via DISABLED_TINT on the
## sprite itself (see refresh_visual()), so dropping the old " (Disabled)"
## text suffix here doesn't lose that information.
func _update_label() -> void:
	label.text = "%d/%d" % [active_workers, max_workers]


## Right-click toggles `disabled`; left-click emits info_clicked (see its
## own doc comment for why this is safe to also fire on Farm/TrainingGround,
## which have their own separate left-click meaning via their own
## _on_input_event override). Godot calls every connected input_event
## listener for a given event regardless of button, so Farm's own
## left-click handler and this one coexist fine on the same Area2D.
## Deliberately a different method name than Farm's own _on_input_event
## override - connecting a same-named method from this base class's
## _ready() would resolve virtually to Farm's override instead (GDScript
## has no way to bind "this class's implementation, even from a
## subclass"), silently skipping this handler entirely and double-
## connecting Farm's.
func _on_workstation_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		get_viewport().set_input_as_handled()
		set_disabled(not disabled)
	elif event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		info_clicked.emit()


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
## input-delivery target". Just reads the input_resource export directly -
## overridden by nothing anymore now that every converter-style post
## (Farm-class, Brickmaker) shares this same field.
func get_input_resource() -> String:
	return input_resource


## No longer pulses the sprite while active (see _update_label's sibling
## history) - removed per an explicit request ("remove the working
## animation from all buildings, the villagers will be the ones animated
## when working"). The sprite-scale pulse was also what farm.gd's
## _start_pulse override existed to suppress (a big ground-diamond sprite
## pulsing ±8% swept over the worker standing on it) - that override is gone
## too now that there's nothing left to override.
func add_worker() -> void:
	active_workers += 1
	_update_label()


func remove_worker() -> void:
	active_workers = max(0, active_workers - 1)
	_update_label()
