extends Area2D
class_name StorageFacility

@export var display_name: String = "Storage Facility"
## See OutpostHall.max_workers' doc comment for why this is generous rather
## than matching Workstation's default of 3 - haulers don't share a
## production buffer, so there's no throughput reason to bottleneck it.
@export var max_workers: int = 10

@onready var label: Label = $Label
@onready var worker_spot: Marker2D = $WorkerSpot

var active_workers := 0
var _pulse_tween: Tween


func _ready() -> void:
	_update_label()


## "Storage Facility\n0/10" - see Workstation._update_label's doc comment.
func _update_label() -> void:
	label.text = "%s\n%d/%d" % [display_name, active_workers, max_workers]


## A placed Storage Facility is a real drop-off/pickup point for haulers,
## not just a storage_capacity bump - Base registers/unregisters this with
## WorldGrid.stockpile_spots on placement/removal, so Character's haul
## loops can route to whichever registered stockpile (this or the Outpost
## Hall) is nearest instead of always the Outpost Hall (see WorldGrid.
## nearest_stockpile). Reuses worker_spot rather than a second marker -
## thematically fine for an assigned hauler to also drop off right where
## they're standing.
func get_stockpile_spot() -> Vector2:
	return worker_spot.global_position


## Same "post" interface Workstation/WallSegment/OutpostHall expose - lets
## a citizen be dragged (or clicked-then-clicked) onto a placed Storage
## Facility to be explicitly assigned as a hauler (see Character.assign_to's
## OutpostHall/StorageFacility branch). Unlike OutpostHall this has no
## input_event of its own, so a click resolves via Base's generic
## _post_at() physics-query path rather than a dedicated clicked signal -
## nothing else currently wants to happen when a Storage Facility is
## clicked with no citizen selected.
func get_worker_spot() -> Vector2:
	return worker_spot.global_position


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
	_pulse_tween.tween_property($Sprite2D, "scale:y", 1.6 * 1.04, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property($Sprite2D, "scale:y", 1.6, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_pulse() -> void:
	if _pulse_tween:
		_pulse_tween.kill()
		_pulse_tween = null
	var reset_tween := create_tween()
	reset_tween.tween_property($Sprite2D, "scale:y", 1.6, 0.15)
