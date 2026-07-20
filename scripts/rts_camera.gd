extends Camera2D
class_name RtsCamera

## Empirically (this Godot build): zoom > 1 magnifies (zoomed in), zoom < 1
## shows more world (zoomed out) — the reverse of what Camera2D's docs
## describe, so don't "fix" this back without re-testing in an actual window.
##
## zoom_min lowered 0.5 -> 0.25 (Increase max zoom out level.md) - doubles
## the previous max visible area again, on top of the map itself already
## being expanded 4x (see Expand map size 4x.md). Not raised further than
## this first pass since going much lower starts to make individual
## villagers unreadably small (a few px tall) - "realistic limits" per that
## note's own phrasing, not an arbitrary engine cap.
@export var zoom_min := 0.25
@export var zoom_max := 2.0
@export var zoom_step := 0.1
@export var zoom_tween_duration := 0.15

@export var edge_scroll_margin := 24.0
@export var edge_scroll_speed := 900.0

## Extra world-space room beyond the ground bounds the camera can pan into.
@export var limit_margin := 320.0

## World bus volume at zoom_max (fully zoomed in) vs zoom_min (fully zoomed
## out) - see _update_world_audio_volume. 0.0 leaves GatherSound/
## LevelUpSound at exactly their own authored volume_db when close up;
## -40.0 is quiet enough to read as "almost inaudible" (Increase max zoom
## out level.md) without relying on a hasty -80/mute, which would make an
## abrupt cutoff right at zoom_min rather than a smooth fade.
const WORLD_AUDIO_DB_AT_MAX_ZOOM := 0.0
const WORLD_AUDIO_DB_AT_MIN_ZOOM := -40.0
var _world_bus_index := -1

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
	_world_bus_index = AudioServer.get_bus_index("World")
	_update_world_audio_volume()


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
	_update_world_audio_volume()


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


## Instant, not tweened - CitizensPanel's own idea note asks for a "snap",
## and every other camera move here (drag, edge-scroll) is already a direct
## position set too; a smooth pan would be the odd one out. Still routed
## through _clamp_position() same as those, so snapping to a citizen right
## at the map edge doesn't push the view past the configured limits.
func focus_on(target: Vector2) -> void:
	position = target
	_clamp_position()


func _zoom_by(amount: float) -> void:
	_zoom_level = clampf(_zoom_level + amount, zoom_min, zoom_max)
	if _zoom_tween:
		_zoom_tween.kill()
	_zoom_tween = create_tween()
	_zoom_tween.tween_property(self, "zoom", Vector2.ONE * _zoom_level, zoom_tween_duration).set_ease(Tween.EASE_OUT)


## Fades the World bus (GatherSound/LevelUpSound on every Character, see
## character.gd's own doc comment on those two nodes) down as the camera
## zooms out, on top of each AudioStreamPlayer2D's own distance-based
## attenuation - Godot's built-in 2D positional audio has no concept of
## camera zoom at all, so without this a villager sound reads exactly as
## loud whether the camera is showing one house or the whole map. Reads
## the actual interpolated `zoom.x` (not `_zoom_level`) so the fade tracks
## the in-flight zoom tween smoothly frame-by-frame rather than jumping the
## instant a scroll/keypress starts one. `_world_bus_index` is -1 (a no-op
## AudioServer call - safe, just does nothing) only if default_bus_layout's
## "World" bus somehow failed to load; never expected in practice.
func _update_world_audio_volume() -> void:
	if _world_bus_index < 0:
		return
	var t := inverse_lerp(zoom_min, zoom_max, zoom.x)
	var volume_db := lerpf(WORLD_AUDIO_DB_AT_MIN_ZOOM, WORLD_AUDIO_DB_AT_MAX_ZOOM, clampf(t, 0.0, 1.0))
	AudioServer.set_bus_volume_db(_world_bus_index, volume_db)
