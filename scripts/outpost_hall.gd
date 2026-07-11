extends Area2D
class_name OutpostHall

## Base opens the recruit panel on this - Outpost Hall was previously a
## plain Node2D (never clicked, just a stockpile drop-off point), so
## becoming an Area2D with a click handler is new specifically for
## recruitment (see Base._on_outpost_hall_clicked, which now also checks
## for a selected citizen first - see add_worker's doc comment).
signal clicked

@export var display_name: String = "Outpost Hall"
## Generous rather than matching Workstation's default of 3 - haulers don't
## share a production buffer the way workers at one post do (each runs
## their own independent end-to-end trip), so there's no real throughput
## reason to bottleneck how many can be stationed here. Idle citizens
## already haul with no cap at all; this just gives the same role a
## deliberate, visible assignment instead of only ever happening by default.
@export var max_workers: int = 10

@onready var label: Label = $Label
@onready var stockpile_spot: Marker2D = $StockpileSpot

var active_workers := 0
var _pulse_tween: Tween


func _ready() -> void:
	_update_label()
	input_event.connect(_on_input_event)


## "Outpost Hall\n0/10" - see Workstation._update_label's doc comment.
func _update_label() -> void:
	label.text = "%s\n%d/%d" % [display_name, active_workers, max_workers]


func get_stockpile_spot() -> Vector2:
	return stockpile_spot.global_position


## Same "post" interface Workstation/WallSegment expose (add_worker/
## remove_worker/get_worker_spot/display_name/active_workers/max_workers) -
## lets a citizen be dragged onto (or clicked-then-clicked, or Base._assign_
## selected_to'd) the Outpost Hall to be explicitly assigned as a hauler
## (see Character.assign_to's OutpostHall/StorageFacility branch), the same
## work _run_hauler_loop already does for any unassigned citizen by
## default - this just makes it a deliberate, visible, savable assignment
## rather than only ever an implicit fallback.
func get_worker_spot() -> Vector2:
	return stockpile_spot.global_position


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
	_pulse_tween.tween_property($Sprite2D, "scale", Vector2(1.04, 1.04), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property($Sprite2D, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_pulse() -> void:
	if _pulse_tween:
		_pulse_tween.kill()
		_pulse_tween = null
	var reset_tween := create_tween()
	reset_tween.tween_property($Sprite2D, "scale", Vector2.ONE, 0.15)


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		clicked.emit()
