extends Camera2D
class_name RtsCamera

## Empirically (this Godot build): zoom > 1 magnifies (zoomed in), zoom < 1
## shows more world (zoomed out) — the reverse of what Camera2D's docs
## describe, so don't "fix" this back without re-testing in an actual window.
@export var zoom_min := 0.5
@export var zoom_max := 2.0
@export var zoom_step := 0.1
@export var zoom_tween_duration := 0.15

@export var edge_scroll_margin := 24.0
@export var edge_scroll_speed := 900.0

## Extra world-space room beyond the ground bounds the camera can pan into.
@export var limit_margin := 320.0

var _zoom_level := 1.0
var _zoom_tween: Tween

var _dragging := false
var _drag_start_mouse := Vector2.ZERO
var _drag_start_cam_pos := Vector2.ZERO


func _ready() -> void:
	zoom = Vector2.ONE * _zoom_level
	# Replicates the framing the game had with no camera at all (world origin
	# at the viewport's top-left corner), regardless of window size.
	position = get_viewport_rect().size / 2.0


func configure_limits(min_local: Vector2, max_local: Vector2) -> void:
	limit_left = int(min_local.x - limit_margin)
	limit_top = int(min_local.y - limit_margin)
	limit_right = int(max_local.x + limit_margin)
	limit_bottom = int(max_local.y + limit_margin)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			get_viewport().set_input_as_handled()
			_zoom_by(zoom_step)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			get_viewport().set_input_as_handled()
			_zoom_by(-zoom_step)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			get_viewport().set_input_as_handled()
			_dragging = event.pressed
			if _dragging:
				_drag_start_mouse = event.position
				_drag_start_cam_pos = position
	elif event is InputEventMouseMotion and _dragging:
		get_viewport().set_input_as_handled()
		var screen_delta: Vector2 = event.position - _drag_start_mouse
		position = _drag_start_cam_pos - screen_delta / zoom
		_clamp_position()


func _process(delta: float) -> void:
	_edge_scroll(delta)


func _edge_scroll(delta: float) -> void:
	if _dragging or not get_window().has_focus():
		return
	var viewport := get_viewport()
	var mouse_pos := viewport.get_mouse_position()
	var size := viewport.get_visible_rect().size
	var dir := Vector2.ZERO
	if mouse_pos.x <= edge_scroll_margin:
		dir.x -= 1
	elif mouse_pos.x >= size.x - edge_scroll_margin:
		dir.x += 1
	if mouse_pos.y <= edge_scroll_margin:
		dir.y -= 1
	elif mouse_pos.y >= size.y - edge_scroll_margin:
		dir.y += 1
	if dir != Vector2.ZERO:
		position += dir.normalized() * edge_scroll_speed / zoom.x * delta
		_clamp_position()


## Camera2D's limit_* properties only clamp the rendered view, not the
## `position` property itself — setting position directly (as drag/edge-scroll
## do) lets it drift arbitrarily far past the limits with no visible change,
## then takes just as long to drift back before the opposite direction has any
## visible effect. Clamp position for real after every manual move.
func _clamp_position() -> void:
	position.x = clampf(position.x, limit_left, limit_right)
	position.y = clampf(position.y, limit_top, limit_bottom)


func _zoom_by(amount: float) -> void:
	_zoom_level = clampf(_zoom_level + amount, zoom_min, zoom_max)
	if _zoom_tween:
		_zoom_tween.kill()
	_zoom_tween = create_tween()
	_zoom_tween.tween_property(self, "zoom", Vector2.ONE * _zoom_level, zoom_tween_duration).set_ease(Tween.EASE_OUT)
