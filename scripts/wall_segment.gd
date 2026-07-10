extends Area2D
class_name WallSegment

@export var display_name: String = "Wall Section"
## Unlike a Workstation, a wall segment only has room for one defender - see
## Workstation.max_workers' doc comment for how Base checks this.
@export var max_workers: int = 1

@onready var label: Label = $Label
@onready var sprite: Sprite2D = $Sprite2D
@onready var work_spot: Marker2D = $WorkSpot

var active_workers := 0
var _pulse_tween: Tween


func _ready() -> void:
	label.text = display_name


func get_worker_spot() -> Vector2:
	return work_spot.global_position


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
