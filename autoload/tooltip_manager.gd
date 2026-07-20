extends CanvasLayer

## Generic "hover a resource icon/stat or a building for 2s -> tooltip"
## system (Outpost_Survival/Actionable Ideas/Mouseover tooltip system.md).
## An autoload rather than a HUD child since it has to render above both
## world-space buildings and every CanvasLayer UI panel regardless of which
## owns the thing being hovered. Like every other autoload here (see
## GameState's Timer, WorldGrid's registries) it has no companion .tscn -
## autoloads can't have one - so the whole Panel/Label tree is built in
## code in _ready() instead.
##
## Callers: HUD's resource icons/stat labels (hud.gd) and Base's per-
## building wiring (_wire_building_tooltip/_tooltip_body) both just call
## request()/cancel() on mouse_entered/mouse_exited - this class knows
## nothing about resources or buildings specifically.

const HOVER_DELAY := 2.0
const MAX_BODY_WIDTH := 240.0
const SCREEN_MARGIN := 12.0
const CURSOR_OFFSET := Vector2(18, 18)

var _panel: PanelContainer
var _title_label: Label
var _body_label: Label
var _timer: Timer
var _pending_title := ""
var _pending_body := ""


func _ready() -> void:
	layer = 20

	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", _build_style())
	_panel.resized.connect(_position_at_mouse)
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 10)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vbox)

	_title_label = Label.new()
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_title_label)

	_body_label = Label.new()
	_body_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body_label.modulate.a = 0.75
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.custom_minimum_size = Vector2(MAX_BODY_WIDTH, 0)
	vbox.add_child(_body_label)

	_timer = Timer.new()
	_timer.wait_time = HOVER_DELAY
	_timer.one_shot = true
	_timer.timeout.connect(_show_pending)
	add_child(_timer)


## Same dark-panel-with-tan-border look as ui_theme.tres's default Panel
## style (resources/theme/ui_theme.tres's PanelStyle) - not that resource
## directly, since this autoload has no scene to hold a Theme reference and
## duplicating the StyleBoxFlat in code is simpler than preloading a
## Theme just to pull one style out of it.
func _build_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.11, 0.1, 0.95)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.55, 0.45, 0.25, 1)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	return style


## Starts (or restarts, if already counting down for something else) the
## HOVER_DELAY countdown - called on a resource icon/building's
## mouse_entered. `body` is empty-safe (an empty string just hides the body
## line, showing the title alone).
func request(title: String, body: String) -> void:
	_pending_title = title
	_pending_body = body
	_panel.visible = false
	_timer.start()


## Called on mouse_exited - cancels a pending countdown and/or hides an
## already-shown tooltip. Safe to call even if nothing was ever requested.
func cancel() -> void:
	_timer.stop()
	_panel.visible = false


func _show_pending() -> void:
	_title_label.text = _pending_title
	_body_label.visible = not _pending_body.is_empty()
	_body_label.text = _pending_body
	_panel.visible = true
	_position_at_mouse()


## Positioned once when shown (not continuously tracked while visible) -
## same behavior as Godot's own default Control tooltip. Connected to
## _panel's own `resized` too (see _ready) since PanelContainer doesn't
## finish sizing to its new text until a layout pass after _show_pending
## sets it visible - the same "size not reliable until resized fires"
## caveat HUD's food_bar_frame has (see hud.gd's own doc comment on it).
##
## Opens away from whichever screen half the cursor is in (left of cursor
## when the cursor is in the right half, above when it's in the bottom
## half) rather than always down-right - HUD's resource rows/stat labels
## all live in a panel anchored to the top-right corner, so a tooltip that
## always opened down-right would sit on top of the very panel it's
## describing (verified by screenshot - hovering the Wood icon covered
## Stone/Water/Population underneath it). Flipping toward open screen
## space avoids that regardless of which HUD row is hovered.
func _position_at_mouse() -> void:
	if not _panel.visible:
		return
	var viewport := get_viewport()
	if not viewport:
		return
	var mouse_pos := viewport.get_mouse_position()
	var viewport_size := viewport.get_visible_rect().size
	var panel_size := _panel.size
	var target := mouse_pos
	if mouse_pos.x > viewport_size.x / 2.0:
		target.x = mouse_pos.x - CURSOR_OFFSET.x - panel_size.x
	else:
		target.x = mouse_pos.x + CURSOR_OFFSET.x
	if mouse_pos.y > viewport_size.y / 2.0:
		target.y = mouse_pos.y - CURSOR_OFFSET.y - panel_size.y
	else:
		target.y = mouse_pos.y + CURSOR_OFFSET.y
	target.x = clampf(target.x, SCREEN_MARGIN, maxf(SCREEN_MARGIN, viewport_size.x - panel_size.x - SCREEN_MARGIN))
	target.y = clampf(target.y, SCREEN_MARGIN, maxf(SCREEN_MARGIN, viewport_size.y - panel_size.y - SCREEN_MARGIN))
	_panel.position = target
